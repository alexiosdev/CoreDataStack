//
//  ModelMigrationTests.swift
//  CoreDataStack
//
//  Created by Robert Edwards on 8/13/15.
//  Copyright © 2015 Big Nerd Ranch. All rights reserved.
//

import XCTest

import CoreData

@testable import CoreDataStack

class ModelMigrationTests: TempDirectoryTestCase {
    
    func testVersionMigration() throws {
        weak var ex1 = expectation(withDescription: "Setup Expectation")
        CoreDataStack.constructSQLiteStack(withModelName: "Sample", inBundle: unitTestBundle, withStoreURL: tempStoreURL) { result in
            switch result {
            case .success(let stack):
                XCTAssertNotNil(stack.mainQueueContext)
            case .failure(let error):
                XCTFail("Error constructing stack: \(error)")
            }
            ex1?.fulfill()
        }
        waitForExpectations(withTimeout: 20, handler: nil)
    }

}
