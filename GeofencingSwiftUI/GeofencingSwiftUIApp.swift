//
//  GeofencingSwiftUIApp.swift
//  GeofencingSwiftUI
//
//  Created by Anthony Da cruz on 09/08/2021.
//

import SwiftUI
import LocalConsole

let consoleManager = LCManager.shared

@main
struct GeofencingSwiftUIApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(GeofenceState())
                .onAppear {
                    consoleManager.isVisible = true
                }
        }
    }
}
