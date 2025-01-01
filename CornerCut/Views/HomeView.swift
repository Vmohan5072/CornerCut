import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                
                // Start Circuit Session
                NavigationLink(destination: TrackListView()) {
                    Text("Start Circuit Session")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                // Start Custom Session
                NavigationLink(destination: CustomSessionTypeView()) {
                    Text("Start Custom Session")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Spacer()
                
                // Device connection status
                HStack {
                    VStack {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.largeTitle)
                        Text("RaceBox Connected")
                    }
                    
                    VStack {
                        Image(systemName: "car.fill")
                            .font(.largeTitle)
                        Text("OBD Reader Connected")
                    }
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Home")
        }
    }
}
