//
//  SwiftCache.swift
//  SwiftCache
//
//  Created by Tbxark on 06/10/2016.
//  Copyright © 2016 Tbxark. All rights reserved.
//

import Foundation

public class SwiftCache<Key: CacheKey, Value: Cacheable> {

    public var name: String? = nil {
        didSet {
            memoryCache.name = name
            diskCache.name = name
        }
    }
    public let memoryCache: MemoryCache<Key, Value>
    public let diskCache: DiskCache<Key, Value>
    
    convenience public init?(name: String) {
        guard let folder = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.cachesDirectory,
                                                               FileManager.SearchPathDomainMask.userDomainMask,
                                                               true).first else { return nil }
        let path = (folder as NSString).appendingPathComponent(name)
        self.init(path: path)
        self.name = name
    }
    
    public init?(path: String) {
        guard let disk = DiskCache<Key, Value>(path: path, threshold: 1024 * 20) else { return nil }
        diskCache = disk
        memoryCache = MemoryCache<Key, Value>()
        name = MD5Encoder.encodeMd5(string: path)
    }
    
}


extension SwiftCache {
    
    /// Contain
    public func containsObjectForKey(_ key: Key) -> Bool {
        return memoryCache.containsObjectForKey(key) || diskCache.containsObjectForKey(key)
    }

    public func containsObjectForKey(_ key: Key, handle: ((Key, Bool) -> Void)?) {
        guard let hd = handle else { return }
        if memoryCache.containsObjectForKey(key) {
            hd(key, true)
        } else {
            diskCache.containsObjectForKey(key, handle: hd)
        }
    }
    
    /// Get
    public func valueForKey(_ key: Key) -> Value? {
        if let v = memoryCache.valueForKey(key) {
            return v
        } else if let v = diskCache.valueForKey(key) {
            memoryCache.setValue(v, withkey: key)
            return v
        } else {
            return nil
        }
    }
    
    public func valueForKey(_ key: Key, handle: ((_ key: Key, _ value: Value?) -> Void)?) {
        guard let hd = handle else { return }
        if let v = memoryCache.valueForKey(key) {
            hd(key, v)
        } else {
            diskCache.valueForKey(key, handle: hd)
        }
    }
    
    
    /// Set
    public func setValue(_ value: Value?, withkey key: Key) {
        memoryCache.setValue(value, withkey: key)
        diskCache.setValue(value, withkey: key)
    }
    
    public func setValue(_ value: Value?, withkey key: Key, handle: (() -> Void)?) {
        memoryCache.setValue(value, withkey: key)
        diskCache.setValue(value, withkey: key, handle: handle)
    }
    
    
    /// Remove
    public func removeValueForKey(_ key: Key) {
        diskCache.removeValueForKey(key)
        memoryCache.removeValueForKey(key)
    }
    
    public func removeAllValue() {
        diskCache.removeAllValue()
        memoryCache.removeAllValue()
    }
    
    public func removeValueForKey(_ key: Key, handle: (() -> Void)?) {
        diskCache.removeValueForKey(key, handle: handle)
        memoryCache.removeValueForKey(key)
    }
    
    public func removeAllValues(_ handle: (() -> Void)?) {
        diskCache.removeAllValues(handle)
        memoryCache.removeAllValue()
    }
    
    public func removeAllValues(_ progress: ((_ removedCount: UInt, _ totalCount: UInt) -> Void)?, handle: (() -> Void)?) {
        diskCache.removeAllValues(progress, handle: handle)
        memoryCache.removeAllValue()
    }
}
