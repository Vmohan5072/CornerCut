import SwiftUI
import SwiftData

struct SessionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var session: Session
    
    var body: some View {
        VStack {
            Text("Track: \(session.trackName)")
                .font(.headline)
            
            // List laps
            List {
                ForEach(session.laps) { lap in
                    VStack(alignment: .leading) {
                        Text("Lap \(lap.lapNumber)")
                        Text("Time: \(lap.lapTime, format: .number.precision(.fractionLength(2)))s")
                            .font(.caption)
                    }
                }
            }
            
            Button("Save Changes") {
                try? modelContext.save()
            }
            .padding()
        }
        .navigationTitle("Session Detail")
    }
}
