import Foundation
import Combine
import CoreBluetooth

class ConnectionSettingsViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var currentGPSSource: GPSSource = .internal
    @Published var isOBDEnabled = false
    
    @Published var isRaceBoxConnected = false
    @Published var connectedRaceBoxName: String?
    @Published var raceBoxDeviceInfo: RaceBoxDeviceInfo?
    
    @Published var isOBDConnected = false
    @Published var connectedOBDName: String?
    
    @Published var isScanning = false
    @Published var discoveredDevices: [CBPeripheral] = []
    
    @Published var showAlert = false
    @Published var alertTitle = ""
    @Published var alertMessage = ""
    
    // MARK: - Dependencies
    
    private let bluetoothManager: BluetoothManager
    private let settingsManager: SettingsManager
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(bluetoothManager: BluetoothManager = BluetoothManager.shared,
         settingsManager: SettingsManager = SettingsManager.shared) {
        self.bluetoothManager = bluetoothManager
        self.settingsManager = settingsManager
        
        setupSubscriptions()
    }
    
    // MARK: - Public Methods
    
    func loadCurrentSettings() {
        currentGPSSource = settingsManager.gpsSource
        isOBDEnabled = settingsManager.isOBDEnabled
    }
    
    func setGPSSource(_ source: GPSSource) {
        currentGPSSource = source
        settingsManager.gpsSource = source
        
        // Disconnect RaceBox if switching to internal GPS
        if source == .internal && isRaceBoxConnected {
            disconnectRaceBox()
        }
    }
    
    func startScanning() {
        isScanning = true
        bluetoothManager.startScanningForDevices()
    }
    
    func stopScanning() {
        isScanning = false
        bluetoothManager.stopScanningForDevices()
    }
    
    func connectToRaceBox(_ peripheral: CBPeripheral) {
        bluetoothManager.connectToRaceBox(peripheral)
    }
    
    func disconnectRaceBox() {
        bluetoothManager.disconnectRaceBox()
    }
    
    func reconnectRaceBox() {
        if let device = bluetoothManager.raceBoxManager.raceBoxDevice {
            disconnectRaceBox()
            
            // Small delay to ensure clean reconnection
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.connectToRaceBox(device)
            }
        }
    }
    
    func connectToOBD(_ peripheral: CBPeripheral) {
        // This would be implemented once you have your OBD manager set up
        bluetoothManager.connectToOBD(peripheral)
        
        // For now, just show a placeholder message
        showAlert(title: "OBD Support", message: "OBD connection will be implemented in a future update.")
    }
    
    func disconnectOBD() {
        // This would be implemented once you have your OBD manager set up
        bluetoothManager.disconnectOBD()
        
        isOBDConnected = false
        connectedOBDName = nil
    }
    
    // MARK: - Private Methods
    
    private func setupSubscriptions() {
        // Subscribe to RaceBox connection state changes
        bluetoothManager.raceBoxManager.$connectionState
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                guard let self = self else { return }
                
                switch state {
                case .connected:
                    self.isRaceBoxConnected = true
                    if let device = self.bluetoothManager.raceBoxManager.raceBoxDevice {
                        self.connectedRaceBoxName = device.name
                    }
                    
                case .disconnected:
                    self.isRaceBoxConnected = false
                    self.connectedRaceBoxName = nil
                    self.raceBoxDeviceInfo = nil
                    
                case .failed(let error):
                    self.isRaceBoxConnected = false
                    self.connectedRaceBoxName = nil
                    self.raceBoxDeviceInfo = nil
                    self.showAlert(title: "Connection Failed", message: error.localizedDescription)
                    
                default:
                    break
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to RaceBox device info updates
        bluetoothManager.raceBoxManager.$deviceInfo
            .receive(on: RunLoop.main)
            .sink { [weak self] deviceInfo in
                self?.raceBoxDeviceInfo = deviceInfo
            }
            .store(in: &cancellables)
        
        // Subscribe to discovered devices
        bluetoothManager.$discoveredDevices
            .receive(on: RunLoop.main)
            .sink { [weak self] devices in
                self?.discoveredDevices = devices
            }
            .store(in: &cancellables)
        
        // Subscribe to scanning state
        bluetoothManager.$isScanning
            .receive(on: RunLoop.main)
            .sink { [weak self] isScanning in
                self?.isScanning = isScanning
            }
            .store(in: &cancellables)
    }
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}
