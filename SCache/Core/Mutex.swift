//
//  Mutex.swift
//  SwiftCache
//
//  Created by Tbxark on 29/09/2016.
//  Copyright © 2016 Tbxark. All rights reserved.
//

import Foundation

class Mutex {
    private let mutex: UnsafeMutablePointer<pthread_mutex_t>
    private let condition: UnsafeMutablePointer<pthread_cond_t>
    private let attribute: UnsafeMutablePointer<pthread_mutexattr_t>
    
    init() {
        
        mutex = UnsafeMutablePointer.allocate(capacity: MemoryLayout<pthread_mutex_t>.size)
        condition = UnsafeMutablePointer.allocate(capacity: MemoryLayout<pthread_cond_t>.size)
        attribute = UnsafeMutablePointer.allocate(capacity: MemoryLayout<pthread_mutexattr_t>.size)
        
        pthread_mutexattr_init(attribute)
        pthread_mutexattr_settype(attribute, PTHREAD_MUTEX_RECURSIVE)
        pthread_mutex_init(mutex, attribute)
        pthread_cond_init(condition, nil)
    }
    
    deinit {
        pthread_cond_destroy(condition);
        pthread_mutexattr_destroy(attribute)
        pthread_mutex_destroy(mutex)
    }
    
    func lock() {
        pthread_mutex_lock(mutex)
    }
    
    func tryLock() -> Int32 {
        return pthread_mutex_trylock(mutex)
    }
    
    func unlock() {
        pthread_mutex_unlock(mutex)
    }
    
    func wait() -> Bool {
        return pthread_cond_wait(condition, mutex) == 0
    }
    
    func signal() -> Bool {
        return pthread_cond_signal(condition) == 0
    }
    
}
