//
//  Cacheable.swift
//  SwiftCache
//
//  Created by Tbxark on 28/09/2016.
//  Copyright © 2016 Tbxark. All rights reserved.
//

#if os(iOS)
import UIKit
#else
import Foundation
#endif

public typealias CacheKey = CustomStringConvertible & Hashable
public let TimeIntervalMax = TimeInterval(DBL_MAX)

public protocol Cacheable {
    associatedtype SelfType
    static func build(_ data: Data) -> SelfType?
    func mapToData() -> Data?
}



public protocol BaseCacheContainer: class {

    associatedtype KeyType
    associatedtype ValueType
        
    var countLimit: UInt { get }
    var costLimit: UInt { get }
    var ageLimit: TimeInterval { get }
    var autoTrimInterval: TimeInterval { get }
    
    var totalCount: UInt { get }
    var totalCost: UInt { get }
    
    func containsObjectForKey(_ key: KeyType) -> Bool
    func valueForKey(_ key: KeyType) -> ValueType?
    func setValue(_ value: ValueType?, withkey key: KeyType)
   
    func removeValueForKey(_ key: KeyType)
    func removeAllValue()
    
    func trimToCount(_ count: UInt)
    func trimToCost(_ cost: UInt)
    func trimToAge(_ age: TimeInterval)
}


public protocol DiskCacheContainer: BaseCacheContainer {
    
    
    init?(path: String, threshold: UInt)

    var freeDiskSpaceLimit: UInt { get }
    var path: String { get }
    
    func containsObjectForKey(_ key: KeyType, handle: ((KeyType, Bool) -> Void)?)
    func valueForKey(_ key: KeyType, handle: ((_ key: KeyType, _ value: ValueType?) -> Void)?)
    func setValue(_ value: ValueType?, withkey key: KeyType, handle: (() -> Void)?)
    
    func removeValueForKey(_ key: KeyType, handle: (() -> Void)?)
    func removeAllValues(_ handle: (() -> Void)?)
    func removeAllValues(_ progress: ((_ removedCount: UInt, _ totalCount: UInt) -> Void)?, handle: (() -> Void)?)
    
    func totalCount(_ calculate: ((_ count: UInt) -> Void)?)
    func trimToCount(_ count: UInt, handle: (() -> Void)?)
    func trimToCost(_ cost: UInt, handle: (() -> Void)?)
    func trimToAge(_ age: TimeInterval, handle: (() -> Void)?)
    
}


public protocol MemoryCacheContainer: BaseCacheContainer {
    
    var releaseOnMainThread: Bool { get }
    var releaseAsynchronously: Bool { get }
    
    var shouldremoveAllValuesOnMemoryWarning: Bool { get }
    var shouldremoveAllValuesWhenEnteringBackground: Bool { get }
    
}




extension NSObject  {
    static public func objToData<T: NSObject>(obj: T) -> Data? where T: NSCoding {
        return NSKeyedArchiver.archivedData(withRootObject: obj)
    }
    static public func dataToObj<T: NSObject>(data: Data, objType: T.Type = T.self) -> T? where T: NSCoding {
        guard let obj =  NSKeyedUnarchiver.unarchiveObject(with: data) else { return nil }
        return obj as? T
    }
}


#if os(iOS)
    extension UIImage: Cacheable {
        
        public func mapToData() -> Data? {
            return UIImageJPEGRepresentation(self, 1)
        }
        
        public static func build(_ data: Data) -> UIImage? {
            return UIImage(data: data)
        }
    }
#endif

