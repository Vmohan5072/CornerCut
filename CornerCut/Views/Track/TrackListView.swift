//
//  TrackListView.swift
//  RaceBoxLapTimer
//

import SwiftUI

struct TrackListView: View {
    @StateObject private var viewModel = TrackViewModel()
    @State private var showingCreateTrack = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Track type toggle
            Picker("Track Type", selection: $viewModel.selectedTrackType) {
                ForEach(TrackType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            .onChange(of: viewModel.selectedTrackType) { _ in
                viewModel.filterTracks()
            }
            
            // Search field
            SearchBar(text: $viewModel.searchText)
                .padding(.horizontal)
                .onChange(of: viewModel.searchText) { _ in
                    viewModel.filterTracks()
                }
            
            // Track list
            List {
                ForEach(viewModel.filteredTracks) { track in
                    NavigationLink(destination: TrackDetailView(track: track)) {
                        TrackRow(track: track)
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let track = viewModel.filteredTracks[index]
                        viewModel.deleteTrack(track)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
        }
        .navigationTitle("Tracks")
        .navigationBarItems(
            trailing: Button(action: {
                showingCreateTrack = true
            }) {
                Image(systemName: "plus")
            }
        )
        .sheet(isPresented: $showingCreateTrack) {
            NavigationView {
                CreateTrackView(viewModel: viewModel)
                    .navigationTitle("Create Track")
                    .navigationBarItems(
                        leading: Button("Cancel") {
                            viewModel.resetTrackCreation()
                            showingCreateTrack = false
                        },
                        trailing: Button("Save") {
                            viewModel.saveTrack()
                            showingCreateTrack = false
                        }
                    )
            }
        }
        .onAppear {
            viewModel.loadTracks()
        }
        .alert(isPresented: $viewModel.showAlert) {
            Alert(
                title: Text(viewModel.alertTitle),
                message: Text(viewModel.alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

struct TrackRow: View {
    let track: Track
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(track.name)
                .font(.headline)
            
            HStack {
                Text(track.location)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let lastUsed = track.lastUsedDate {
                    Text("Last used: \(formatDate(lastUsed))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let bestLapTime = track.bestLapTime {
                Text("Best: \(formatTime(bestLapTime))")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)
        
        return String(format: "%02d:%02d.%03d", minutes, seconds, milliseconds)
    }
}

struct SearchBarView: View {
    @Binding var text: String
    var placeholder: String = "Search"
    
    var body: some View {
        HStack {
            TextField(placeholder, text: $text)
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

struct SearchBarView_Previews: PreviewProvider {
    static var previews: some View {
        SearchBarView(text: .constant(""))
            .previewLayout(.sizeThatFits)
            .padding()
        }
    }

