//
//  KVStorage.swift
//  SwiftCache
//
//  Created by Tbxark on 26/09/2016.
//  Copyright © 2016 Tbxark. All rights reserved.
//

import Foundation
#if !USING_BUILTIN_SQLITE
#if os(OSX)
    import SQLiteMacOSX
    #elseif os(iOS)
#if (arch(i386) || arch(x86_64))
    import SQLiteiPhoneSimulator
    #else
    import SQLiteiPhoneOS
#endif
    #elseif os(watchOS)
#if (arch(i386) || arch(x86_64))
    import SQLiteWatchSimulator
    #else
    import SQLiteWatchOS
#endif
#endif
#endif


typealias KVStorageItemSample = (key: String, fileName: String?, size: Int32)

public enum KVStorageValueType {
    case blob(data: Data)
    case text(string: String)
}

public struct KVStorageItem {
    var key: String
    
    var value: Data?
   
    var filename: String?
    
    var size = 0
    var modTime = 0
    var accessTime = 0
}

public enum KVStorageType {
    case file, sqLite, auto
}



public class KVStorage<T: CacheKey> {
    
    open let path: String
    open let type: KVStorageType
    fileprivate let db: KVStorageDatabase
    fileprivate let file: KVStorageFile
    var invalidated: Bool = false {
        didSet {
            db.invalidated =  invalidated
            file.invalidated = invalidated
        }
    }
    var totalItemSize: Int32 {
        return db.totalItemSize
    }
    
    var totalItemCount: Int32 {
        return db.totalItemCount
    }
    
    
    
    init?(path: String, type: KVStorageType) {
        self.path = path
        self.type = type
        let dbPath = (path as NSString).appendingPathComponent(KVStorageDatabase.Config.fileName)
        let dataPath = (path as NSString).appendingPathComponent("data")
        let trashPath = (path as NSString).appendingPathComponent("data")

        db = KVStorageDatabase(path: dbPath)
        file = KVStorageFile(dataPath: dataPath, trashPath: trashPath)
        
        
        do {
            let manager = FileManager.default
            try manager.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
            try manager.createDirectory(atPath: trashPath, withIntermediateDirectories: true, attributes: nil)
            try manager.createDirectory(atPath: dataPath, withIntermediateDirectories: true, attributes: nil)
        } catch {
            return nil
        }
        if !db.open() || !db.initialize() {
            _ = db.close()
            reset()
            if !db.open() || !db.initialize() {
                _ = db.close()
                return nil
            }
        }
        file.emptyTrashInBackground()
        #if os(iOS)
        NotificationCenter.default
            .addObserver(self,
                         selector: #selector(KVStorage.appWillBeTerminated(_:)),
                         name: NSNotification.Name.UIApplicationWillTerminate,
                         object: nil)
        #endif

    }
    
    @objc fileprivate func appWillBeTerminated(_ sender: AnyObject?) {
        invalidated = true
    }
 
    deinit {
        _ = db.close()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Private
extension KVStorage {
    
    fileprivate func reset() {
        do {
            let manager = FileManager.default
            try manager.removeItem(atPath: db.dbPath)
            try manager.removeItem(atPath: (path as NSString).appendingPathComponent(KVStorageDatabase.Config.shmFileName))
            try manager.removeItem(atPath: (path as NSString).appendingPathComponent(KVStorageDatabase.Config.walFileName))
        } catch{
        
        }
        _ = file.moveAllToTrash()
        file.emptyTrashInBackground()
    }
}

// MARK: - Operation
extension KVStorage {
    public func save(item: KVStorageItem) -> Bool {
        return save(key: item.key,
                    value: item.value,
                    filename: item.filename)
    }
    
    public func save(key: String, value: Data?) -> Bool {
        return save(key: key,
                    value: value,
                    filename: nil)
    }
    
    public func save(key: String, value: Data?, filename: String?) -> Bool {
        guard let data = value, key.characters.count > 0 else { return false}
        if type == .file && (filename?.characters.isEmpty ?? true) { return false }
        
        if let name = filename {
            guard file.writeWithName(name, data: data),
                db.saveWithKey(key: key, value: data, fileName: name) else {
                    _ = file.deleteWithName(name)
                    return false
            }
            return true
        } else {
            if type != .sqLite {
                if let name = db.getFilenameWithKeys(key: key) {
                    _ = file.deleteWithName(name)
                }
            }
            return db.saveWithKey(key: key, value: data, fileName: nil)
        }
    }
    
    public func remove(forKey key: String) -> Bool {
        guard key.characters.isEmpty else {
            return false
        }
        switch type {
        case .sqLite:
            return db.deleteItemWithKey(key: key)
        case .auto, .file:
            if let name = db.getFilenameWithKeys(key: key) {
                _ = file.deleteWithName(name)
            }
            return db.deleteItemWithKey(key: key)
        }
    }
    public func remove(forKeys keys: [String]) -> Bool {
        guard keys.isEmpty else {
            return false
        }
        switch type {
        case .sqLite:
            return db.deleteItemsWithKeys(keys: keys)
        case .auto, .file:
            let fileNames = db.getFilenamesWithKeys(keys: keys)
            fileNames?.forEach({ (name) in
                _ = file.deleteWithName(name)
            })
            return db.deleteItemsWithKeys(keys: keys)
        }
    }

    public func remove(largerThan size: Int32) -> Bool {
        if size == Int32.max { return true }
        if size <= 0 { return remove(allItems: ()) }
        switch type {
        case .sqLite:
            if db.deleteItemsWithSizeLargerThan(size: size) {
                db.checkpoint()
                return true
            }
            return false
        case .auto, .file:
            let names = db.getFilenamesWithSizeLargerThan(size: size)
            names?.forEach({ (name) in
                _ = file.deleteWithName(name)
            })
            if db.deleteItemsWithSizeLargerThan(size: size) {
                db.checkpoint()
                return true
            }
            return false
        }
    }
    
    public func remove(earlierThan time: Int32) -> Bool {
        if time < 0{ return true }
        if time == Int32.max { return remove(allItems: ()) }
        switch type {
        case .sqLite:
            if db.deleteItemsWithTimeEarlierThan(time: time) {
                db.checkpoint()
                return true
            }
            return false
        case .auto, .file:
            let names = db.getFilenamesWithTimeEarlierThan(time: time)
            names?.forEach({ (name) in
                _ = file.deleteWithName(name)
            })
            if db.deleteItemsWithTimeEarlierThan(time: time) {
                db.checkpoint()
                return true
            }
            return false
        }
    }
    
    
    public func remove(toFitSize maxSize: Int32) -> Bool {
        if maxSize == Int32.max  { return true}
        if maxSize <= 0 { return remove(allItems: ())  }
        
        var total = db.totalItemSize
        if total < 0 { return false}
        if total <= maxSize { return true }
    
        var items = [KVStorageItemSample]()
        var success = false
        repeat {
            let perCount: Int32 = 16
            guard let temps = db.getItemSizeInfoOrderByTimeDescWithLimit(count: perCount) else { return false}
            items = temps
            for item in temps {
                if total > maxSize {
                    if let name = item.fileName {
                        _ = file.deleteWithName(name)
                    }
                    success = db.deleteItemWithKey(key: item.key)
                    total -= item.size
                } else {
                    break
                }
            }
            if !success { break }
        } while (total > maxSize && items.count > 0 && success)
        
        if success { db.checkpoint() }
        return success
    }
    
    
    public func remove(toFitCount maxCount: Int32) -> Bool {
        if maxCount == Int32.max  { return true}
        if maxCount <= 0 { return remove(allItems: ())  }
        
        var total = db.totalItemCount
        if total < 0 { return false}
        if total <= maxCount { return true }

        var items = [KVStorageItemSample]()
        var success = false
        repeat {
            let perCount: Int32 = 16
            guard let temps = db.getItemSizeInfoOrderByTimeDescWithLimit(count: perCount) else { return false }
            items = temps
            for item in temps {
                if total > maxCount {
                    if let name = item.fileName {
                        _ = file.deleteWithName(name)
                    }
                    success = db.deleteItemWithKey(key: item.key)
                    total -= 1
                } else {
                    break
                }
            }
            if !success { break }
        } while (total > maxCount && items.count > 0 && success)
        
        if success { db.checkpoint() }
        return success
    }
    
    
    
    
    public func remove(allItems progress: (_ removedCount: Int32, _ totalCount: Int32) -> Void,
                       finish: (_ error: Bool) -> Void) {
        let total = db.totalItemCount
        if total <= 0 {
            finish(total<0)
        } else {
            var left = total
            let perCount: Int32 = 32
            var items = [KVStorageItemSample]()
            var success = false
            repeat {
                guard let temps = db.getItemSizeInfoOrderByTimeDescWithLimit(count: perCount) else { break }
                items = temps
                for item in temps {
                    if left > 0 {
                        if let name = item.fileName {
                            _ = file.deleteWithName(name)
                        }
                        success = db.deleteItemWithKey(key: item.key)
                        left -= 1
                    } else {
                        break
                    }
                }
            } while(left < 0 && items.count > 0 && success)
            if success { db.checkpoint() }
            finish(!success)
        }
    }
    
    
    public func itemForKey(key: String) -> KVStorageItem? {
        guard key.characters.count > 0  else {
            return nil
        }
        guard var item = db.getItemWithKey(key: key, excludeInlineData: false) else { return nil }
        if let name = item.filename {
            item.value = file.readWithName(name)
            if item.value == nil {
                _ = db.deleteItemWithKey(key: key)
                return nil
            }
        }
        return item
    }
    
    public func itemInfoForKey(key: String) -> KVStorageItem? {
        guard key.characters.count > 0  else {
            return nil
        }
        return db.getItemWithKey(key: key, excludeInlineData: true)
    }
    
    public func itemValueForKey(key: String) -> Data? {
        guard key.characters.count > 0  else {
            return nil
        }
        var value: Data? = nil
        switch type {
        case .file:
            guard let name = db.getFilenameWithKeys(key: key) else {
                return nil
            }
            if let data = file.readWithName(name) {
                value = data
            } else {
                _ = db.deleteItemWithKey(key: key)
            }
        case .sqLite:
            value = db.getValueWithKeys(key: key)
        case .auto:
            if let name = db.getFilenameWithKeys(key: key) {
                if let data = file.readWithName(name) {
                    value = data
                } else {
                    _ = db.deleteItemWithKey(key: key)
                }
            } else {
                value = db.getValueWithKeys(key: key)
            }
        }
        if value != nil {
            _ = db.updateAccessTimeWithKey(key: key)
        }
        return value
    }
    
    public func itemsForKeys(keys: [String]) -> [KVStorageItem]? {
        guard keys.count > 0  else {
            return nil
        }
        guard var items = db.getItemsWithKeys(keys: keys, excludeInlineData: false),
            items.count > 0 else {
            return nil
        }
        if type != .sqLite {
            var temp = [KVStorageItem]()
            for item in items {
                if let name = item.filename {
                    var copy = item
                    copy.value = file.readWithName(name)
                    temp.append(copy)
                }
            }
            items = temp
        }
        if items.count > 0 {
            _ = db.updateAccessTimeWithKeys(keys: keys)
        }
        return items
    }
    
    
    public func itemInfosForKeys(keys: [String]) -> [KVStorageItem]? {
        guard keys.count > 0  else {
            return nil
        }
        return db.getItemsWithKeys(keys: keys, excludeInlineData: true)
    }
    
    public func itemValuesForKeys(keys: [String]) -> [String: Data]? {
        guard let items = itemsForKeys(keys: keys) else { return nil }
        var dict = [String: Data]()
        for i in items {
            if let data = i.value {
                dict[i.key] = data
            }
        }
        return dict
    }
    
    
    public func containItemforKey(key: String) -> Bool {
        guard key.characters.count > 0  else {
            return false
        }
        return (db.getItemCountWithKey(key: key) ?? 0) > 0
    }
    
    public func remove(allItems: ()) -> Bool {
        guard db.close() else {
            return false
        }
        reset()
        guard db.open() && db.initialize() else {
            return false
        }
        return true
    }
    
}


// MARK: - KVStorageFile
fileprivate final class KVStorageFile {
    
    let dataPath: String
    let trashPath: String
    var invalidated = false
    let trashQueue: DispatchQueue
    
    init(dataPath: String, trashPath: String) {
        self.dataPath = dataPath
        self.trashPath = trashPath
        trashQueue = DispatchQueue(label: "com.swiftCache.disk.trash")
    }

    fileprivate func writeWithName(_ fileName: String, data: Data) -> Bool {
        guard !invalidated else {  return false }
        let path = (dataPath as NSString).appendingPathComponent(fileName)
        return (data as NSData).write(toFile: path, atomically: false)
    }
    
    fileprivate func readWithName(_ fileName: String) -> Data? {
        guard !invalidated else {  return nil }
        let path = (dataPath as NSString).appendingPathComponent(fileName)
        do {
            let data = try NSData(contentsOfFile: path, options: [])
            return data as Data
        } catch {
            return nil
        }
    }
    
    fileprivate func deleteWithName(_ fileName: String) -> Bool {
        guard !invalidated else {  return false }
        let path = (dataPath as NSString).appendingPathComponent(fileName)
        let url = URL(fileURLWithPath: path)
        do {
            try FileManager.default.removeItem(at: url)
            return true
        } catch {
            return false
        }
    }
    
    fileprivate func moveAllToTrash() -> Bool  {
        guard !invalidated else {  return false }
        let uuidRef = CFUUIDCreate(kCFAllocatorDefault)
        let uuid = CFUUIDCreateString(nil, uuidRef)
        let tmpPath = (trashPath as NSString).appendingPathComponent("\(uuid)")
        do {
            try FileManager.default.moveItem(atPath: dataPath, toPath: tmpPath)
            try FileManager.default.createDirectory(atPath: dataPath, withIntermediateDirectories: true, attributes: nil)
            return true
        } catch {
            return false
        }
    }

    fileprivate func emptyTrashInBackground() {
        guard !invalidated else {  return }
        let path = trashPath
        trashQueue.async {
            let manager = FileManager()
            let directoryContents = (try? manager.contentsOfDirectory(atPath: path)) ?? []
            for subPath in directoryContents {
                let fullPath = (path as NSString).appendingPathComponent(subPath)
                _ = try? manager.removeItem(atPath: fullPath)
            }
        }
    }

}


// MARK: - KVStorageDatabase
fileprivate final class KVStorageDatabase {
    
    struct Config {
        static let fileName    = "manifest.sqlite";
        static let shmFileName = "manifest.sqlite-shm";
        static let walFileName = "manifest.sqlite-wal";
        
    }
    var db: SQLiteDatabase? = nil
    let dbPath: String
    var dbStmtCache = [String: SQLiteSTMT]()
    var invalidated = false
    var dbIsClosing = false
    init(path: String) {
        dbPath = path
    }

    fileprivate var isReady: Bool {
        return db != nil &&  !dbIsClosing && !invalidated
    }
    
    fileprivate var totalItemCount: Int32 {
        let sql = "select count(*) from manifest;"
        guard let stmt = prepareStmt(sql: sql) else { return 0 }
        return SQLiteDbUtil.selectData(stmt: stmt, binds: [:], select: [0])?[0]?.int32Value ?? 0
    }

    fileprivate var totalItemSize: Int32 {
        let sql = "select sum(size) from manifest;"
        guard let stmt = prepareStmt(sql: sql) else { return 0 }
        return SQLiteDbUtil.selectData(stmt: stmt, binds: [:], select: [0])?[0]?.int32Value ?? 0
    }
    
    fileprivate func open() -> Bool {
        guard !invalidated || dbIsClosing || db == nil else { return true }
        return sqlite3_open(dbPath, &db) == SQLITE_OK
    }
    
    fileprivate func close() -> Bool {
        guard db != nil ||  dbIsClosing || invalidated else { return true }
        dbStmtCache.removeAll()
        var stmtFinalized = false
        while true {
            var retry = false
            let result = sqlite3_close(db)
            if (result == SQLITE_BUSY || result == SQLITE_LOCKED) {
                if (!stmtFinalized) {
                    stmtFinalized = true
                    while true {
                        let stmt: OpaquePointer = sqlite3_next_stmt(db, nil)
                        if stmt.hashValue == 0 { break }
                        sqlite3_finalize(stmt)
                        retry = true
                    }
                }
            } else if (result != SQLITE_OK) {
            }
            if !retry { break }
        }
        db = nil
        dbIsClosing = false
        return true
    }
    
    fileprivate func initialize() -> Bool {
        let sql = "pragma journal_mode = wal; pragma synchronous = normal; create table if not exists manifest (key text, filename text, size integer, inline_data blob, modification_time integer, last_access_time integer, primary key(key)); create index if not exists last_access_time_idx on manifest(last_access_time);"
        return execute(sql: sql)
    }
    
    fileprivate func checkpoint() {
        guard isReady else { return }
        sqlite3_wal_checkpoint(db, nil)
    }
    
    fileprivate func execute(sql: String) -> Bool {
        guard sql.characters.count > 0 && isReady else { return false  }
        return sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK
    }
    
    fileprivate  func prepareStmt(sql: String) -> SQLiteSTMT? {
        guard isReady else { return nil }
        if let stmt = dbStmtCache[sql] {
            sqlite3_reset(stmt)
            return stmt
        } else {
            guard let stmt = SQLiteDbUtil.prepare(db: db, sql: sql) else { return nil }
            dbStmtCache[sql] = stmt
            return stmt
        }
    }
    
    // MARK: - 完整数据操作
    fileprivate func saveWithKey(key: String, value: Data, fileName: String?) -> Bool {
        let sql = "insert or replace into manifest (key, filename, size, inline_data, modification_time, last_access_time) values (?1, ?2, ?3, ?4, ?5, ?6);"
        guard let stmt = prepareStmt(sql: sql) else { return false  }
        let timestamp = Int32(time(nil))
        sqlite3_bind_text(stmt, 1, key, -1, nil)
        sqlite3_bind_text(stmt, 2, fileName, -1, nil)
        sqlite3_bind_int(stmt, 3, Int32(value.count))
        if fileName?.characters.isEmpty ?? true {
            sqlite3_bind_blob(stmt, 4, (value as NSData).bytes, Int32(value.count), nil)
        } else {
            sqlite3_bind_blob(stmt, 4, nil, 0, nil) // 若有文件名则不存 blob 到数据库
        }
        sqlite3_bind_int(stmt, 5, timestamp)
        sqlite3_bind_int(stmt, 6, timestamp)
        let result = sqlite3_step(stmt)
        return result == SQLITE_DONE
    }
    
    
    fileprivate func getItemFromStmt(stmt: SQLiteSTMT, excludeInlineData: Bool) -> KVStorageItem? {
        func increase(_ i: inout Int32) ->  Int32 {
            defer { i = i + 1 }
            return i
        }
        var i: Int32 = 0
        guard let key = SQLiteDbUtil.string(stmt: stmt, index: increase(&i)) else { return nil }
        let filename = SQLiteDbUtil.string(stmt: stmt, index: increase(&i))
        let size = SQLiteDbUtil.int(stmt: stmt, index: increase(&i))
        let inline_data: Data? = excludeInlineData ? nil : SQLiteDbUtil.blob(stmt: stmt, index: increase(&i))
        if excludeInlineData { _ = increase(&i) }
        let modification_time = SQLiteDbUtil.int(stmt: stmt, index: increase(&i))
        let last_access_time = SQLiteDbUtil.int(stmt: stmt, index: increase(&i))
        return KVStorageItem(key: key, value: inline_data, filename: filename, size: size, modTime: modification_time, accessTime: last_access_time)
    }
    
    fileprivate func getItemWithKey(key: String, excludeInlineData: Bool) -> KVStorageItem? {
        let sql = excludeInlineData ? "select key, filename, size, modification_time, last_access_time from manifest where key = ?1;" : "select key, filename, size, inline_data, modification_time, last_access_time from manifest where key = ?1;"
        guard let stmt = prepareStmt(sql: sql) else { return nil }
        sqlite3_bind_text(stmt, 1, key, -1, nil);
        let result = sqlite3_step(stmt)
        if result == SQLITE_ROW {
            return getItemFromStmt(stmt: stmt, excludeInlineData: excludeInlineData)
        } else {
            return nil
        }
    }
    
    
    fileprivate func getItemsWithKeys(keys: [String], excludeInlineData: Bool) -> [KVStorageItem]? {
        guard isReady else { return nil }
        let keysStr = SQLiteDbUtil.joinedKeys(keys: keys) + " ;"
        let sql = (excludeInlineData ? "select key, filename, size, modification_time, last_access_time from manifest where key in " : "select key, filename, size, inline_data, modification_time, last_access_time from manifest where key in ") + keysStr
        
        guard let stmt = SQLiteDbUtil.prepare(db: db, sql: sql) else { return nil }
        SQLiteDbUtil.bindJoinedKeys(keys: keys, stmt: stmt, fromIndex: 1)
        var items = [KVStorageItem]()
        defer { sqlite3_finalize(stmt) }
        repeat {
            switch sqlite3_step(stmt) {
            case SQLITE_ROW:
                guard let item = getItemFromStmt(stmt: stmt, excludeInlineData: excludeInlineData) else { continue }
                items.append(item)
            case SQLITE_DONE:
                return items
            default:
                return nil
            }
        } while true
    }
    
    
    fileprivate func updateAccessTimeWithKey(key: String) -> Bool {
        let sql = "update manifest set last_access_time = ?1 where key = ?2;"
        guard let stmt = prepareStmt(sql: sql) else {  return false }
        return SQLiteDbUtil.runStep(stmt: stmt, binds: [1: SQLiteDataType.int(value: Int32(time(nil))), 2: SQLiteDataType.string(value: key)])
    }

    fileprivate func updateAccessTimeWithKeys(keys: [String]) -> Bool {
        guard isReady else { return false }
        let t = Int32(time(nil))
        let sql = "update manifest set last_access_time = \(t) where key in (\(SQLiteDbUtil.joinedKeys(keys: keys)));"
        guard let stmt = SQLiteDbUtil.prepare(db: db, sql: sql) else { return false }
        SQLiteDbUtil.bindJoinedKeys(keys: keys, stmt: stmt, fromIndex: 1)
        defer { sqlite3_finalize(stmt) }
        return SQLiteDbUtil.runStep(stmt: stmt)
    }

    fileprivate func deleteItemWithKey(key: String) -> Bool {
        let sql = "delete from manifest where key = ?1;"
        guard let stmt = prepareStmt(sql: sql) else {  return false }
        return SQLiteDbUtil.runStep(stmt: stmt, binds: [1: SQLiteDataType.string(value: key)])
    }
    
    fileprivate func deleteItemsWithKeys(keys: [String]) -> Bool {
        guard isReady else { return false }
        let sql = "delete from manifest where key in (\(SQLiteDbUtil.joinedKeys(keys: keys)));"
        guard let stmt = SQLiteDbUtil.prepare(db: db, sql: sql) else { return false }
        SQLiteDbUtil.bindJoinedKeys(keys: keys, stmt: stmt, fromIndex: 1)
        defer { sqlite3_finalize(stmt) }
        return SQLiteDbUtil.runStep(stmt: stmt)
    }
    
    fileprivate func deleteItemsWithSizeLargerThan(size: Int32) -> Bool {
        let sql = "delete from manifest where size > ?1;"
        guard let stmt = prepareStmt(sql: sql) else {  return false }
        return SQLiteDbUtil.runStep(stmt: stmt, binds: [1: SQLiteDataType.int(value: size)])
    }
    
    fileprivate func deleteItemsWithTimeEarlierThan(time: Int32) -> Bool {
        let sql = "delete from manifest where last_access_time < ?1;"
        guard let stmt = prepareStmt(sql: sql) else {  return false }
        return SQLiteDbUtil.runStep(stmt: stmt, binds: [1: SQLiteDataType.int(value: time)])
    }

    fileprivate func getValueWithKeys(key: String) -> Data? {
        let sql = "select inline_data from manifest where key = ?1;"
        guard let stmt = prepareStmt(sql: sql) else { return nil }
        return SQLiteDbUtil.selectData(stmt: stmt,
                                   binds: [1: SQLiteDataType.string(value: key)],
                                   select: [0])?[0]?.blobValue
    }
    
    fileprivate func getFilenameWithKeys(key: String) -> String? {
        let sql = "select filename from manifest where key = ?1;"
        guard let stmt = prepareStmt(sql: sql) else { return nil }
        return SQLiteDbUtil.selectData(stmt: stmt,
                                       binds: [1: SQLiteDataType.string(value: key)],
                                       select: [0])?[0]?.stringValue
 
    }


    fileprivate func getFilenamesWithKeys(keys: [String]) -> [String]? {
        guard isReady else { return nil }
        let sql = "select filename from manifest where key in " + SQLiteDbUtil.joinedKeys(keys: keys) + " ;"
        guard let stmt = SQLiteDbUtil.prepare(db: db, sql: sql) else { return nil }
        defer {  sqlite3_finalize(stmt) }
        SQLiteDbUtil.bindJoinedKeys(keys: keys, stmt: stmt, fromIndex: 1)
        guard let datas = SQLiteDbUtil.selectDatas(stmt: stmt, binds: [:], select: [0]) else { return nil }
        return datas.flatMap { $0[0]?.stringValue }
    }
    
    
    fileprivate func getFilenamesWithSizeLargerThan(size: Int32) -> [String]? {
        let sql = "select filename from manifest where size > ?1 and filename is not null;"
        guard  let stmt = prepareStmt(sql: sql) else { return nil }
        guard let datas = SQLiteDbUtil.selectDatas(stmt: stmt,
                                                  binds: [1: SQLiteDataType.int(value: size)],
                                                  select: [0]) else { return nil}
        return datas.flatMap { $0[0]?.stringValue }
    }
    
    fileprivate func getFilenamesWithTimeEarlierThan(time: Int32) -> [String]? {
    
        let sql = "select filename from manifest where last_access_time < ?1 and filename is not null;"
        guard  let stmt = prepareStmt(sql: sql) else { return nil }
        guard let datas = SQLiteDbUtil.selectDatas(stmt: stmt,
                                                  binds: [1: SQLiteDataType.int(value: time)],
                                                  select: [0]) else { return nil}
        return datas.flatMap { $0[0]?.stringValue }
    }

    fileprivate func getItemSizeInfoOrderByTimeDescWithLimit(count: Int32) -> [KVStorageItemSample]? {
        let sql = "select key, filename, size from manifest order by last_access_time desc limit ?1;"
        guard  let stmt = prepareStmt(sql: sql) else { return nil }
        guard let datas = SQLiteDbUtil.selectDatas(stmt: stmt,
                                                  binds: [1: SQLiteDataType.int(value: count)],
                                                  select: [0, 1, 2]) else { return nil}
        
        return datas.flatMap { value -> KVStorageItemSample? in
            guard let key = value[0]?.stringValue else { return nil }
            let filename = value[1]?.stringValue
            let size = value[2]?.intValue ?? 0
            return (key, filename, Int32(size))
        }
    }

    fileprivate func getItemCountWithKey(key: String) -> Int? {
        let sql = "select count(key) from manifest where key = ?1;"
        guard let stmt = prepareStmt(sql: sql) else { return nil }
        let count = SQLiteDbUtil.selectData(stmt: stmt,
                                            binds: [1: SQLiteDataType.string(value: key)],
                                            select: [0])?[0]?.intValue
        return count
    }
    
}
