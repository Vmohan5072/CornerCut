//
//  ActiveSessionView.swift
//  RaceBoxLapTimer
//

import SwiftUI
import CoreLocation

struct ActiveSessionView: View {
    @ObservedObject var viewModel: SessionViewModel
    @Environment(\.presentationMode) var presentationMode
    @GestureState private var doubleTapActive = false
    
    // Double tap gesture to end session
    var doubleTapGesture: some Gesture {
        TapGesture(count: 2)
            .updating($doubleTapActive) { _, state, _ in
                state = true
            }
            .onEnded { _ in
                viewModel.endSession()
                presentationMode.wrappedValue.dismiss()
            }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black.edgesIgnoringSafeArea(.all)
                
                // Main content
                VStack(spacing: 0) {
                    // Top status bar
                    HStack {
                        // Lap counter
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray6).opacity(0.3))
                                .frame(width: 100, height: 40)
                            
                            Text("LAP: \(viewModel.currentLap)")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        // Track name
                        Text(viewModel.trackName)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        // GPS signal indicator
                        HStack(spacing: 8) {
                            // GPS
                            Circle()
                                .fill(viewModel.hasGPSSignal ? Color.green : Color.red)
                                .frame(width: 12, height: 12)
                            
                            // OBD (if enabled)
                            if viewModel.isOBDEnabled {
                                Circle()
                                    .fill(viewModel.hasOBDConnection ? Color.green : Color.red)
                                    .frame(width: 12, height: 12)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    .padding(.bottom, 5)
                    
                    // Best lap time
                    HStack {
                        Spacer()
                        
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray6).opacity(0.3))
                                .frame(width: 220, height: 40)
                            
                            HStack {
                                Text("BEST:")
                                    .font(.system(size: 18, weight: .medium, design: .rounded))
                                    .foregroundColor(.white)
                                
                                Text(viewModel.formattedBestLapTime)
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(.green)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.bottom, 20)
                    
                    // Current lap time - large display
                    Text(viewModel.formattedCurrentLapTime)
                        .font(.system(size: 70, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    
                    // Delta to best lap
                    Text(viewModel.formattedDeltaTime)
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(viewModel.isDeltaPositive ? .red : .green)
                        .padding(.bottom, 30)
                    
                    // Sector times
                    if viewModel.hasSectors {
                        HStack(spacing: 0) {
                            // Sector 1
                            SectorTimeView(
                                sectorNumber: 1,
                                time: viewModel.formattedSector1Time,
                                isCompleted: viewModel.sector1Completed,
                                isFastest: viewModel.isSector1Fastest,
                                sectorColor: viewModel.sector1Color
                            )
                            
                            // Sector 2
                            SectorTimeView(
                                sectorNumber: 2,
                                time: viewModel.formattedSector2Time,
                                isCompleted: viewModel.sector2Completed,
                                isFastest: viewModel.isSector2Fastest,
                                sectorColor: viewModel.sector2Color
                            )
                            
                            // Sector 3
                            SectorTimeView(
                                sectorNumber: 3,
                                time: viewModel.formattedSector3Time,
                                isCompleted: viewModel.sector3Completed,
                                isFastest: viewModel.isSector3Fastest,
                                sectorColor: viewModel.sector3Color
                            )
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                    
                    // Bottom telemetry display
                    HStack(spacing: 30) {
                        // Speed
                        TelemetryGaugeView(
                            value: viewModel.speed,
                            maxValue: viewModel.maxSpeed,
                            displayValue: Int(viewModel.displaySpeed),
                            title: viewModel.speedUnit,
                            gaugeColor: .blue
                        )
                        
                        // RPM (if OBD connected)
                        if viewModel.hasOBDConnection {
                            TelemetryGaugeView(
                                value: viewModel.rpm,
                                maxValue: viewModel.maxRPM,
                                displayValue: Int(viewModel.rpm),
                                title: "RPM",
                                gaugeColor: .orange
                            )
                        }
                        
                        // G-Force
                        GForceView(
                            lateralG: viewModel.lateralG,
                            longitudinalG: viewModel.longitudinalG,
                            maxG: 2.0
                        )
                    }
                    .padding(.horizontal)
                    
                    // OBD data row (if connected)
                    if viewModel.hasOBDConnection {
                        HStack(spacing: 20) {
                            // Throttle
                            LinearGaugeView(
                                value: viewModel.throttlePosition,
                                maxValue: 100,
                                title: "Throttle",
                                unit: "%",
                                gaugeColor: .green
                            )
                            
                            // Brake
                            LinearGaugeView(
                                value: viewModel.brakePosition,
                                maxValue: 100,
                                title: "Brake",
                                unit: "%",
                                gaugeColor: .red
                            )
                            
                            // Gear
                            ZStack {
                                Circle()
                                    .stroke(Color.white.opacity(0.5), lineWidth: 2)
                                    .frame(width: 50, height: 50)
                                
                                Text(viewModel.currentGear)
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding()
                    }
                    
                    Spacer()
                    
                    // Bottom hint
                    Text("Double tap to end session")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .padding(.bottom, 8)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .gesture(doubleTapGesture)
            .statusBar(hidden: true)
            .onAppear {
                // Lock to landscape orientation
                UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
                UINavigationController.attemptRotationToDeviceOrientation()
            }
            .onDisappear {
                // Allow all orientations again
                UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
                UINavigationController.attemptRotationToDeviceOrientation()
            }
        }
        .navigationBarHidden(true)
    }
}

struct SectorTimeView: View {
    let sectorNumber: Int
    let time: String
    let isCompleted: Bool
    let isFastest: Bool
    let sectorColor: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text("S\(sectorNumber)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
            
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(sectorColor.opacity(0.3))
                    .frame(height: 30)
                
                Text(time)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(isCompleted ? (isFastest ? .green : .white) : .gray)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct TelemetryGaugeView: View {
    let value: Double
    let maxValue: Double
    let displayValue: Int
    let title: String
    let gaugeColor: Color
    
    private var percentage: Double {
        return min(value / maxValue, 1.0)
    }
    
    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                // Gauge background
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 5)
                    .frame(width: 100, height: 100)
                
                // Gauge fill
                Circle()
                    .trim(from: 0, to: CGFloat(percentage))
                    .stroke(gaugeColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 100, height: 100)
                
                // Value display
                VStack {
                    Text("\(displayValue)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(title)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
    }
}

struct LinearGaugeView: View {
    let value: Double
    let maxValue: Double
    let title: String
    let unit: String
    let gaugeColor: Color
    
    private var percentage: Double {
        return min(value / maxValue, 1.0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                Text("\(Int(value))\(unit)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            
            ZStack(alignment: .leading) {
                // Background
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 10)
                    .cornerRadius(5)
                
                // Fill
                Rectangle()
                    .fill(gaugeColor)
                    .frame(width: max(5, CGFloat(percentage) * 150), height: 10)
                    .cornerRadius(5)
            }
            .frame(width: 150)
        }
    }
}

struct GForceView: View {
    let lateralG: Double
    let longitudinalG: Double
    let maxG: Double
    
    private var normalizedLateralG: Double {
        return lateralG / maxG
    }
    
    private var normalizedLongitudinalG: Double {
        return longitudinalG / maxG
    }
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                .frame(width: 100, height: 100)
            
            // Cross lines
            Path { path in
                path.move(to: CGPoint(x: 50, y: 0))
                path.addLine(to: CGPoint(x: 50, y: 100))
                path.move(to: CGPoint(x: 0, y: 50))
                path.addLine(to: CGPoint(x: 100, y: 50))
            }
            .stroke(Color.white.opacity(0.2), lineWidth: 1)
            
            // G-force marker
            Circle()
                .fill(Color.red)
                .frame(width: 12, height: 12)
                .offset(
                    x: CGFloat(normalizedLateralG * 40),
                    y: CGFloat(-normalizedLongitudinalG * 40)
                )
            
            // Label
            Text("G-FORCE")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.8))
                .offset(y: 55)
        }
        .frame(width: 100, height: 100)
    }
}


