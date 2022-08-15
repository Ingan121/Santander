//
//  AppDelegate.swift
//  Santander
//
//  Created by Serena on 21/06/2022
//
	

import UIKit
import PersonaSpawn

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        // Try obtaining root using com.apple.private.persona-mgmt entitlement
        if getuid() != 0 {
            var attr: posix_spawnattr_t?
            posix_spawnattr_init(&attr)
            posix_spawnattr_setflags(&attr, Int16(POSIX_SPAWN_SETEXEC))
            posix_spawnattr_set_persona_np(&attr, 99, 1)
            posix_spawnattr_set_persona_uid_np(&attr, 0)
            posix_spawnattr_set_persona_gid_np(&attr, 0)

            var pid: pid_t = 0
            var argv: [UnsafeMutablePointer<CChar>?] = [CommandLine.unsafeArgv[0], nil]
            let result = posix_spawn(&pid, CommandLine.arguments[0], nil, &attr, &argv, environ)
        }
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }


}

