import SwiftUI

struct CustomSessionTypeView: View {
    var body: some View {
        VStack {
            Text("Custom Session Type")
                .font(.largeTitle)
            Button("Single Point Timing") {
                // Navigate to Single Point Session setup
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            
            Button("End-to-End Timing") {
                // Navigate to End-to-End Session setup
            }
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
    }
}
