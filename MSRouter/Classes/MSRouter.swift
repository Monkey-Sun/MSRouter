//
//  MSRouter.swift
//  MSRouterPlugin
//
//  Created by 孙俊祥 on 2023/4/21.
//

import Foundation

fileprivate let schemeKey = "scheme"
fileprivate let methodKey = "method"
public class MSRouter : NSObject {
    public static let share = MSRouter()
    private var routerMap = [String:String]()
    private let queue = DispatchQueue(label: "com.ms.router")
    private var didStart = false
    
    public func start() {
        queue.async {
            if self.didStart { return }
            self.didStart = true
            let bundle = Bundle.main.bundlePath
            var plistInfoList = [String]()
            self.recursiveGetPlistPath(prePath: bundle, infoPlistPaths: &plistInfoList)
            self.readPlistData(plistPathList: plistInfoList)
        }
    }
    
    /// convenice get navigationController with router
    public var navigationController: UINavigationController? {
        assert(Thread.isMainThread, "必须主线程访问")
        return UIApplication.shared.keyWindow?.rootViewController as? UINavigationController
    }
    
    /// open scheme
    /// - Parameter urlString: targetScheme
    public func process(urlString:String) {
        guard let url = URL(string: urlString) else { return }
        process(url: url)
    }
    
    /// open scheme
    /// - Parameter url: target scheme
    public func process(url:URL) {
        process(url: url, ext: nil)
    }
    
    /// open scheme with ext
    /// - Parameters:
    ///   - urlString: target scheme
    ///   - ext: addtional params
    public func process(urlString:String, ext:[String:Any]?) {
        guard let url = URL(string: urlString) else { return }
        process(url: url, ext: ext)
    }
    
    /// open scheme with ext
    /// - Parameters:
    ///   - url: target scheme
    ///   - ext: addtional params
    public func process(url:URL, ext:[String:Any]?) {
        let components = URLComponents(string: url.absoluteString)
        var params = [String:Any]()
        if let queryItems = components?.queryItems {
            for query in queryItems {
                params[query.name] = query.value
            }
        }
        if let map = ext {
            for (key, val) in map {
                params[key] = val
            }
        }
        if let path = url.absoluteString.components(separatedBy: "//").last {
            var ret:String? = path
            if params.values.count > 0 {
                ret = path.components(separatedBy: "?").first
            }
            guard let targetScheme = ret else { return }
            handle(path: targetScheme, params: params)
        }
    }
}

// private
extension MSRouter {
    fileprivate func recursiveGetPlistPath(prePath:String, infoPlistPaths:inout [String]) {
        if let files = try? FileManager.default.contentsOfDirectory(atPath: prePath) {
            for item in files {
                let subPath = "\(prePath)/\(item)"
                if item.hasPrefix(schemeKey), item.hasSuffix("plist") {
                    infoPlistPaths.append(subPath)
                } else {
                    recursiveGetPlistPath(prePath: subPath, infoPlistPaths: &infoPlistPaths)
                }
            }
        }
    }
    
    fileprivate func readPlistData(plistPathList:[String]) {
        for path in plistPathList {
            if let array = NSArray(contentsOfFile: path) {
                for item in array {
                    if let map = item as? [String:String], let key = map[schemeKey] {
                        routerMap[key] = map[methodKey]
                    }
                }
            } else {
                if let map = NSDictionary(contentsOfFile: path) as? [String:String] {
                    if let key = map[schemeKey] {
                        routerMap[key] = map[methodKey]
                    }
                }
            }
        }
        
    }
    
    fileprivate func handle(path:String, params:[String:Any]) {
        queue.async {
            let task = {
                guard let selectorStr = self.routerMap[path] else { return }
                let selector = NSSelectorFromString(selectorStr)
                DispatchQueue.main.async {
                    self.perform(selector, with: params)
                }
            }
            if self.didStart {
                task()
            } else {
                self.start()
                self.queue.async {
                    task()
                }
            }
        }
    }
}
