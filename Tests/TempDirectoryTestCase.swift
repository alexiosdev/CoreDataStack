//
//  TempDirectoryTestCase.swift
//  CoreDataStack
//
//  Created by Robert Edwards on 12/17/15.
//  Copyright © 2015 Big Nerd Ranch. All rights reserved.
//

import XCTest

class TempDirectoryTestCase: XCTestCase {

    lazy var tempStoreURL: URL? = {
        return try! self.tempStoreDirectory?.appendingPathComponent("testmodel.sqlite")
    }()

    private lazy var tempStoreDirectory: URL? = {
        let baseURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        
        let tempDir = try! baseURL.appendingPathComponent("XXXXXX")
        do {
            try FileManager.default.createDirectory(at: tempDir,
                withIntermediateDirectories: true,
                attributes: nil)
            return tempDir
        } catch {
            assertionFailure("\(error)")
        }
        return nil
    }()

    private func removeTempDir() {
        if let tempStoreDirectory = tempStoreDirectory {
            do {
                try FileManager.default.removeItem(at: tempStoreDirectory)
            } catch {
                assertionFailure("\(error)")
            }
        }
    }
    
    override func tearDown() {
        removeTempDir()
        super.tearDown()
    }
}
