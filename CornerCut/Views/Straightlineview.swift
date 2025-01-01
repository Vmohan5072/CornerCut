import SwiftUI

struct StraightlineView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Straightline Performance")
                    .font(.largeTitle)
                    .bold()
                
                List {
                    Text("0-60 mph")
                    Text("60-130 mph")
                    Text("100-200 km/h")
                    Text("1/4 mile")
                    Text("1/2 mile")
                    Text("Other Measurements")
                }
            }
            .padding()
            .navigationTitle("Performance")
        }
    }
}
