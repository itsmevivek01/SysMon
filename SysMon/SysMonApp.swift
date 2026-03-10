//
//  SysMonApp.swift
//  SysMon
//
//  Created by Vivek Krishnan on 11/03/26.
//

import SwiftUI

@main
struct SystemMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView() // no settings window
        }
    }
}
