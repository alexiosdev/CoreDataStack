//
//  SaveTests.swift
//  CoreDataStack
//
//  Created by Brian Hardy on 8/27/15.
//  Copyright © 2015 Big Nerd Ranch. All rights reserved.
//

import Foundation
import CoreData
import XCTest

@testable import CoreDataStack

class SaveTests : TempDirectoryTestCase {
    
    var coreDataStack: CoreDataStack!
    
    override func setUp() {
        super.setUp()
        createStack()
    }
    
    override func tearDown() {
        coreDataStack = nil
        super.tearDown()
    }

    func testSaveContextToStore() {
        let privateQueueContext = coreDataStack.privateQueueContext
        let mainQueueContext = coreDataStack.mainQueueContext
        let worker = coreDataStack.newChildContext()
        let saveExpectation = expectation(withDescription: "Async save callback")

        // Initial State Assertions
        worker.performAndWait() {
            XCTAssertFalse(worker.hasChanges)
            XCTAssertEqual(try! Author.all(in: worker).count, 0)
        }
        privateQueueContext.performAndWait() {
            XCTAssertFalse(privateQueueContext.hasChanges)
            XCTAssertEqual(try! Author.all(in: privateQueueContext).count, 0)
        }
        XCTAssertFalse(mainQueueContext.hasChanges)
        XCTAssertEqual(try! Author.all(in: mainQueueContext).count, 0)

        // Insert Records
        worker.performAndWait { () -> Void in
            for i in 1...5 {
                let author = Author(in: worker)
                author.firstName = "Jim \(i)"
                author.lastName = "Jones \(i)"
            }
        }

        // Perform Save
        worker.saveContextToStore() { result in
            switch result {
            case .success:
                break
            case .failure(let error):
                self.failingOn(error)
            }
            saveExpectation.fulfill()
        }
        waitForExpectations(withTimeout: 10, handler: nil)

        // Final State Assertions
        worker.performAndWait() {
            XCTAssertFalse(worker.hasChanges)
            XCTAssertEqual(try! Author.all(in: worker).count, 5)
        }
        privateQueueContext.performAndWait() {
            XCTAssertFalse(privateQueueContext.hasChanges)
            XCTAssertEqual(try! Author.all(in: privateQueueContext).count, 5)
        }
        XCTAssertFalse(mainQueueContext.hasChanges)
        XCTAssertEqual(try! Author.all(in: mainQueueContext).count, 5)
    }

    func testSaveContextToStoreAndWait() {
        let privateQueueContext = coreDataStack.privateQueueContext
        let mainQueueContext = coreDataStack.mainQueueContext
        let worker = coreDataStack.newChildContext()

        // Initial State Assertions
        worker.performAndWait() {
            XCTAssertFalse(worker.hasChanges)
            XCTAssertEqual(try! Author.all(in: worker).count, 0)
        }
        privateQueueContext.performAndWait() {
            XCTAssertFalse(privateQueueContext.hasChanges)
            XCTAssertEqual(try! Author.all(in: privateQueueContext).count, 0)
        }
        XCTAssertFalse(mainQueueContext.hasChanges)
        XCTAssertEqual(try! Author.all(in: mainQueueContext).count, 0)

        // Insert Records
        worker.performAndWait { () -> Void in
            for i in 1...5 {
                let author = Author(in: worker)
                author.firstName = "Jim \(i)"
                author.lastName = "Jones \(i)"
            }
        }

        // Perform Save
        do {
            try worker.saveContextToStoreAndWait()
        } catch {
            failingOn(error)
        }

        // Final State Assertions
        worker.performAndWait() {
            XCTAssertFalse(worker.hasChanges)
            XCTAssertEqual(try! Author.all(in: worker).count, 5)
        }
        privateQueueContext.performAndWait() {
            XCTAssertFalse(privateQueueContext.hasChanges)
            XCTAssertEqual(try! Author.all(in: privateQueueContext).count, 5)
        }
        XCTAssertFalse(mainQueueContext.hasChanges)
        XCTAssertEqual(try! Author.all(in: mainQueueContext).count, 5)
    }

    func testBackgroundInsertAndSavePropagatesChanges() {
        // create a NSFRC looking for Authors
        let frc = authorsFetchedResultsController()
        let frcDelegate = EmptyFRCDelegate()
        frc.delegate = frcDelegate
        // fetch authors to ensure we got zero (and setup change notification)
        try! frc.performFetch()
        XCTAssertEqual(frc.fetchedObjects?.count, 0)
        // now insert some authors on a background MOC and save it
        let bgMoc = coreDataStack.newChildContext()
        expectation(forNotification: NSNotification.Name.NSManagedObjectContextDidSave.rawValue, object: coreDataStack.privateQueueContext, handler: nil)
        bgMoc.performAndWait { () -> Void in
            for i in 1...5 {
                let author = Author(in: bgMoc)
                author.firstName = "Jim \(i)"
                author.lastName = "Jones \(i)"
            }
            do {
                try bgMoc.saveContextAndWait()
            } catch let error {
                XCTFail("Could not save background context: \(error)")
            }
        }
        // assert we now have that many authors in the FRC
        XCTAssertEqual(frc.fetchedObjects?.count, 5)
        // wait for the persisting context to save async
        waitForExpectations(withTimeout: 5, handler: nil)
        // destroy and recreate the stack
        coreDataStack = nil
        createStack()
        // try the fetch again
        let newFRC = authorsFetchedResultsController()
        try! newFRC.performFetch()
        // assert that we still have the same number of authors
        XCTAssertEqual(newFRC.fetchedObjects?.count, 5)
    }
    
    private func authorsFetchedResultsController() -> NSFetchedResultsController<Author> {
        let fetchRequest:NSFetchRequest<Author> = NSFetchRequest(entityName: "Author")
        fetchRequest.sortDescriptors = [SortDescriptor(key: "lastName", ascending: true)]
        return NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: coreDataStack.mainQueueContext, sectionNameKeyPath: nil, cacheName: nil)
    }
    
    func testBackgroundSaveAsync() {
        expectation(forNotification: NSNotification.Name.NSManagedObjectContextDidSave.rawValue, object: coreDataStack.mainQueueContext, handler: nil)
        
        DispatchQueue.global(attributes: [.qosBackground]).async{
            let bgMoc = self.coreDataStack.newChildContext()
            bgMoc.performAndWait { () -> Void in
                for i in 1...5 {
                    let author = Author(in: bgMoc)
                    author.firstName = "Jim \(i)"
                    author.lastName = "Jones \(i)"
                }
            }
            bgMoc.saveContext()
        }
        
        waitForExpectations(withTimeout: 2, handler: nil)
    }
    
    private func createStack() {
        weak var setupExpectation = expectation(withDescription: "stack setup")
        CoreDataStack.constructSQLiteStack(withModelName: "Sample", inBundle: unitTestBundle, withStoreURL: self.tempStoreURL) { (setupResult) -> Void in
            switch setupResult {
            case .success(let stack):
                self.coreDataStack = stack
            default: break
            }
            setupExpectation?.fulfill()
        }
        waitForExpectations(withTimeout: 2, handler: nil)
    }
}

class EmptyFRCDelegate : NSObject, NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        // nothing
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        // nothing
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: AnyObject, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        // nothing
    }
}
