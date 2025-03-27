//
//  SettingsViewModel.swift
//  CornerCut
//

import Foundation
import Combine
import SwiftUI

class SettingsViewModel: ObservableObject {
    // MARK: - Published Properties
    
    // General settings
    @Published var isDarkModeEnabled: Bool = false
    @Published var unitSystem: UnitSystem = .imperial
    @Published var sampleRate: SampleRate = .hz25
    
    // App information
    @Published var appVersion: String = ""
    @Published var buildNumber: String = ""
    
    // MARK: - Dependencies
    
    private let settingsManager = SettingsManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        loadSettings()
        loadAppInfo()
    }
    
    // MARK: - Public Methods
    
    func loadSettings() {
        isDarkModeEnabled = settingsManager.isDarkModeEnabled
        unitSystem = settingsManager.unitSystem
        sampleRate = settingsManager.sampleRate
    }
    
    func updateDarkMode(_ enabled: Bool) {
        isDarkModeEnabled = enabled
        settingsManager.isDarkModeEnabled = enabled
    }
    
    func updateUnitSystem(_ system: UnitSystem) {
        unitSystem = system
        settingsManager.unitSystem = system
    }
    
    func updateSampleRate(_ rate: SampleRate) {
        sampleRate = rate
        settingsManager.sampleRate = rate
    }
    
    // MARK: - Private Methods
    
    private func loadAppInfo() {
        if let info = Bundle.main.infoDictionary {
            appVersion = info["CFBundleShortVersionString"] as? String ?? "1.0"
            buildNumber = info["CFBundleVersion"] as? String ?? "1"
        }
    }
}
