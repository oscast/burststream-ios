//
//  BurstStreamApp.swift
//  BurstStream
//
//  Created by Oscar Castillo on 10/8/26.
//

import SwiftUI

@main
struct BurstStreamApp: App {
    @UIApplicationDelegateAdaptor(OfflineHLSAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
