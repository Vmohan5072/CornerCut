//
//  LapTimerView.swift
//  CornerCut
//

import SwiftUI

struct LapTimerView: View {
    let currentTime: String
    let lastLapTime: String
    let bestLapTime: String
    let deltaTime: String
    let isDeltaPositive: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            // Current lap time - large display
            Text(currentTime)
                .font(.system(size: 70, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .monospacedDigit()
            
            // Delta to best lap
            Text(deltaTime)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(isDeltaPositive ? .red : .green)
                .padding(.bottom, 10)
            
            // Previous times
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("LAST LAP")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(lastLapTime)
                        .font(.system(size: 20, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 4) {
                    Text("BEST LAP")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Text(bestLapTime)
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                }
            }
        }
    }
}

struct LapTimerView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            LapTimerView(
                currentTime: "01:23.456",
                lastLapTime: "01:24.789",
                bestLapTime: "01:22.345",
                deltaTime: "+01.111",
                isDeltaPositive: true
            )
        }
    }
}
