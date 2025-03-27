//
//  RaceBoxLapTimerApp.swift
//  RaceBoxLapTimer
//
//  Created for RaceBox Lap Timer App
//

import SwiftUI

@main
struct RaceBoxLapTimerApp: App {
    @StateObject private var bluetoothManager = BluetoothManager()
    @StateObject private var locationManager = LocationManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bluetoothManager)
                .environmentObject(locationManager)
                .preferredColorScheme(SettingsManager.shared.isDarkModeEnabled ? .dark : .light)
        }
    }
}

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationView {
                HomeView()
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }
            .tag(0)
            
            NavigationView {
                TrackListView()
            }
            .tabItem {
                Label("Tracks", systemImage: "map")
            }
            .tag(1)
            
            NavigationView {
                SessionHistoryView()
            }
            .tabItem {
                Label("History", systemImage: "clock")
            }
            .tag(2)
            
            NavigationView {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(3)
        }
    }
}
