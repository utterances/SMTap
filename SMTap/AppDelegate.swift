//
//  AppDelegate.swift
//  SMTap
//
//  Created by Tim on 10/28/15.
//  Copyright © 2015 Q. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

	enum DefaultsKey:String {
		case CurrentSession
		case TaskHistory
		case SessionHistory
	}
	
	var window: UIWindow?

	fileprivate var engine: ExpEngine { return (self.window?.rootViewController as! ViewController).engine }
	
	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
		
		let defaults = UserDefaults.standard

		if let nsSession = defaults.array(forKey: DefaultsKey.CurrentSession.rawValue) {
			for r in nsSession {
				let rs = r as! NSArray
                let item = ExpEngine.Task(length: rs[0] as! Int, repeats: rs[1] as! Int, type: ExpEngine.TaskType(rawValue: rs[2] as! String)!, seedID: rs[3] as! Int)
				engine.session.append(item)
			}
		}
		
		if let tasks = defaults.array(forKey: DefaultsKey.TaskHistory.rawValue) {
			for r in tasks {
				let rs = r as! NSArray
				let item = ExpEngine.Task(length: rs[0] as! Int, repeats: rs[1] as! Int, type: ExpEngine.TaskType(rawValue: rs[2] as! String)!, seedID: rs[3] as! Int)
				engine.taskHistory.append(item)
			}
		}

		if let sessions = defaults.array(forKey: DefaultsKey.SessionHistory.rawValue) {
			for r in sessions {
				let rs = r as! NSArray
				var tasks: [ExpEngine.Task] = []
				for i in rs[0] as! NSArray {
					let i = i as! NSArray
					let item = ExpEngine.Task(length: i[0] as! Int, repeats: i[1] as! Int, type: ExpEngine.TaskType(rawValue: i[2] as! String)!, seedID: i[3] as! Int)
					tasks.append(item)
				}
				engine.sessionHistory.append(ExpEngine.Session(tasks: tasks, date: rs[1] as! Date))
			}
		}
		
		return true
	}

	func applicationWillResignActive(_ application: UIApplication) {
		// Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
		// Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
		saveStates()
	}

	func applicationDidEnterBackground(_ application: UIApplication) {
		// Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
		// If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
	}

	func applicationWillEnterForeground(_ application: UIApplication) {
		// Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
	}

	func applicationDidBecomeActive(_ application: UIApplication) {
		// Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
	}

	func applicationWillTerminate(_ application: UIApplication) {
		// Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
	}

	fileprivate func saveStates() {
		let array = engine.session.map{[$0.length, $0.repeats, $0.type.rawValue, $0.seedID]} as NSArray
		UserDefaults.standard.set(array, forKey: DefaultsKey.CurrentSession.rawValue)
		
		let array2 = engine.taskHistory.map{[$0.length, $0.repeats, $0.type.rawValue, $0.seedID]} as NSArray
		UserDefaults.standard.set(array2, forKey: DefaultsKey.TaskHistory.rawValue)

		let array3 = engine.sessionHistory.map{
			[$0.tasks.map{[$0.length, $0.repeats, $0.type.rawValue, $0.seedID]}, $0.date] } as NSArray
		UserDefaults.standard.set(array3, forKey: DefaultsKey.SessionHistory.rawValue)
	}
}

