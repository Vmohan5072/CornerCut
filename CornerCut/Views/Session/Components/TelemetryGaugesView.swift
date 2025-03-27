//
//  TelemetryGaugesView.swift
//  CornerCut
//

import SwiftUI

struct TelemetryGaugesView: View {
    let speed: Double
    let maxSpeed: Double
    let displaySpeed: Int
    let speedUnit: String
    let rpm: Double
    let maxRpm: Double
    let lateralG: Double
    let longitudinalG: Double
    let hasOBDConnection: Bool
    
    var body: some View {
        HStack(spacing: 30) {
            // Speed
            CircularGaugeView(
                value: speed,
                maxValue: maxSpeed,
                displayValue: displaySpeed,
                title: speedUnit,
                gaugeColor: .blue
            )
            
            // RPM (if OBD connected)
            if hasOBDConnection {
                CircularGaugeView(
                    value: rpm,
                    maxValue: maxRpm,
                    displayValue: Int(rpm),
                    title: "RPM",
                    gaugeColor: .orange
                )
            }
            
            // G-Force
            GForceView(
                lateralG: lateralG,
                longitudinalG: longitudinalG,
                maxG: 2.0
            )
        }
        .padding(.horizontal)
    }
}

struct CircularGaugeView: View {
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

struct TelemetryGaugesView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            TelemetryGaugesView(
                speed: 120,
                maxSpeed: 180,
                displaySpeed: 120,
                speedUnit: "MPH",
                rpm: 5000,
                maxRpm: 8000,
                lateralG: 0.5,
                longitudinalG: -0.3,
                hasOBDConnection: true
            )
        }
    }
}
