//
//  CoreDataModelableTests.swift
//  CoreDataStack
//
//  Created by Robert Edwards on 11/18/15.
//  Copyright © 2015 Big Nerd Ranch. All rights reserved.
//

import XCTest

import CoreData
import CoreDataStack

class CoreDataModelableTests: TempDirectoryTestCase {
    var stack: CoreDataStack!

    override func setUp() {
        super.setUp()

        weak var expectation = self.expectation(withDescription: "callback")
        CoreDataStack.constructSQLiteStack(withModelName: "Sample", inBundle: unitTestBundle, withStoreURL: tempStoreURL) { result in
            switch result {
            case .success(let stack):
                self.stack = stack
            case .failure(let error):
                XCTFail("Error constructing stack: \(error)")
            }
            expectation?.fulfill()
        }

        waitForExpectations(withTimeout: 10, handler: nil)
    }

    func testNewObject() {
        let book = Book(in: stack.mainQueueContext)
        XCTAssertNotNil(book)
    }

    func testFindFirst() {
        do {
            let _ = Book(in: stack.mainQueueContext)
            try stack.mainQueueContext.saveContextAndWait()

            guard let firstBook = try Book.findFirst(in: stack.mainQueueContext) else {
                XCTFail("First Book not found"); return
            }
            firstBook.title = "Testing"
            try! stack.mainQueueContext.saveContextAndWait()

            let predicate1 = Predicate(format: "title CONTAINS[cd] %@", "Bob")
            let notFound = try Book.findFirst(in: stack.mainQueueContext, predicate: predicate1)
            XCTAssertNil(notFound)

            let predicate2 = Predicate(format: "title CONTAINS[cd] %@", "Test")
            guard let _ = try Book.findFirst(in: stack.mainQueueContext, predicate: predicate2) else {
                XCTFail("Failed to find first with matching title."); return
            }
        } catch {
            failingOn(error)
        }
    }

    func testallInContext() {
        let totalBooks = 5
        for _ in 0..<totalBooks {
            let _ = Book(in: stack.mainQueueContext)
            try! stack.mainQueueContext.saveContextAndWait()
        }

        do {
            let allBooks = try Book.all(in: stack.mainQueueContext)
            XCTAssertEqual(allBooks.count, totalBooks)
        } catch {
            failingOn(error)
        }
    }

    func testAllInContextWithPredicateAndSortDescriptor() {
        let iOSBook = Book(in: stack.mainQueueContext)
        iOSBook.title = "iOS Programming: The Big Nerd Ranch Guide"

        let swiftBook = Book(in: stack.mainQueueContext)
        swiftBook.title = "Swift Programming: The Big Nerd Ranch Guide"

        let warAndPeace = Book(in: stack.mainQueueContext)
        warAndPeace.title = "War and Peace"

        do {
            try stack.mainQueueContext.save()
        } catch {
            XCTFail("Failed to save with error: \(error)")
        }

        let sortDescriptors = [SortDescriptor(key: "title", ascending: true)]
        let predicate = Predicate(format: "title CONTAINS[cd] %@", "Big Nerd Ranch")

        do {
            let matchingBooks = try Book.all(in: stack.mainQueueContext, predicate: predicate, sortDescriptors: sortDescriptors)
            XCTAssertEqual(matchingBooks.count, 2)
            XCTAssertEqual(matchingBooks.first, swiftBook)
            XCTAssertEqual(matchingBooks.last, iOSBook)
        } catch {
            XCTFail("Failed to fetch with error: \(error)")
        }
    }
    
    func testCountInContext() {
        let totalBooks = 5
        for _ in 0..<totalBooks {
            let _ = Book(in: stack.mainQueueContext)
            try! stack.mainQueueContext.saveContextAndWait()
        }
        
        do {
            let booksCount = try Book.count(in: stack.mainQueueContext)
            XCTAssertEqual(booksCount, totalBooks)
        } catch {
            failingOn(error)
        }
    }
    
    func testCountInContextWithPredicate() {
        let iOSBook = Book(in: stack.mainQueueContext)
        iOSBook.title = "iOS Programming: The Big Nerd Ranch Guide"
        
        let swiftBook = Book(in: stack.mainQueueContext)
        swiftBook.title = "Swift Programming: The Big Nerd Ranch Guide"
        
        let warAndPeace = Book(in: stack.mainQueueContext)
        warAndPeace.title = "War and Peace"
        
        do {
            try stack.mainQueueContext.save()
        } catch {
            XCTFail("Failed to save with error: \(error)")
        }
        
        let predicate = Predicate(format: "title CONTAINS[cd] %@", "Big Nerd Ranch")
        
        do {
            let matchingBooksCount = try Book.count(in: stack.mainQueueContext, predicate: predicate)
            XCTAssertEqual(matchingBooksCount, 2)
        } catch {
            XCTFail("Failed to fetch with error: \(error)")
        }
    }

    func testRemoveAllExcept() {
        let totalBooks = 5
        var exceptionBooks = [Book]()
        for counter in 0..<totalBooks {
            let newBook = Book(in: stack.mainQueueContext)
            try! stack.mainQueueContext.saveContextAndWait()

            if (counter % 2 == 0) {
                exceptionBooks.append(newBook)
            }
        }

        do {
            var allBooks = try Book.all(in: stack.mainQueueContext)
            XCTAssertEqual(allBooks.count, totalBooks)

            try Book.removeAll(in: stack.mainQueueContext, except: exceptionBooks)
            allBooks = try Book.all(in: stack.mainQueueContext)
            XCTAssertEqual(allBooks.count, exceptionBooks.count)
        } catch {
            failingOn(error)
        }
    }

    func testRemoveAll() {
        let totalBooks = 5
        for _ in 0..<totalBooks {
            let _ = Book(in: stack.mainQueueContext)
            try! stack.mainQueueContext.saveContextAndWait()
        }

        do {
            var allBooks = try Book.all(in: stack.mainQueueContext)
            XCTAssertEqual(allBooks.count, totalBooks)

            try Book.removeAll(in: stack.mainQueueContext)
            allBooks = try Book.all(in: stack.mainQueueContext)
            XCTAssertEqual(allBooks.count, 0)
        } catch {
            failingOn(error)
        }
    }
}
