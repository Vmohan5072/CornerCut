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
            GForceIndicatorView(
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
