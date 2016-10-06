//
//  LinkedMap.swift
//  SwiftCache
//
//  Created by Tbxark on 29/09/2016.
//  Copyright © 2016 Tbxark. All rights reserved.
//

import Foundation

class LinkedMapNode<Key: Hashable, Value> {
    var value: Value?
    var key: Key
    var time: TimeInterval

    fileprivate(set) var next: LinkedMapNode?
    fileprivate(set) weak var prev: LinkedMapNode?
    fileprivate(set) var cost: UInt = 0
    
    init(key: Key, value: Value?, cost: UInt = 0) {
        self.key = key
        self.value = value
        self.time = Date().timeIntervalSince1970
        self.cost = cost
    }
}

class LinkedMap<Key: Hashable, Value> {
    
    typealias Node = LinkedMapNode<Key, Value>
    private(set) var dict = [Key: LinkedMapNode<Key, Value>]()
    private(set) var totalCost: UInt = 0
    private(set) var totalCount: UInt = 0
    private(set) var head: Node?
    private(set) var tail: Node?
    var isEmpty: Bool { return dict.isEmpty }
    
    
    var totalCostSafe: UInt {
        if var node = head {
            var c: UInt = 0
            while case let next? = node.next {
                node = next
                c += next.cost
            }
            return c
        } else {
            return 0
        }
    }
    var totalCountSafe: UInt {
        if var node = head {
            var c: UInt = 1
            while case let next? = node.next {
                node = next
                c += 1
            }
            return c
        } else {
            return 0
        }
    }
    
    var tailSafe: Node? {
        if var node = head {
            while case let next? = node.next {
                node = next
            }
            return node
        } else {
            return nil
        }
    }
    
    // MARK: - 基本操作 能对 totalCost totalCount 进行操作
    func insertNodeAtHead(node: Node) {
        if let h = head {
            node.next = h
            h.prev = node
            head = node
        } else {
            head = node
        }
        dict[node.key] = node
        
        totalCount += 1
        totalCost += node.cost
    }
    
    func removeNode(node: Node) {
        let prev = node.prev
        let next = node.next
        
        if let p = prev {
            p.next = next
        } else {
            head = next
        }
        next?.prev = prev
        dict[node.key] = nil
        node.prev = nil
        node.next = nil
        
        if let t = tail, t === node {
            tail = tail?.prev
        }
        
        totalCount -= 1
        totalCost -= node.cost
        
    }
    
    
    func replaceNode(node: Node, newNode: Node)  {
        dict[node.key] = newNode
        node.prev?.next = newNode
        node.next?.prev = newNode
        bringNodeToHead(node: newNode)
        
        totalCost += newNode.cost - node.cost
    }
    
    
    subscript(_ key: Key) -> Node? {
        get {
            return dict[key]
        }
        set {
            if let node = newValue {
                guard let old = dict[key] else {
                    insertNodeAtHead(node: node)
                    return
                }
                replaceNode(node: old, newNode: node)
            } else if let node = dict[key] {
                removeNode(node: node)
            }
        }
    }

    func removeAll() {
        dict.removeAll()
        head = nil
        tail = nil
        totalCost = 0
        totalCount = 0
    }


    
    // MARK: 便利操作
    func bringNodeToHead(node: Node) {
        if head === node { return }
        if let t = tail, t === node {
            tail = node.prev
            node.next = nil
        } else {
            node.next?.prev = node.prev
            node.prev?.next = node.next
        }
        
        node.next = head
        node.prev = nil
        
        head?.prev = node
        head = node
    }
    
    
    func removeTailNode() -> Node? {
        guard let tail = self.tail else {
            return nil
        }
        removeNode(node: tail)
        return tail
    }
    
    
    func containNodeByKey(_ key: Key) -> Bool {
        return dict.keys.contains(key)
    }
    
}
