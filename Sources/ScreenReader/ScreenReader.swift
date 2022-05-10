//
//  ScreenReader.swift
//
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

import Cocoa

public final class ScreenReader {
    private let serverProvider: ServerProvider
    private var runningApplicationsTask: Task<Void, Error>?
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
            dependencies.logger.error("Not Trusted")
            exit(1)
        }
    }
    public func start() async throws {
        runningApplicationsTask?.cancel()
        let runningApplications = try await dependencies.runningApplicationsFactory()
        runningApplicationsTask = Task.detached { [weak self] in
            for await change in await runningApplications.stream() {
                try Task.checkCancellation()
                await self?.handleApplication(change: change)
            }
        }
    }
    public func stop() async throws {
        runningApplicationsTask?.cancel()
        runningApplicationsTask = nil
    }
    struct ServerKey: Hashable {
        let processIdentifier: pid_t
        let bundleIdentifier: BundleIdentifier
    }
    private var running: [ServerKey:Server] = [:]
}

private extension Array where Element == NSRunningApplication {
    func identifiers() -> [ScreenReader.ServerKey] {
        compactMap { application in
            guard let bundleIdentifier = BundleIdentifier(rawValue: application.bundleIdentifier) else {
                return nil
            }
            return .init(processIdentifier: application.processIdentifier,
                         bundleIdentifier: bundleIdentifier)
        }
    }
}

extension ScreenReader {
    private func handleApplication(change: ArrayChange<NSRunningApplication>) async {
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
    private func add(applications: [NSRunningApplication]) async {
        for key in applications.identifiers() {
            do {
                let server = try await serverProvider.connect(processIdentifier: key.processIdentifier,
                                                              bundleIdentifier: key.bundleIdentifier)
                dependencies.logger.debug("Add \(key.processIdentifier) \(key.bundleIdentifier)")
                try await server.start()
                running[key] = server
            } catch ServerProviderError.ignored {
                dependencies.logger.error("Ignored \(key.processIdentifier) \(key.bundleIdentifier)")
            } catch {
                dependencies.logger.error("\(error.localizedDescription)")
            }
        }
    }
    private func remove(applications: [NSRunningApplication]) async {
        for key in applications.identifiers() {
            if let server = running.removeValue(forKey: .init(processIdentifier: key.processIdentifier,
                                                              bundleIdentifier: key.bundleIdentifier)) {
                dependencies.logger.debug("Remove \(key.processIdentifier) \(key.bundleIdentifier)")
                do {
                    try await server.stop()
                } catch {
                    dependencies.logger.error("Server Stop Error: \(error.localizedDescription)")
                }
            }
        }
    }
}
