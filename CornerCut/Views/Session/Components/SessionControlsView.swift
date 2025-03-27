//
//  SessionControlsView.swift
//  CornerCut
//

import SwiftUI

struct SessionControlsView: View {
    let trackName: String
    let sessionType: SessionType
    let currentLap: Int
    let hasGPSSignal: Bool
    let hasOBDConnection: Bool
    let isOBDEnabled: Bool
    let onEndSession: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Top status bar
            HStack {
                // Lap counter
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6).opacity(0.3))
                        .frame(width: 100, height: 40)
                    
                    Text("LAP: \(currentLap)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Track name
                Text(trackName)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Signal indicators
                HStack(spacing: 8) {
                    // GPS
                    Circle()
                        .fill(hasGPSSignal ? Color.green : Color.red)
                        .frame(width: 12, height: 12)
                    
                    // OBD (if enabled)
                    if isOBDEnabled {
                        Circle()
                            .fill(hasOBDConnection ? Color.green : Color.red)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)
            .padding(.bottom, 5)
            
            // Session type badge
            HStack {
                Spacer()
                
                Text(sessionType.rawValue.uppercased())
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(getSessionTypeColor(sessionType))
                    .cornerRadius(4)
                
                Spacer()
            }
            .padding(.bottom, 10)
            
            // Bottom hint for ending session
            Spacer()
            
            Text("Double tap to end session")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .padding(.bottom, 8)
        }
    }
    
    private func getSessionTypeColor(_ type: SessionType) -> Color {
        switch type {
        case .practice:
            return .blue
        case .qualifying:
            return .orange
        case .race:
            return .red
        case .testing:
            return .purple
        }
    }
}

struct SessionControlsView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            SessionControlsView(
                trackName: "Laguna Seca",
                sessionType: .practice,
                currentLap: 3,
                hasGPSSignal: true,
                hasOBDConnection: true,
                isOBDEnabled: true,
                onEndSession: {}
            )
        }
    }
}
