//
//  LapAnalysisView.swift
//  CornerCut
//

import SwiftUI

struct LapAnalysisView: View {
    @ObservedObject var viewModel: AnalysisViewModel
    @State private var selectedMetric: AnalysisMetric = .speed
    
    enum AnalysisMetric: String, CaseIterable {
        case speed = "Speed"
        case rpm = "RPM"
        case throttleBrake = "Throttle & Brake"
        case gForce = "G-Force"
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.isLoading {
                    ProgressView("Loading lap data...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                } else if let lap = viewModel.selectedLap {
                    // Lap selector
                    LapSelectorView(viewModel: viewModel)
                        .padding(.horizontal)
                    
                    // Metrics overview
                    LapMetricsView(viewModel: viewModel)
                        .padding(.horizontal)
                    
                    // Main chart section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Lap Analysis")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Picker("Analysis Type", selection: $selectedMetric) {
                            ForEach(AnalysisMetric.allCases, id: \.self) { metric in
                                Text(metric.rawValue).tag(metric)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                        
                        // Dynamic chart based on selection
                        switch selectedMetric {
                        case .speed:
                            SpeedChartView(points: viewModel.speedPoints, maxValue: viewModel.maxSpeed)
                        case .rpm:
                            RPMChartView(points: viewModel.rpmPoints, maxValue: viewModel.maxRPM)
                        case .throttleBrake:
                            ThrottleBrakeChartView(throttlePoints: viewModel.throttlePoints,
                                                 brakePoints: viewModel.brakePoints)
                        case .gForce:
                            GForceChartView(lateralPoints: viewModel.lateralGPoints,
                                         longitudinalPoints: viewModel.longitudinalGPoints,
                                         maxLatG: viewModel.maxLateralG,
                                         maxLongG: viewModel.maxLongitudinalG)
                        }
                    }
                    .frame(height: 300)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                    .padding()
                    
                    // Additional metrics and insights
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Performance Insights")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        // Display some insights based on the data
                        InsightsView(viewModel: viewModel)
                            .padding(.horizontal)
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationTitle("Lap Analysis")
    }
}

// MARK: - Supporting Views

struct LapSelectorView: View {
    @ObservedObject var viewModel: AnalysisViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select Lap")
                .font(.headline)
            
            if let session = viewModel.selectedSession {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(session.laps) { lap in
                            Button(action: {
                                viewModel.loadLap(lap)
                            }) {
                                VStack {
                                    Text("Lap \(lap.lapNumber)")
                                        .font(.subheadline)
                                    
                                    Text(lap.formattedLapTime)
                                        .font(.system(.body, design: .monospaced))
                                        .fontWeight(.semibold)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(viewModel.selectedLap?.id == lap.id ?
                                            Color.blue.opacity(0.2) : Color(.systemGray6))
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
        }
    }
}

struct LapMetricsView: View {
    @ObservedObject var viewModel: AnalysisViewModel
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Lap Overview")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                MetricItemView(title: "Max Speed",
                             value: String(format: "%.1f", viewModel.maxSpeed),
                             unit: SettingsManager.shared.unitSystem == .imperial ? "mph" : "km/h",
                             color: .blue)
                
                MetricItemView(title: "Avg Speed",
                             value: String(format: "%.1f", viewModel.avgSpeed),
                             unit: SettingsManager.shared.unitSystem == .imperial ? "mph" : "km/h",
                             color: .green)
                
                MetricItemView(title: "Max RPM",
                             value: String(format: "%.0f", viewModel.maxRPM),
                             unit: "rpm",
                             color: .orange)
                
                MetricItemView(title: "Throttle",
                             value: String(format: "%.0f%%", viewModel.avgThrottle),
                             unit: "avg",
                             color: .green)
                
                MetricItemView(title: "Max Brake",
                             value: String(format: "%.0f%%", viewModel.maxBrake),
                             unit: "pressure",
                             color: .red)
                
                MetricItemView(title: "Max G",
                             value: String(format: "%.1f", max(viewModel.maxLateralG, viewModel.maxLongitudinalG)),
                             unit: "g",
                             color: .purple)
            }
        }
        .padding()
        .background(colorScheme == .dark ? Color(.systemGray6) : Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct MetricItemView: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(color)
                
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Chart Views

struct SpeedChartView: View {
    let points: [ChartPoint]
    let maxValue: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background grid
                VStack(spacing: 0) {
                    ForEach(0..<5) { i in
                        Divider()
                        Spacer()
                            .frame(height: geometry.size.height / 5)
                    }
                    Divider()
                }
                
                // Speed line
                Path { path in
                    guard !points.isEmpty else { return }
                    
                    let width = geometry.size.width
                    let height = geometry.size.height
                    
                    // Scale factors
                    let xScale = width / (points.last?.x ?? 1)
                    let yScale = height / (maxValue * 1.1)
                    
                    // Start point
                    path.move(to: CGPoint(
                        x: 0,
                        y: height - CGFloat(points[0].y * yScale)
                    ))
                    
                    // Draw line through points
                    for point in points {
                        path.addLine(to: CGPoint(
                            x: CGFloat(point.x * xScale),
                            y: height - CGFloat(point.y * yScale)
                        ))
                    }
                }
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                
                // Speed labels
                VStack {
                    ForEach(0..<5) { i in
                        let value = maxValue * Double(5 - i) / 5
                        HStack {
                            Text("\(Int(value))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 4)
                        Spacer()
                    }
                    HStack {
                        Text("0")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                }
                
                // Time labels
                VStack {
                    Spacer()
                    HStack {
                        ForEach(0..<5) { i in
                            let maxTime = points.last?.x ?? 60
                            Text("\(Int(maxTime * Double(i) / 4))s")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        Text("\(Int(points.last?.x ?? 60))s")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 4)
                }
            }
            .padding(4)
        }
    }
}

struct RPMChartView: View {
    let points: [ChartPoint]
    let maxValue: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background grid
                VStack(spacing: 0) {
                    ForEach(0..<5) { i in
                        Divider()
                        Spacer()
                            .frame(height: geometry.size.height / 5)
                    }
                    Divider()
                }
                
                // RPM line
                Path { path in
                    guard !points.isEmpty else { return }
                    
                    let width = geometry.size.width
                    let height = geometry.size.height
                    
                    // Scale factors
                    let xScale = width / (points.last?.x ?? 1)
                    let yScale = height / (maxValue * 1.1)
                    
                    // Start point
                    path.move(to: CGPoint(
                        x: 0,
                        y: height - CGFloat(points[0].y * yScale)
                    ))
                    
                    // Draw line through points
                    for point in points {
                        path.addLine(to: CGPoint(
                            x: CGFloat(point.x * xScale),
                            y: height - CGFloat(point.y * yScale)
                        ))
                    }
                }
                .stroke(Color.orange, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                
                // RPM labels
                VStack {
                    ForEach(0..<5) { i in
                        let value = maxValue * Double(5 - i) / 5
                        HStack {
                            Text("\(Int(value))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 4)
                        Spacer()
                    }
                    HStack {
                        Text("0")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                }
                
                // Time labels
                VStack {
                    Spacer()
                    HStack {
                        ForEach(0..<5) { i in
                            let maxTime = points.last?.x ?? 60
                            Text("\(Int(maxTime * Double(i) / 4))s")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        Text("\(Int(points.last?.x ?? 60))s")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 4)
                }
            }
            .padding(4)
        }
    }
}

struct ThrottleBrakeChartView: View {
    let throttlePoints: [ChartPoint]
    let brakePoints: [ChartPoint]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background grid
                VStack(spacing: 0) {
                    ForEach(0..<5) { i in
                        Divider()
                        Spacer()
                            .frame(height: geometry.size.height / 5)
                    }
                    Divider()
                }
                
                // Throttle and brake data
                ZStack {
                    // Throttle area
                    Path { path in
                        guard !throttlePoints.isEmpty else { return }
                        
                        let width = geometry.size.width
                        let height = geometry.size.height
                        
                        // Scale factors
                        let xScale = width / (throttlePoints.last?.x ?? 1)
                        let yScale = height / 100
                        
                        // Start point at bottom left
                        path.move(to: CGPoint(x: 0, y: height))
                        
                        // Add first point
                        path.addLine(to: CGPoint(
                            x: 0,
                            y: height - CGFloat(throttlePoints[0].y * yScale)
                        ))
                        
                        // Draw line through points
                        for point in throttlePoints {
                            path.addLine(to: CGPoint(
                                x: CGFloat(point.x * xScale),
                                y: height - CGFloat(point.y * yScale)
                            ))
                        }
                        
                        // Close the path back to bottom
                        path.addLine(to: CGPoint(x: width, y: height))
                        path.closeSubpath()
                    }
                    .fill(Color.green.opacity(0.3))
                    
                    // Throttle line
                    Path { path in
                        guard !throttlePoints.isEmpty else { return }
                        
                        let width = geometry.size.width
                        let height = geometry.size.height
                        
                        // Scale factors
                        let xScale = width / (throttlePoints.last?.x ?? 1)
                        let yScale = height / 100
                        
                        // Start point
                        path.move(to: CGPoint(
                            x: 0,
                            y: height - CGFloat(throttlePoints[0].y * yScale)
                        ))
                        
                        // Draw line through points
                        for point in throttlePoints {
                            path.addLine(to: CGPoint(
                                x: CGFloat(point.x * xScale),
                                y: height - CGFloat(point.y * yScale)
                            ))
                        }
                    }
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    
                    // Brake area
                    Path { path in
                        guard !brakePoints.isEmpty else { return }
                        
                        let width = geometry.size.width
                        let height = geometry.size.height
                        
                        // Scale factors
                        let xScale = width / (brakePoints.last?.x ?? 1)
                        let yScale = height / 100
                        
                        // Start point at bottom left
                        path.move(to: CGPoint(x: 0, y: height))
                        
                        // Add first point
                        path.addLine(to: CGPoint(
                            x: 0,
                            y: height - CGFloat(brakePoints[0].y * yScale)
                        ))
                        
                        // Draw line through points
                        for point in brakePoints {
                            path.addLine(to: CGPoint(
                                x: CGFloat(point.x * xScale),
                                y: height - CGFloat(point.y * yScale)
                            ))
                        }
                        
                        // Close the path back to bottom
                        path.addLine(to: CGPoint(x: width, y: height))
                        path.closeSubpath()
                    }
                    .fill(Color.red.opacity(0.2))
                    
                    // Brake line
                    Path { path in
                        guard !brakePoints.isEmpty else { return }
                        
                        let width = geometry.size.width
                        let height = geometry.size.height
                        
                        // Scale factors
                        let xScale = width / (brakePoints.last?.x ?? 1)
                        let yScale = height / 100
                        
                        // Start point
                        path.move(to: CGPoint(
                            x: 0,
                            y: height - CGFloat(brakePoints[0].y * yScale)
                        ))
                        
                        // Draw line through points
                        for point in brakePoints {
                            path.addLine(to: CGPoint(
                                x: CGFloat(point.x * xScale),
                                y: height - CGFloat(point.y * yScale)
                            ))
                        }
                    }
                    .stroke(Color.red, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
                
                // Labels
                VStack {
                    HStack {
                        Text("100%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                    Spacer()
                    
                    HStack {
                        Text("50%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                    .offset(y: geometry.size.height / 4)
                    
                    Spacer()
                    
                    HStack {
                        Text("0%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                }
                
                // Legend
                VStack {
                    HStack {
                        Spacer()
                        HStack {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("Throttle")
                                .font(.caption2)
                            
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                            Text("Brake")
                                .font(.caption2)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                    Spacer()
                }
            }
            .padding(4)
        }
    }
}

struct GForceChartView: View {
    let lateralPoints: [ChartPoint]
    let longitudinalPoints: [ChartPoint]
    let maxLatG: Double
    let maxLongG: Double
    
    var body: some View {
        VStack {
            // G-Force scatter plot
            GeometryReader { geometry in
                ZStack {
                    // Reference circles
                    ForEach(1...3, id: \.self) { i in
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            .frame(width: geometry.size.width * CGFloat(i) / 3,
                                   height: geometry.size.width * CGFloat(i) / 3)
                    }
                    
                    // Reference lines
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: geometry.size.height / 2))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height / 2))
                        path.move(to: CGPoint(x: geometry.size.width / 2, y: 0))
                        path.addLine(to: CGPoint(x: geometry.size.width / 2, y: geometry.size.height))
                    }
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    
                    // Data points
                    ForEach(0..<min(lateralPoints.count, longitudinalPoints.count), id: \.self) { index in
                        let latG = lateralPoints[index].y
                        let longG = longitudinalPoints[index].y
                        
                        // Scale factors
                        let maxG = max(3.0, max(maxLatG, maxLongG)) // At least 3G scale
                        let scale = min(geometry.size.width, geometry.size.height) / 2 / CGFloat(maxG)
                        
                        // Convert G to coordinate
                        let x = geometry.size.width / 2 + CGFloat(latG) * scale
                        let y = geometry.size.height / 2 - CGFloat(longG) * scale
                        
                        Circle()
                            .fill(Color.purple.opacity(0.7))
                            .frame(width: 4, height: 4)
                            .position(x: x, y: y)
                    }
                    
                    // Labels
                    VStack {
                        Text("BRAKING")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("ACCELERATION")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("LEFT")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .rotationEffect(.degrees(-90))
                        Spacer()
                        Text("RIGHT")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .rotationEffect(.degrees(90))
                    }
                    
                    // G-force values
                    VStack {
                        Spacer()
                        HStack {
                            Text("Max Lat-G: \(String(format: "%.2f", maxLatG))g")
                                .font(.caption)
                            Spacer()
                            Text("Max Long-G: \(String(format: "%.2f", maxLongG))g")
                                .font(.caption)
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
    }
}

struct InsightsView: View {
    @ObservedObject var viewModel: AnalysisViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Time distribution
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.green)
                    .frame(width: getThrottleWidth(), height: 20)
                
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: getCoastWidth(), height: 20)
                
                Rectangle()
                    .fill(Color.red)
                    .frame(width: getBrakeWidth(), height: 20)
            }
            .cornerRadius(4)
            
            // Explanation
            HStack(spacing: 16) {
                HStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("Throttle")
                        .font(.caption)
                }
                
                HStack {
                    Circle()
                        .fill(Color.gray.opacity(0.6))
                        .frame(width: 8, height: 8)
                    Text("Coast")
                        .font(.caption)
                }
                
                HStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text("Brake")
                        .font(.caption)
                }
            }
            
            // Textual insights
            Text("Lap Insights")
                .font(.subheadline)
                .fontWeight(.semibold)
                .padding(.top, 8)
            
            Text("During this lap, you spent \(Int(getThrottlePercentage()))% on throttle, \(Int(getBrakePercentage()))% on brakes, and \(Int(getCoastPercentage()))% coasting.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            // Additional insights here...
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
    
    private func getThrottleWidth() -> CGFloat {
        return CGFloat(getThrottlePercentage() / 100) * 300
    }
    
    private func getBrakeWidth() -> CGFloat {
        return CGFloat(getBrakePercentage() / 100) * 300
    }
    
    private func getCoastWidth() -> CGFloat {
        return CGFloat(getCoastPercentage() / 100) * 300
    }
    
    private func getThrottlePercentage() -> Double {
        let totalTime = viewModel.throttleTime + viewModel.brakeTime + viewModel.coastTime
        guard totalTime > 0 else { return 0 }
        return (viewModel.throttleTime / totalTime) * 100
    }
    
    private func getBrakePercentage() -> Double {
        let totalTime = viewModel.throttleTime + viewModel.brakeTime + viewModel.coastTime
        guard totalTime > 0 else { return 0 }
        return (viewModel.brakeTime / totalTime) * 100
    }
    
    private func getCoastPercentage() -> Double {
        let totalTime = viewModel.throttleTime + viewModel.brakeTime + viewModel.coastTime
        guard totalTime > 0 else { return 0 }
        return (viewModel.coastTime / totalTime) * 100
    }
}

struct LapAnalysisView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            LapAnalysisView(viewModel: AnalysisViewModel())
        }
    }
}
