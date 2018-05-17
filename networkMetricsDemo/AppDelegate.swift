//
//  AppDelegate.swift
//  networkMetricsDemo
//
//  Created by shiva  kumar on 19/08/17.
//  Copyright © 2017 shiva  kumar. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var reachability:CoreDataNetworkReachability? = nil


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        setupNetworkReachability()
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    private func setupNetworkReachability() {
        
        do {
            reachability = try CoreDataNetworkReachability.reachabilityForInternetConnection()
        } catch {
            print("Unable to create Reachability")
            return
        }
        
        reachability?.whenReachable = { reachability in
            
            DispatchQueue.main.async {
                
                if reachability.isReachableViaWiFi() {
                    NotificationCenter.default.post(name:NSNotification.Name(rawValue: "reachabilityUpdate"), object: reachability, userInfo: ["Network":"Wifi"])
                    print("Reachable via Wi-Fi")
                } else {
                    NotificationCenter.default.post(name:NSNotification.Name(rawValue: "reachabilityUpdate"), object: reachability, userInfo: ["Network":"Cellular"])
                    print("Reachable via Cellular")
                }
            }
            
        }
        reachability?.whenUnreachable = { reachability in
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(name:NSNotification.Name(rawValue: "reachabilityUpdate"), object: reachability, userInfo: ["Network":"NotReachable"])
                print("Not Reachable")
            }
        }
        
        do{
            try reachability?.startNotifier()
        }catch{
            print("could not start reachability notifier")
        }
    }
}



