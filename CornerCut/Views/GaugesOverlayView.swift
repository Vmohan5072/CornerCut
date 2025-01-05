import SwiftUI

struct GaugeView: View {
    var value: Double
    var maxValue: Double
    var label: String

    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .stroke(lineWidth: 10)
                    .opacity(0.3)
                Circle()
                    .trim(from: 0.0, to: CGFloat(value / maxValue))
                    .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(Angle(degrees: -90))
                Text("\(Int(value))")
                    .font(.headline)
            }
            Text(label)
                .font(.caption)
        }
        .frame(width: 100, height: 100)
    }
}

struct GaugesOverlayView: View {
    @Binding var speed: Double
    @Binding var rpm: Double
    @Binding var throttle: Double
    @Binding var temperature: Double

    var body: some View {
        HStack {
            GaugeView(value: speed, maxValue: 200, label: "Speed")
            GaugeView(value: rpm, maxValue: 8000, label: "RPM")
            GaugeView(value: throttle, maxValue: 100, label: "Throttle")
            GaugeView(value: temperature, maxValue: 300, label: "Temp")
        }
    }
}
