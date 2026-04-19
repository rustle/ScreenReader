//
//  ScreenReader.swift
//
//  Copyright © 2017-2026 Doug Russell. All rights reserved.
//

import Cocoa

/// ScreenReader manages the lifetime
/// and configuration of your screen reader
/// It will request and manage a `Server`
/// instance for each `RunningApplication`
/// it is aware of, including monitoring
/// the process exit and doing tear down.
public actor ScreenReader {
    private let serverProvider: ServerProvider
    private var runningApplications: RunningApplications?
    private var runningApplicationsTask: Task<Void, Error>?
    private let output: Output
    private let dependencies: ScreenReaderDependencies
    // Each entry is a Task that runs withServer for the app's lifetime.
    // Cancelling the task stops the server and releases its executor.
    private var runningApplicationTasks: [RunningApplication: Task<Void, Never>] = [:]
    // Live servers keyed by PID for fast command dispatch.
    private var serversByProcessIdentifier: [pid_t: Server] = [:]
    // Process Identifier accessibility is/should be focused on
    private var focusedProcessIdentifier: pid_t = 0
    private var systemWide: SystemWide?
    private var focusedApplicationTask: Task<Void, Never>?
    // Active command sources keyed by their identifier for O(1) add/remove.
    private var commandSources: [String: any CommandSource] = [:]
    private var commandSourceTasks: [String: Task<Void, any Error>] = [:]

    public init(dependencies: Dependencies) {
        let screenReaderDeps = dependencies.screenReaderDependenciesFactory()
        self.dependencies = screenReaderDeps
        self.output = Output(contexts: screenReaderDeps.outputContextsFactory())
        serverProvider = ServerProvider(dependencies: dependencies.serverProviderDependenciesFactory())
    }

    public func confirmTrust() {
        guard dependencies.isTrusted(true) else {
            // If you already added ScreenReader
            // to trusted apps, it's likely that changing the
            // binary has invalidated it's AX API access.
            // You can usually reauthorize it by unchecking and
            // rechecking it's entry in the list of apps
            // with AX API access in System Preferences.
            Loggers.logger.error("Not Trusted")
            exit(1)
        }
    }

    public func start() async throws {
        runningApplicationsTask?.cancel()
        let runningApplications = try await dependencies.runningApplicationsFactory()
        runningApplicationsTask = await runningApplications
            .stream
            .target(
                self,
                action: ScreenReader.handleApplication
            )
        self.runningApplications = runningApplications

        let focusedRunningApplication = try await dependencies.focusedRunningApplicationFactory()
        let systemWide = try SystemWide(focusedRunningApplication: focusedRunningApplication)
        try await systemWide.start()
        self.systemWide = systemWide
        focusedApplicationTask = Task { [weak self] in
            for await pid in systemWide.focusedApplicationStream {
                await self?.setFocusedProcessIdentifier(pid)
            }
        }

        let commandSourcesFactory = dependencies.commandSourcesFactory
        let sources = try await MainActor.run {
            try commandSourcesFactory()
        }
        for source in sources {
            await addCommandSource(source)
        }
    }

    /// Register a command source. Its handler is wired to dispatch commands
    /// to the frontmost application. Safe to call at any time after init.
    public func addCommandSource(_ source: any CommandSource) async {
        commandSources[source.identifier] = source
        commandSourceTasks[source.identifier] = source
            .dispatch
            .target(
                self,
                priority: .userInitiated,
                action: ScreenReader.dispatchCommand
            )
    }

    /// Deregister a command source and clear its handler.
    public func removeCommandSource(_ source: any CommandSource) async {
        commandSources.removeValue(forKey: source.identifier)
        commandSourceTasks.removeValue(forKey: source.identifier)?.cancel()
    }

    public func stop() async throws {
        focusedApplicationTask?.cancel()
        focusedApplicationTask = nil
        try? await systemWide?.stop()
        systemWide = nil
        runningApplicationsTask?.cancel()
        runningApplicationsTask = nil
    }

    private func setFocusedProcessIdentifier(_ focusedProcessIdentifier: pid_t) {
        self.focusedProcessIdentifier = focusedProcessIdentifier
    }

    public func dispatchCommand(_ command: ScreenReaderCommand) async {
        guard let server = serversByProcessIdentifier[focusedProcessIdentifier] else {
            return
        }
        await server.dispatch(command: command)
    }
}

extension ScreenReader {
    @Sendable
    private func handleApplication(change: ArrayChange<RunningApplication>) async {
        switch change {
        case .insert(let applications):
            await add(applications: applications)
        case .remove(let applications):
            await remove(applications: applications)
        case .replace(let oldApplications, let newApplications):
            await remove(applications: oldApplications)
            await add(applications: newApplications)
        case .set(let applications):
            // TODO: Remove all
            await add(applications: applications)
        }
    }

    private func add(applications: [RunningApplication]) async {
        for key in applications {
            let task = Task { [serverProvider, output, self] in
                do {
                    try await serverProvider.withServer(
                        processIdentifier: key.processIdentifier,
                        bundleIdentifier: key.bundleIdentifier,
                        output: output
                    ) { server, _ in
                        // The _ above is this actor's isolation context.
                        // The outer await Task {} enforces that isolation
                        // and lets us stash and cleanup our server for lookup
                        // by dispatch without extending the server instances
                        // lifetime beyond the `withServer` body
                        try await Task {
                            serversByProcessIdentifier[key.processIdentifier] = server
                            defer {
                                Task {
                                    serversByProcessIdentifier.removeValue(forKey: key.processIdentifier)
                                }
                            }
                            // Suspend until the task is cancelled (app removed).
                            try await server.yield()
                        }.value
                    }
                } catch is CancellationError {
                    // Normal shutdown via task cancellation — no action needed.
                } catch ServerProviderError.ignored {
                    Loggers.logger.error("Ignored \(key.processIdentifier) \(key.bundleIdentifier)")
                } catch {
                    Loggers.logger.error("\(error.localizedDescription)")
                }
            }
            Loggers.logger.debug("Add \(key.processIdentifier) \(key.bundleIdentifier)")
            runningApplicationTasks[key] = task
        }
    }

    private func remove(applications: [RunningApplication]) async {
        for key in applications {
            if let task = runningApplicationTasks.removeValue(forKey: RunningApplication(
                processIdentifier: key.processIdentifier,
                bundleIdentifier: key.bundleIdentifier
            )) {
                Loggers.logger.debug("Remove \(key.processIdentifier) \(key.bundleIdentifier)")
                task.cancel()
            }
        }
    }
}
