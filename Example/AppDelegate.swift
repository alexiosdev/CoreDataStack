//
//  AppDelegate.swift
//  Example
//
//  Created by Robert Edwards on 8/6/15.
//  Copyright © 2015 Big Nerd Ranch. All rights reserved.
//

import UIKit

import CoreDataStack

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    private var coreDataStack: CoreDataStack?
    private let mainStoryboard = UIStoryboard(name: "Main", bundle: nil)
    private lazy var loadingVC: UIViewController = {
        return self.mainStoryboard.instantiateViewController(withIdentifier: "LoadingVC")
    }()
    private lazy var myCoreDataVC: MyCoreDataConnectedViewController = {
        return self.mainStoryboard.instantiateViewController(withIdentifier: "CoreDataVC")
            as! MyCoreDataConnectedViewController
    }()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {

        window = UIWindow(frame: UIScreen.main().bounds)
        window?.rootViewController = loadingVC
        
        CoreDataStack.constructSQLiteStack(withModelName: "UniqueConstraintModel") { result in
            switch result {
            case .success(let stack):
                self.coreDataStack = stack
                self.seedInitialData()

                // Note don't actually use dispatch_after
                // Arbitrary 2 second delay to illustrate an async setup.
                DispatchQueue.main.after(when: .now() + .seconds(2)){
                    self.myCoreDataVC.coreDataStack = stack
                    self.window?.rootViewController = self.myCoreDataVC
                }
            case .failure(let error):
                assertionFailure("\(error)")
            }
        }

        window?.makeKeyAndVisible()

        return true
    }

    private func seedInitialData() {
        guard let stack = coreDataStack else {
            assertionFailure("Stack was not setup first")
            return
        }

        let moc = stack.newChildContext()
        do {
            try moc.performAndWaitOrThrow {
                let books = StubbedBookData.books
                for bookTitle in books {
                    let book = Book(in: moc)
                    book.title = bookTitle
                }
                try moc.saveContextAndWait()
            }
        } catch {
            print("Error creating initial data: \(error)")
        }
    }
}

