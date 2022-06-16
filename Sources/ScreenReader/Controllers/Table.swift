//
//  Table.swift
//  
//  Copyright © 2017-2022 Doug Russell. All rights reserved.
//

import AccessibilityElement
import Foundation
import TargetAction
import os

public final class Table<ObserverType: Observer>: Controller where ObserverType.ObserverElement: Hashable {
    public typealias ElementType = ObserverType.ObserverElement
    public let element: ElementType

    private var logger: Logger {
        Loggers.Controller.table
    }

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
        logger.info("\(#function) \(self.element)")
        do {
            observerTokens.append(try await add(
                notification: .selectedRowsChanged,
                handler: TargetAction.target(
                    self,
                    action: Table<ObserverType>.selectionChanged
                )
            ))
        } catch let error as ControllerObserverError {
            logger.info("\(error.localizedDescription)")
        } catch {
            throw error
        }
        do {
            observerTokens.append(try await add(
                notification: .selectedColumnsChanged,
                handler: TargetAction.target(
                    self,
                    action: Table<ObserverType>.selectionChanged
                )
            ))
        } catch let error as ControllerObserverError {
            logger.info("\(error.localizedDescription)")
        } catch {
            throw error
        }
        await selectionChanged(
            element: element,
            userInfo: nil
        )
    }
    public func focus() async throws {
        logger.info("\(#function) \(self.element)")
    }
    public func stop() async throws {
        do {
            try await remove(tokens: observerTokens)
        } catch {
            logger.error("\(error.localizedDescription)")
        }
        observerTokens.removeAll()
    }
    private func selectionChanged(
        element: ElementType,
        userInfo: [String:Any]?
    ) async {
        logger.info("\(#function) \(element)")
        do {
            let cells = try element.selectedCells()
            logger.info("\(#function) \(cells)")
        } catch {
            logger.error("\(#function) \(error.localizedDescription)")
        }
    }
}

extension Table: ObserverHosting {}
