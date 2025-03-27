//
//  SessionHistoryView.swift
//  CornerCut
//

import SwiftUI

struct SessionHistoryView: View {
    @StateObject private var viewModel = SessionHistoryViewModel()
    @State private var searchText = ""
    @State private var selectedFilter: SessionFilter = .all
    
    enum SessionFilter: String, CaseIterable {
        case all = "All"
        case practice = "Practice"
        case qualifying = "Qualifying"
        case race = "Race"
        case testing = "Testing"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Filter tabs
            Picker("Session Type", selection: $selectedFilter) {
                ForEach(SessionFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            .onChange(of: selectedFilter) { _ in
                viewModel.filterSessions(by: selectedFilter, searchText: searchText)
            }
            
            // Search bar
            SearchBar(text: $searchText)
                .padding(.horizontal)
                .onChange(of: searchText) { _ in
                    viewModel.filterSessions(by: selectedFilter, searchText: searchText)
                }
            
            // Sessions list
            if viewModel.filteredSessions.isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                    
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    Text("No session history found")
                        .font(.headline)
                    
                    Text("Complete your first lap session to see it here")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Spacer()
                }
            } else {
                List {
                    ForEach(viewModel.filteredSessions) { session in
                        NavigationLink(destination: SessionReviewView(session: session)) {
                            SessionHistoryRow(session: session)
                        }
                    }
                    .onDelete { indexSet in
                        viewModel.deleteSessions(at: indexSet)
                    }
                }
                .listStyle(InsetGroupedListStyle())
            }
        }
        .navigationTitle("Session History")
        .onAppear {
            viewModel.loadSessions()
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            TextField("Search sessions", text: $text)
                .padding(7)
                .padding(.horizontal, 25)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .overlay(
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 8)
                        
                        if !text.isEmpty {
                            Button(action: {
                                text = ""
                            }) {
                                Image(systemName: "multiply.circle.fill")
                                    .foregroundColor(.gray)
                                    .padding(.trailing, 8)
                            }
                        }
                    }
                )
        }
    }
}

struct SessionHistoryRow: View {
    let session: LapSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(session.trackName)
                    .font(.headline)
                
                Spacer()
                
                Text(formatDate(session.startTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text(session.sessionType.rawValue)
                    .font(.subheadline)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(getSessionTypeColor(session.sessionType).opacity(0.2))
                    .cornerRadius(4)
                
                Spacer()
                
                if session.lapCount > 0 {
                    Text("\(session.lapCount) laps")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text("No laps")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
            
            if let bestLap = session.bestLap {
                HStack {
                    Text("Best Lap: \(bestLap.formattedLapTime)")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
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

// ViewModel for the session history view
class SessionHistoryViewModel: ObservableObject {
    @Published var allSessions: [LapSession] = []
    @Published var filteredSessions: [LapSession] = []
    
    private let sessionManager = SessionManager.shared
    
    func loadSessions() {
        allSessions = sessionManager.getAllSessions()
        filteredSessions = allSessions
    }
    
    func filterSessions(by filter: SessionHistoryView.SessionFilter, searchText: String) {
        var filtered = allSessions
        
        // Apply type filter
        if filter != .all {
            filtered = filtered.filter { $0.sessionType.rawValue == filter.rawValue }
        }
        
        // Apply search text
        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.trackName.lowercased().contains(searchText.lowercased()) ||
                $0.notes.lowercased().contains(searchText.lowercased())
            }
        }
        
        filteredSessions = filtered
    }
    
    func deleteSessions(at indexSet: IndexSet) {
        for index in indexSet {
            let sessionId = filteredSessions[index].id
            // Remove from both arrays
            allSessions.removeAll { $0.id == sessionId }
            filteredSessions.removeAll { $0.id == sessionId }
            
            // In a real app, you would also delete from persistence
            // sessionManager.deleteSession(sessionId)
        }
    }
}

struct SessionHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SessionHistoryView()
        }
    }
}
