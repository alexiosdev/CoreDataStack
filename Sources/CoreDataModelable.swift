//
//  CoreDataModelable.swift
//  CoreDataStack
//
//  Created by Robert Edwards on 11/18/15.
//  Copyright © 2015 Big Nerd Ranch. All rights reserved.
//

import CoreData

/**
 Protocol to be conformed to by `NSManagedObject` subclasses that allow for convenience
    methods that make fetching, inserting, deleting, and change management easier.
 */
@objc public protocol CoreDataModelable {
    /**
     The name of your `NSManagedObject`'s entity within the `XCDataModel`.

     - returns: String: Entity's name in `XCDataModel`
     */
    static var entityName: String { get }
}

/**
 Extension to `CoreDataModelable` with convenience methods for
 creating, deleting, and fetching entities from a specific `NSManagedObjectContext`.
 */
extension CoreDataModelable where Self: NSManagedObject {

    // MARK: - Creating Objects
    /**
     Creates a new instance of the Entity within the specified `NSManagedObjectContext`.
     
     - parameter in: `NSManagedObjectContext` to create the object within.
     - parameter inserted: Whether this object is inserted into managed object context. Default true. set to false when you only want use with temporary object purpose.
     
     - returns: `Self`: The newly created entity.
     */
    public init(in context:NSManagedObjectContext, isInserted:Bool = true){
        self.init(entity: Self.entityDescription(in: context), insertInto: isInserted ? context : nil)
    }

    // MARK: - Finding Objects

    /**
    Creates an `NSEntityDescription` of the `CoreDataModelable` entity using the `entityName`

    - parameter context: `NSManagedObjectContext` to create the object within.

    - returns: `NSEntityDescription`: The entity description.
    */
    static public func entityDescription(in context: NSManagedObjectContext) -> NSEntityDescription! {
        guard let entity = NSEntityDescription.entity(forEntityName: entityName, in: context) else {
            assertionFailure("Entity named \(entityName) doesn't exist. Fix the entity description or naming of \(Self.self).")
            return nil
        }
        return entity
    }

    /**
     Creates a new fetch request for the `CoreDataModelable` entity.
     There's class function named fetchRequest from iOSApplicationExtension10, so the only way was to use request.
    */
    static public func request() -> NSFetchRequest<Self>{
        return NSFetchRequest(entityName: entityName)
    }
    
    /**
     Creates a new fetch request for the `CoreDataModelable` entity.

     - parameter context: `NSManagedObjectContext` to create the object within.

     - returns: `NSFetchRequest`: The new fetch request.
     */
    static public func fetchRequestForEntity(in context: NSManagedObjectContext) -> NSFetchRequest<Self> {
        let fetchRequest:NSFetchRequest<Self> = NSFetchRequest(entityName: entityName)
        fetchRequest.entity = entityDescription(in: context)
        return fetchRequest
    }

    /**
    Fetches the first Entity that matches the optional predicate within the specified `NSManagedObjectContext`.

    - parameter context: `NSManagedObjectContext` to find the entities within.
    - parameter predicate: An optional `NSPredicate` for filtering
    
    - throws: Any error produced from `executeFetchRequest`

    - returns: `Self?`: The first entity that matches the optional predicate or `nil`.
    */
    static public func findFirst(in context: NSManagedObjectContext, predicate: Predicate? = nil) throws -> Self? {
        let fetchRequest = request()
        fetchRequest.predicate = predicate
        fetchRequest.fetchLimit = 1
        fetchRequest.returnsObjectsAsFaults = false
        fetchRequest.fetchBatchSize = 1
        return try context.fetch(fetchRequest).first
    }

    /**
     Fetches all Entities within the specified `NSManagedObjectContext`.

     - parameter context: `NSManagedObjectContext` to find the entities within.
     - parameter sortDescriptors: Optional array of `NSSortDescriptors` to apply to the fetch
     - parameter predicate: An optional `NSPredicate` for filtering

     - throws: Any error produced from `executeFetchRequest`

     - returns: `[Self]`: The array of matching entities.
     */
    static public func all(in context: NSManagedObjectContext, predicate: Predicate? = nil, sortDescriptors: [SortDescriptor]? = nil) throws -> [Self] {
        let fetchRequest = request()
        fetchRequest.sortDescriptors = sortDescriptors
        fetchRequest.predicate = predicate
        return try context.fetch(fetchRequest)
    }
    
    // MARK: - Counting Objects
    
    /**
     Returns count of Entities that matches the optional predicate within the specified `NSManagedObjectContext`.
     
     - parameter context: `NSManagedObjectContext` to count the entities within.
     - parameter predicate: An optional `NSPredicate` for filtering
     
     - throws: Any error produced from `countForFetchRequest`
     
     - returns: `Int`: Count of entities that matches the optional predicate.
     */
    static public func count(in context: NSManagedObjectContext, predicate: Predicate? = nil) throws -> Int {
        let fetchReqeust = request()
        fetchReqeust.includesSubentities = false
        fetchReqeust.predicate = predicate
        return try context.count(for: fetchReqeust)
    }

    // MARK: - Removing Objects

    /**
    Removes all entities from within the specified `NSManagedObjectContext`.

    - parameter context: `NSManagedObjectContext` to remove the entities from.
    
    - throws: Any error produced from `executeFetchRequest`
    */
    static public func removeAll(in context: NSManagedObjectContext) throws {
        let fetchRequest = request()
        try removeAll(by: fetchRequest, inContext: context)
    }

    /**
     Removes all entities from within the specified `NSManagedObjectContext` excluding a supplied array of entities.

     - parameter context: The `NSManagedObjectContext` to remove the Entities from.
     - parameter except: An Array of `NSManagedObjects` belonging to the `NSManagedObjectContext` to exclude from deletion.

     - throws: Any error produced from `executeFetchRequest`
     */
    static public func removeAll(in context: NSManagedObjectContext, except toKeep: [Self]) throws {
        let fetchRequest = request()
        fetchRequest.predicate = Predicate(format: "NOT (self IN %@)", toKeep)
        try removeAll(by: fetchRequest, inContext: context)
    }

    // MARK: Private Funcs

    static private func removeAll(by fetchRequest: NSFetchRequest<Self>, inContext context: NSManagedObjectContext) throws {
        // TODO: rcedwards A batch delete would be more efficient here on iOS 9 and up 
        //                  however it complicates things since the request requires a context with
        //                  an NSPersistentStoreCoordinator directly connected. (MOC cannot be a child of another MOC)
        fetchRequest.includesPropertyValues = false
        fetchRequest.includesSubentities = false
        try context.fetch(fetchRequest).lazy.forEach(context.delete)
    }
}
