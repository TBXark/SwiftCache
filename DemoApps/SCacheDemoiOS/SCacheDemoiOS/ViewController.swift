import UIKit
import SCache


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

class ViewController: UIViewController {

    let imageCache = SwiftCache<String, UIImage>(name: "Image")
    let structCache = SwiftCache<Int, CacheStruct>(name: "Struct")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // cache image  test
        imageCache?.setValue(UIImage(named: "logo"), withkey: "logo")
        let imgv = UIImageView()
        imgv.frame.size = CGSize(width: 100, height: 100)
        view.addSubview(imgv)
        imgv.center = view.center
        imageCache?.memoryCache.removeAllValue()
        imgv.image = imageCache?.valueForKey("logo")
        
        
        
        
        // cache struct  test
        let a = CacheStruct(name: "A", value: "A")
        let b = CacheStruct(name: "B", value: "B")
        structCache?.setValue(a, withkey: 1)
        structCache?.setValue(b, withkey: 2)
        
        if let aCache = structCache?.valueForKey(1) {
            print(aCache)
        }
        
        structCache?.memoryCache.removeAllValue()
        structCache?.valueForKey(2, handle: { (key: Int, value: CacheStruct?) in
            if let v = value {
                print(v)
            }
        })
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

}
