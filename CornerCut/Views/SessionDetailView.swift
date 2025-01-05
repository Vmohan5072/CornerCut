import SwiftUI
import PhotosUI
import SwiftData

struct SessionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: Session 

    @State private var showVideoPicker = false
    @State private var selectedPickerItem: PhotosPickerItem? // Use PhotosPickerItem

    var body: some View {
        VStack {
            if let videoURL = session.videoURL {
                Text("Video Linked: \(videoURL.lastPathComponent)")
                    .font(.footnote)
                    .padding()

                Button("Unlink Video") {
                    unlinkVideo()
                }
                .foregroundColor(.red)
                .padding()
            } else {
                Button("Import Video") {
                    showVideoPicker = true
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }

            Spacer() // Placeholder for additional session details
            Text("Session Details Here")
        }
        .navigationTitle(session.trackName.isEmpty ? "Custom Session" : session.trackName)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveContext()
                }
            }
        }
        .photosPicker(isPresented: $showVideoPicker, selection: $selectedPickerItem, matching: .videos)
        .onChange(of: selectedPickerItem) { _, newItem in
            if let newItem = newItem {
                handleVideoImport(item: newItem)
            }
        }
    }

    private func unlinkVideo() {
        session.videoURL = nil
        saveContext()
    }

    private func saveContext() {
        try? modelContext.save()
    }

    private func handleVideoImport(item: PhotosPickerItem) {
        item.loadTransferable(type: URL.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let url):
                    if let url = url {
                        session.videoURL = url
                        saveContext()
                    } else {
                        print("Failed to retrieve video URL")
                    }
                case .failure(let error):
                    print("Error loading video: \(error.localizedDescription)")
                }
            }
        }
    }
}
