//
//  ScreenReader.swift
//
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

import Cocoa

public actor ScreenReader {
    private let serverProvider: ServerProvider
    private var runningApplications: RunningApplications?
    private var runningApplicationsTask: Task<Void, Error>?
    private let output = Output()
    private let dependencies: ScreenReaderDependencies
    public init(dependencies: Dependencies) {
        self.dependencies = dependencies.screenReaderDependenciesFactory()
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
    }
    public func stop() async throws {
        runningApplicationsTask?.cancel()
        runningApplicationsTask = nil
    }
    private var running: [RunningApplication:Server] = [:]
}

extension ScreenReader {
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
            do {
                let server = try await serverProvider.connect(
                    processIdentifier: key.processIdentifier,
                    bundleIdentifier: key.bundleIdentifier,
                    output: output
                )
                Loggers.logger.debug("Add \(key.processIdentifier) \(key.bundleIdentifier)")
                try await server.start()
                running[key] = server
            } catch ServerProviderError.ignored {
                Loggers.logger.error("Ignored \(key.processIdentifier) \(key.bundleIdentifier)")
            } catch {
                Loggers.logger.error("\(error.localizedDescription)")
            }
        }
    }
    private func remove(applications: [RunningApplication]) async {
        for key in applications {
            if let server = running.removeValue(forKey: .init(processIdentifier: key.processIdentifier,
                                                              bundleIdentifier: key.bundleIdentifier)) {
                Loggers.logger.debug("Remove \(key.processIdentifier) \(key.bundleIdentifier)")
                do {
                    try await server.stop()
                } catch {
                    Loggers.logger.error("Server Stop Error: \(error.localizedDescription)")
                }
            }
        }
    }
}
