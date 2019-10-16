//
//  AppDelegate.swift
//  Split
//
//  Created by Alfred Woo on 2019/10/11.
//  Copyright © 2019 Alfred Woo. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        return true
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        guard let home = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first else { return }
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: home) else { return }
        print("files: \(files)")
        for file in files {
            let path = "\(home)/\(file)"
            print("file path: \(path)")
            try? FileManager.default.removeItem(atPath: path)
        }
    }

}



extension String {
    
    func localized() -> String {
        return NSLocalizedString(self, comment: self)
    }
    
}
