//
//  RaceBoxPacketDecoder.swift
//  RaceBoxLapTimer
//
//  Created for RaceBox Lap Timer App
//

import Foundation

class RaceBoxPacketDecoder {
    
    // MARK: - UBX Packet Parsing
    
    /// Parse a RaceBox Data Message (0xFF 0x01) from binary data
    static func parseDataMessage(data: Data) -> RaceBoxData? {
        guard data.count >= 80 else {
            print("Data message too short: \(data.count) bytes")
            return nil
        }
        
        var result = RaceBoxData()
        
        // Time information
        result.iTOW = data.extract(UInt32.self, fromOffset: 0)
        result.year = data.extract(UInt16.self, fromOffset: 4)
        result.month = data[6]
        result.day = data[7]
        result.hour = data[8]
        result.minute = data[9]
        result.second = data[10]
        result.validityFlags = data[11]
        result.timeAccuracy = data.extract(UInt32.self, fromOffset: 12)
        result.nanoseconds = data.extract(Int32.self, fromOffset: 16)
        
        // Fix information
        result.fixStatus = data[20]
        result.fixStatusFlags = data[21]
        result.dateTimeFlags = data[22]
        result.numSVs = data[23]
        
        // Location
        let rawLongitude = data.extract(Int32.self, fromOffset: 24)
        result.longitude = Double(rawLongitude) / 10_000_000.0
        
        let rawLatitude = data.extract(Int32.self, fromOffset: 28)
        result.latitude = Double(rawLatitude) / 10_000_000.0
        
        let rawWgsAltitude = data.extract(Int32.self, fromOffset: 32)
        result.wgsAltitude = Double(rawWgsAltitude)
        
        let rawMslAltitude = data.extract(Int32.self, fromOffset: 36)
        result.mslAltitude = Double(rawMslAltitude)
        
        let rawHorizontalAccuracy = data.extract(UInt32.self, fromOffset: 40)
        result.horizontalAccuracy = Double(rawHorizontalAccuracy)
        
        let rawVerticalAccuracy = data.extract(UInt32.self, fromOffset: 44)
        result.verticalAccuracy = Double(rawVerticalAccuracy)
        
        // Movement
        let rawSpeed = data.extract(Int32.self, fromOffset: 48)
        result.speed = Double(rawSpeed)
        
        let rawHeading = data.extract(Int32.self, fromOffset: 52)
        result.heading = Double(rawHeading) / 100_000.0
        
        let rawSpeedAccuracy = data.extract(UInt32.self, fromOffset: 56)
        result.speedAccuracy = Double(rawSpeedAccuracy)
        
        let rawHeadingAccuracy = data.extract(UInt32.self, fromOffset: 60)
        result.headingAccuracy = Double(rawHeadingAccuracy) / 100_000.0
        
        // PDOP
        let rawPDOP = data.extract(UInt16.self, fromOffset: 64)
        result.pdop = Double(rawPDOP) / 100.0
        
        // Flags
        result.latLonFlags = data[66]
        result.batteryStatus = data[67]
        
        // IMU data
        let rawGForceX = data.extract(Int16.self, fromOffset: 68)
        result.gForceX = Double(rawGForceX) / 1000.0
        
        let rawGForceY = data.extract(Int16.self, fromOffset: 70)
        result.gForceY = Double(rawGForceY) / 1000.0
        
        let rawGForceZ = data.extract(Int16.self, fromOffset: 72)
        result.gForceZ = Double(rawGForceZ) / 1000.0
        
        let rawRotationRateX = data.extract(Int16.self, fromOffset: 74)
        result.rotationRateX = Double(rawRotationRateX) / 100.0
        
        let rawRotationRateY = data.extract(Int16.self, fromOffset: 76)
        result.rotationRateY = Double(rawRotationRateY) / 100.0
        
        let rawRotationRateZ = data.extract(Int16.self, fromOffset: 78)
        result.rotationRateZ = Double(rawRotationRateZ) / 100.0
        
        return result
    }
    
    /// Parse a RaceBox Recording Status message (0xFF 0x22)
    static func parseRecordingStatus(data: Data) -> RaceBoxRecordingStatus? {
        guard data.count >= 12 else {
            print("Recording status message too short: \(data.count) bytes")
            return nil
        }
        
        var result = RaceBoxRecordingStatus()
        
        result.isRecording = data[0] != 0
        result.memoryLevel = data[1]
        
        let securityFlags = data[2]
        result.isMemorySecurityEnabled = (securityFlags & 0x01) != 0
        result.isMemoryUnlocked = (securityFlags & 0x02) != 0
        
        result.storedDataMessages = data.extract(UInt32.self, fromOffset: 4)
        result.deviceMemorySize = data.extract(UInt32.self, fromOffset: 8)
        
        return result
    }
    
    // MARK: - UBX Packet Construction
    
    /// Create a memory unlock packet (0xFF 0x30)
    static func createMemoryUnlockPacket(securityCode: UInt32) -> Data {
        var packet = Data()
        
        // Add header
        packet.append(contentsOf: RaceBoxProtocol.packetStartBytes)
        
        // Add class and ID
        packet.append(RaceBoxProtocol.MessageClass.ubx.rawValue)
        packet.append(RaceBoxProtocol.MessageID.memoryUnlock.rawValue)
        
        // Add payload length (4 bytes for security code)
        packet.append(UInt16(4).littleEndianData)
        
        // Add payload (security code)
        packet.append(securityCode.littleEndianData)
        
        // Add checksum
        let checksum = calculateChecksum(packet: packet)
        packet.append(checksum.0)
        packet.append(checksum.1)
        
        return packet
    }
    
    /// Create a platform configuration packet (0xFF 0x27)
    static func createPlatformConfigPacket(config: RaceBoxPlatformConfig) -> Data {
        var packet = Data()
        
        // Add header
        packet.append(contentsOf: RaceBoxProtocol.packetStartBytes)
        
        // Add class and ID
        packet.append(RaceBoxProtocol.MessageClass.ubx.rawValue)
        packet.append(RaceBoxProtocol.MessageID.platformConfig.rawValue)
        
        // Add payload length (3 bytes)
        packet.append(UInt16(3).littleEndianData)
        
        // Add payload
        packet.append(config.platformModel.rawValue)
        packet.append(config.enable3DSpeed ? 1 : 0)
        packet.append(config.minHorizontalAccuracy)
        
        // Add checksum
        let checksum = calculateChecksum(packet: packet)
        packet.append(checksum.0)
        packet.append(checksum.1)
        
        return packet
    }
    
    /// Create a recording configuration packet (0xFF 0x25)
    static func createRecordingConfigPacket(enable: Bool, dataRate: UInt8 = 0, stationary: Bool = true, noFix: Bool = true, autoShutdown: Bool = true, waitForData: Bool = true, stationaryThreshold: UInt16 = 1389, stationaryInterval: UInt16 = 30, noFixInterval: UInt16 = 30, shutdownInterval: UInt16 = 300) -> Data {
        var packet = Data()
        
        // Add header
        packet.append(contentsOf: RaceBoxProtocol.packetStartBytes)
        
        // Add class and ID
        packet.append(RaceBoxProtocol.MessageClass.ubx.rawValue)
        packet.append(RaceBoxProtocol.MessageID.recordingConfig.rawValue)
        
        // Add payload length (12 bytes)
        packet.append(UInt16(12).littleEndianData)
        
        // Add payload
        packet.append(enable ? 1 : 0)
        packet.append(dataRate)
        
        var flags: UInt8 = 0
        if stationary { flags |= 0x02 }
        if noFix { flags |= 0x04 }
        if autoShutdown { flags |= 0x08 }
        if waitForData { flags |= 0x10 }
        packet.append(flags)
        
        packet.append(0) // Reserved
        packet.append(stationaryThreshold.littleEndianData)
        packet.append(stationaryInterval.littleEndianData)
        packet.append(noFixInterval.littleEndianData)
        packet.append(shutdownInterval.littleEndianData)
        
        // Add checksum
        let checksum = calculateChecksum(packet: packet)
        packet.append(checksum.0)
        packet.append(checksum.1)
        
        return packet
    }
    
    /// Create a data erase packet (0xFF 0x24)
    static func createDataErasePacket() -> Data {
        var packet = Data()
        
        // Add header
        packet.append(contentsOf: RaceBoxProtocol.packetStartBytes)
        
        // Add class and ID
        packet.append(RaceBoxProtocol.MessageClass.ubx.rawValue)
        packet.append(RaceBoxProtocol.MessageID.dataErase.rawValue)
        
        // Add payload length (0 bytes)
        packet.append(UInt16(0).littleEndianData)
        
        // Add checksum
        let checksum = calculateChecksum(packet: packet)
        packet.append(checksum.0)
        packet.append(checksum.1)
        
        return packet
    }
    
    /// Create a data download packet (0xFF 0x23)
    static func createDataDownloadPacket() -> Data {
        var packet = Data()
        
        // Add header
        packet.append(contentsOf: RaceBoxProtocol.packetStartBytes)
        
        // Add class and ID
        packet.append(RaceBoxProtocol.MessageClass.ubx.rawValue)
        packet.append(RaceBoxProtocol.MessageID.dataDownload.rawValue)
        
        // Add payload length (0 bytes)
        packet.append(UInt16(0).littleEndianData)
        
        // Add checksum
        let checksum = calculateChecksum(packet: packet)
        packet.append(checksum.0)
        packet.append(checksum.1)
        
        return packet
    }
    
    // MARK: - Checksum Calculation
    
    /// Calculate UBX checksum for a packet (excluding header and checksum bytes)
    static func calculateChecksum(packet: Data) -> (UInt8, UInt8) {
        var ckA: UInt8 = 0
        var ckB: UInt8 = 0
        
        // Start from byte 2 (after header) and go until the end (excluding checksum)
        for i in 2..<packet.count {
            ckA = ckA &+ packet[i]
            ckB = ckB &+ ckA
        }
        
        return (ckA, ckB)
    }
    
    /// Verify checksum for a complete packet
    static func verifyChecksum(packet: Data) -> Bool {
        guard packet.count >= 8 else { return false } // Minimum valid packet size
        
        // Get expected checksum from packet
        let expectedCkA = packet[packet.count - 2]
        let expectedCkB = packet[packet.count - 1]
        
        // Calculate actual checksum
        let (actualCkA, actualCkB) = calculateChecksum(packet: packet.dropLast(2))
        
        return expectedCkA == actualCkA && expectedCkB == actualCkB
    }
}

// MARK: - Data Extensions for Binary Parsing
extension Data {
    func extract<T>(_ type: T.Type, fromOffset offset: Int) -> T where T: FixedWidthInteger {
        let size = MemoryLayout<T>.size
        guard offset + size <= self.count else {
            fatalError("Trying to extract beyond data bounds")
        }
        
        var value: T = 0
        withUnsafeMutableBytes(of: &value) { pointer in
            for i in 0..<size {
                pointer[i] = self[offset + i]
            }
        }
        
        return T(littleEndian: value)
    }
}

// MARK: - Integer Extensions for Data Conversion
extension FixedWidthInteger {
    var littleEndianData: Data {
        var value = self.littleEndian
        return Data(bytes: &value, count: MemoryLayout<Self>.size)
    }
}

// MARK: - Data Extensions for Bytes
extension Data {
    init(bytes: [UInt8]) {
        self.init(bytes)
    }
}
