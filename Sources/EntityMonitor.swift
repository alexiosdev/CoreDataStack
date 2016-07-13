//
//  EntityMonitor.swift
//  CoreDataStack
//
//  Created by Robert Edwards on 11/18/15.
//  Copyright © 2015 Big Nerd Ranch. All rights reserved.
//

import CoreData

/// The frequency of notification dispatch from the `EntityMonitor`
public enum FireFrequency {
    /// Notifications will be sent upon `NSManagedObjectContext` being changed
    case onChange

    /// Notifications will be sent upon `NSManagedObjectContext` being saved
    case onSave
}

/**
 Protocol for delegate callbacks of `NSManagedObject` entity change events.
 */
public protocol EntityMonitorDelegate: class { // : class for weak capture
    /// Type of object being monitored. Must inheirt from `NSManagedObject` and implement `CoreDataModelable`
    associatedtype T: NSManagedObject, CoreDataModelable, Hashable

    /**
     Callback for when objects matching the predicate have been inserted

     - parameter monitor: The `EntityMonitor` posting the callback
     - parameter entities: The set of inserted matching objects
     */
    func entityMonitorObservedInserts(_ monitor: EntityMonitor<T>, entities: Set<T>)

    /**
     Callback for when objects matching the predicate have been deleted

     - parameter monitor: The `EntityMonitor` posting the callback
     - parameter entities: The set of deleted matching objects
     */
    func entityMonitorObservedDeletions(_ monitor: EntityMonitor<T>, entities: Set<T>)

    /**
     Callback for when objects matching the predicate have been updated

     - parameter monitor: The `EntityMonitor` posting the callback
     - parameter entities: The set of updated matching objects
     */
    func entityMonitorObservedModifications(_ monitor: EntityMonitor<T>, entities: Set<T>)
}

/**
 Class for monitoring changes within a given `NSManagedObjectContext`
    to a specific Core Data Entity with optional filtering via an `NSPredicate`.
 */
public class EntityMonitor<T: NSManagedObject where T: CoreDataModelable, T: Hashable> {

    // MARK: - Public Properties

    /**
     Function for setting the `EntityMonitorDelegate` that will receive callback events.

     - parameter U: Your delegate must implement the methods in `EntityMonitorDelegate` with the matching `CoreDataModelable` type being monitored.
     */
    public func setDelegate<U: EntityMonitorDelegate where U.T == T>(_ delegate: U) {
        self.delegateHost = ForwardingEntityMonitorDelegate(owner: self, delegate: delegate)
    }

    // MARK: - Private Properties

    private var delegateHost: BaseEntityMonitorDelegate<T>? {
        willSet {
            delegateHost?.removeObservers()
        }
        didSet {
            delegateHost?.setupObservers()
        }
    }

    private typealias EntitySet = Set<T>

    private let context: NSManagedObjectContext
    private let frequency: FireFrequency
    private let entityPredicate: Predicate
    private let filterPredicate: Predicate?
    private lazy var combinedPredicate: Predicate = {
        if let filterPredicate = self.filterPredicate {
            return CompoundPredicate(andPredicateWithSubpredicates:
                [self.entityPredicate, filterPredicate])
        } else {
            return self.entityPredicate
        }
    }()

    // MARK: - Lifecycle

    /**
    Initializer to create an `EntityMonitor` to monitor changes to a specific Core Data Entity.

    This initializer is failable in the event your Entity is not within the supplied `NSManagedObjectContext`.

    - parameter context: `NSManagedObjectContext` the context you want to monitor changes within.
    - parameter frequency: `FireFrequency` How frequently you wish to receive callbacks of changes. Default value is `.OnSave`.
    - parameter filterPredicate: An optional filtering predicate to be applied to entities being monitored.
    */
    public init(context: NSManagedObjectContext, frequency: FireFrequency = .onSave, filterPredicate: Predicate? = nil) {
        self.context = context
        self.frequency = frequency
        self.filterPredicate = filterPredicate
        self.entityPredicate = Predicate(format: "entity == %@", T.entityDescription(in: context))
    }

    deinit {
        delegateHost?.removeObservers()
    }
}

private class BaseEntityMonitorDelegate<T: NSManagedObject where T: CoreDataModelable, T: Hashable>: NSObject {

    private let ChangeObserverSelectorName = #selector(BaseEntityMonitorDelegate<T>.evaluateChangeNotification(_:))

    typealias Owner = EntityMonitor<T>
    typealias EntitySet = Owner.EntitySet

    unowned let owner: Owner

    init(owner: Owner) {
        self.owner = owner
    }

    final func setupObservers() {
        let notificationName: Notification.Name
        switch owner.frequency {
        case .onChange:
            notificationName = NSNotification.Name.NSManagedObjectContextObjectsDidChange
        case .onSave:
            notificationName = NSNotification.Name.NSManagedObjectContextDidSave
        }

        NotificationCenter.default.addObserver(self,
            selector: ChangeObserverSelectorName,
            name: notificationName,
            object: owner.context)
    }

    final func removeObservers() {
        NotificationCenter.default.removeObserver(self)
    }

    @objc final func evaluateChangeNotification(_ notification: Notification) {
        guard let changeSet = (notification as NSNotification).userInfo else {
            return
        }

        owner.context.performAndWait { [predicate = owner.combinedPredicate] in
            func process(_ value: AnyObject?) -> EntitySet {
                return ((value as? NSSet)?.filtered(using: predicate) as? EntitySet) ?? []
            }
            let inserted = process(changeSet[NSInsertedObjectsKey])
            let deleted = process(changeSet[NSDeletedObjectsKey])
            let updated = process(changeSet[NSUpdatedObjectsKey])
            self.handleChanges(inserted: inserted, deleted: deleted, updated: updated)
        }
    }

    func handleChanges(inserted: EntitySet, deleted: EntitySet, updated: EntitySet) {
        fatalError()
    }
}

private final class ForwardingEntityMonitorDelegate<Delegate: EntityMonitorDelegate>: BaseEntityMonitorDelegate<Delegate.T> {

    weak var delegate: Delegate?

    init(owner: Owner, delegate: Delegate) {
        super.init(owner: owner)
        self.delegate = delegate
    }

    override func handleChanges(inserted: EntitySet, deleted: EntitySet, updated: EntitySet) {
        guard let delegate = delegate else { return }

        if !inserted.isEmpty {
            delegate.entityMonitorObservedInserts(owner, entities: inserted)
        }

        if !deleted.isEmpty {
            delegate.entityMonitorObservedDeletions(owner, entities: deleted)
        }

        if !updated.isEmpty {
            delegate.entityMonitorObservedModifications(owner, entities: updated)
        }
    }
}
