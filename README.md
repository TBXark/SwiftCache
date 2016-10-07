# SwiftCache

SwiftCache is a pure swift cache framework inspired by [YYCache](http://github.com/ibireme/YYCache)
在 OC里面 [YYCache](https://github.com/ibireme/YYCache) 算是最出色的一个缓存框架, 我在研究 YYCache 的代码的时候就顺便用 Swift 仿写了一遍, 毕竟比起看代码, 写代码更能加深理解. 写得时候也充分的利用的 Swift语言的优势, 加上了泛型类 Any 类型的支持(因为YYCache是 OC 写的所以只能缓存 class 类型). 虽然在写指针的时候特别蛋疼.



[![Swift Version][swift-image]][swift-url]
[![License MIT](https://img.shields.io/badge/license-MIT-green.svg?style=flat)](https://raw.githubusercontent.com/TBXark/TKSectorProgressView/master/LICENSE)
[![CocoaPods](http://img.shields.io/cocoapods/v/TKSectorProgressView.svg?style=flat)](http://cocoapods.org/?q= TKSectorProgressView)
[![CocoaPods](http://img.shields.io/cocoapods/p/TKSectorProgressView.svg?style=flat)](http://cocoapods.org/?q= TKSectorProgressView)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Support](https://img.shields.io/badge/support-iOS%208%2B%20-blue.svg?style=flat)](https://www.apple.com/nl/ios/)

## Requirements

- iOS 8.0+
- Xcode 8.0
- Swift 3.0

## Installation

#### Carthage
Create a `Cartfile` that lists the framework and run `carthage update`. Follow the [instructions](https://github.com/Carthage/Carthage#if-youre-building-for-ios) to add `$(SRCROOT)/Carthage/Build/iOS/SCache.framework` to an iOS project.
add `


## Usage example

*UIImage*

```
let imageCache = SwiftCache<String, UIImage>(name: "Image")
imageCache?.setValue(UIImage(named: "test"), withkey: "test")
let img = imageCache?.valueForKey("test")

```

*Struct*

```
struct CacheStruct: Cacheable {

    let name: String
    let value: String

    static func build(_ data: Data) -> CacheStruct? {
        guard let obj = try? JSONSerialization.jsonObject(with: data, options: .allowFragments),
              let dict = obj as? [String: String],
              let n = dict["name"],
              let v = dict["value"]  else { return nil }
        return CacheStruct(name: n, value: v)
    }
    func mapToData() -> Data? {
        let dict = ["name": name, "value": value]
        return try? JSONSerialization.data(withJSONObject: dict, options: [])
    }
}

let structCache = SwiftCache<Int, CacheStruct>(name: "Struct")
let a = CacheStruct(name: "A", value: "A")
structCache?.setValue(a, withkey: 1)
if let aCache = structCache?.valueForKey(1) {
    print(aCache)
}

```

## Thank

[YYCache](https://github.com/ibireme/YYCache) High performance cache framework for iOS.
[GRDB.swift](https://github.com/groue/GRDB.swift)  A Swift application toolkit for SQLite databases, with WAL mode support https://www.sqlite.org
[SwiftMD5](https://github.com/mpurland/SwiftMD5) A pure Swift implementation of MD5


## Contribute

We would love for you to contribute to **SwiftCache**, check the ``LICENSE`` file for more info.

## Meta

TBXark – [@vfanx](https://twitter.com/vfanx) – tbxark@outlook.com

Distributed under the MIT license. See ``LICENSE`` for more information.

[https://github.com/TBXark](https://github.com/TBXark)

[swift-image]:https://img.shields.io/badge/swift-3.0-orange.svg
[swift-url]: https://swift.org/
[license-image]: https://img.shields.io/badge/License-MIT-blue.svg
[license-url]: LICENSE
[travis-image]: https://img.shields.io/travis/dbader/node-datadog-metrics/master.svg?style=flat-square
[travis-url]: https://travis-ci.org/dbader/node-datadog-metrics
[codebeat-image]: https://codebeat.co/badges/c19b47ea-2f9d-45df-8458-b2d952fe9dad
[codebeat-url]: https://codebeat.co/projects/github-com-vsouza-awesomeios-com
