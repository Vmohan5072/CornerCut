import SwiftUI
import SwiftData

struct SessionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Session.date, order: .reverse) private var sessions: [Session]

    var body: some View {
        NavigationView {
            List {
                ForEach(sessions) { session in
                    NavigationLink(destination: SessionDetailView(session: session)) {
                        SessionRowView(session: session)
                    }
                }
                .onDelete(perform: deleteSession)
            }
            .navigationTitle("Sessions")
        }
    }

    private func deleteSession(offsets: IndexSet) {
        offsets.map { sessions[$0] }.forEach { session in
            modelContext.delete(session)
        }
        try? modelContext.save()
    }

    private func addSampleSession() {
        let sampleLaps = [
            Lap(lapNumber: 1, lapTime: 60.5),
            Lap(lapNumber: 2, lapTime: 62.1)
        ]
        let newSession = Session(
            trackName: "Sample Track",
            usingExternalGPS: false,
            customName: "Test Session",
            date: Date()
        )
        modelContext.insert(newSession) // Insert into SwiftData context
        try? modelContext.save() // Save the context
    }
}

struct SessionRowView: View {
    let session: Session

    var body: some View {
        VStack(alignment: .leading) {
            Text(session.trackName.isEmpty ? "Custom Session" : session.trackName)
                .font(.headline)
            Text("Date: \(session.date, style: .date) Time: \(session.date, style: .time)")
            Text("Duration: \(session.laps.reduce(0) { $0 + $1.lapTime }, format: .number) minutes")
            Text("Custom Name: \(session.customName ?? "None")") // Safely unwraps the optional
        }
    }
}
