//
//  StackCallbackQueueTests.swift
//  CoreDataStack
//
//  Created by Robert Edwards on 4/21/16.
//  Copyright © 2016 Big Nerd Ranch. All rights reserved.
//

import XCTest

@testable import CoreDataStack

class StackCallbackQueueTests: TempDirectoryTestCase {

    func testMainQueueCallbackExecution() {
        let setupExpectation = expectation(withDescription: "Waiting for setup")

        CoreDataStack.constructSQLiteStack(
            withModelName: "Sample",
            inBundle: unitTestBundle,
            callbackQueue: DispatchQueue.main) { _ in
                XCTAssertTrue(Thread.isMainThread)
                setupExpectation.fulfill()
        }

        waitForExpectations(withTimeout: 10, handler: nil)
    }

    func testDefaultQueueCallbackExecution() {
        let setupExpectation = expectation(withDescription: "Waiting for setup")

        CoreDataStack.constructSQLiteStack(
            withModelName: "Sample",
            inBundle: unitTestBundle) { _ in
                XCTAssertFalse(Thread.isMainThread)
                setupExpectation.fulfill()
        }

        waitForExpectations(withTimeout: 10, handler: nil)
    }

    func testMainQueueResetCallbackExecution() {
        let resetExpectation = expectation(withDescription: "Waiting for reset")

        CoreDataStack.constructSQLiteStack(
            withModelName: "Sample",
            inBundle: unitTestBundle) { setupResult in
                switch setupResult {
                case .success(let stack):
                    stack.resetStore(DispatchQueue.main) { _ in
                        XCTAssertTrue(Thread.isMainThread)
                        resetExpectation.fulfill()
                    }
                case .failure(let error):
                    self.failingOn(error)
                }
        }

        waitForExpectations(withTimeout: 10, handler: nil)
    }

    func testDefaultBackgroundQueueResetCallbackExecution() {
        let resetExpectation = expectation(withDescription: "Waiting for reset")

        CoreDataStack.constructSQLiteStack(
            withModelName: "Sample",
            inBundle: unitTestBundle) { setupResult in
                switch setupResult {
                case .success(let stack):
                    stack.resetStore() { _ in
                        XCTAssertFalse(Thread.isMainThread)
                        resetExpectation.fulfill()
                    }
                case .failure(let error):
                    self.failingOn(error)
                }
        }

        waitForExpectations(withTimeout: 10, handler: nil)
    }

}
