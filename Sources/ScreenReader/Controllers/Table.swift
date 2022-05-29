//
//  Table.swift
//  
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

import AccessibilityElement
import Foundation
import os

public actor Table<ObserverType: Observer>: Controller where ObserverType.ObserverElement: Hashable {
    public typealias ElementType = ObserverType.ObserverElement
    public let element: ElementType
    let observer: ApplicationObserver<ObserverType>
    private var observerTokens: [ApplicationObserver<ObserverType>.ObserverToken] = []
    public init(
        element: ElementType,
        observer: ApplicationObserver<ObserverType>
    ) async throws {
        self.element = element
        self.observer = observer
    }
    public func start() async throws {
        Loggers.Controller.table.info("\(#function) \(self.element)")
        do {
            observerTokens.append(try await add(
                notification: .selectedRowsChanged,
                handler: isolated(action: Table<ObserverType>.selectionChanged)
            ))
        } catch let error as ControllerObserverError {
            Loggers.Controller.table.info("\(error.localizedDescription)")
        } catch {
            throw error
        }
        do {
            observerTokens.append(try await add(
                notification: .selectedColumnsChanged,
                handler: isolated(action: Table<ObserverType>.selectionChanged)
            ))
        } catch let error as ControllerObserverError {
            Loggers.Controller.table.info("\(error.localizedDescription)")
        } catch {
            throw error
        }
        await selectionChanged(
            element: element,
            userInfo: nil
        )
    }
    public func focus() async throws {
        Loggers.Controller.table.info("\(#function) \(self.element)")
    }
    public func stop() async throws {
        do {
            for observerToken in observerTokens {
                try await observer.remove(token: observerToken)
            }
        } catch {}
        observerTokens.removeAll()
    }
    private func selectionChanged(
        element: ElementType,
        userInfo: [String:Any]?
    ) async {
        Loggers.Controller.table.info("\(#function) \(element)")
        do {
            let cells = try element.selectedCells()
            Loggers.Controller.table.info("\(#function) \(cells)")
        } catch {
            Loggers.Controller.table.error("\(#function) \(error.localizedDescription)")
        }
    }
}

extension Table: ObserverHosting {}
