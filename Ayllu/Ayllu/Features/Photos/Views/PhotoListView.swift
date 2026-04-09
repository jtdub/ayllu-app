import SwiftUI

/// List view for photos with grid layout
struct PhotoListView: View {
    @Environment(DatabaseManager.self) private var database

    let projectId: Int64?

    @State private var viewModel: PhotoListViewModel?
    @State private var searchText = ""

    init(projectId: Int64? = nil) {
        self.projectId = projectId
    }

    var body: some View {
        Group {
            if let viewModel = viewModel {
                PhotoListContent(
                    viewModel: viewModel,
                    searchText: $searchText
                )
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Photos")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel?.showingCaptureSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search photos")
        .onChange(of: searchText) { _, newValue in
            viewModel?.searchText = newValue
        }
        .onAppear {
            if viewModel == nil {
                let repo = PhotoRepository(dbPool: database.dbPool)
                viewModel = PhotoListViewModel(repository: repo, projectId: projectId)
            }
            viewModel?.loadPhotos()
        }
        .navigationDestination(for: Photo.self) { photo in
            PhotoDetailView(photo: photo)
        }
        .sheet(
            isPresented: Binding(
                get: { viewModel?.showingCaptureSheet ?? false },
                set: { viewModel?.showingCaptureSheet = $0 }
            ),
            onDismiss: {
                viewModel?.loadPhotos()
            },
            content: {
                if let projectId = projectId {
                    NavigationStack {
                        PhotoCaptureView(projectId: projectId)
                    }
                }
            }
        )
        .alert("Delete Photo?", isPresented: Binding(
            get: { viewModel?.showingDeleteConfirmation ?? false },
            set: { viewModel?.showingDeleteConfirmation = $0 }
        )) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let photo = viewModel?.photoToDelete {
                    viewModel?.deletePhoto(photo)
                }
            }
        } message: {
            Text("This will permanently delete the photo and its files.")
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel?.showingError ?? false },
            set: { viewModel?.showingError = $0 }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            if let error = viewModel?.error {
                Text(error.localizedDescription)
            }
        }
    }
}

// MARK: - Content View

private struct PhotoListContent: View {
    @Bindable var viewModel: PhotoListViewModel
    @Binding var searchText: String

    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 2)
    ]

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
            } else if viewModel.isEmpty {
                ContentUnavailableView(
                    "No Photos",
                    systemImage: "photo.on.rectangle",
                    description: Text("Take a photo to get started")
                )
            } else if !viewModel.hasSearchResults {
                ContentUnavailableView.search(text: searchText)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(viewModel.filteredPhotos) { photo in
                            NavigationLink(value: photo) {
                                PhotoRowView(photo: photo)
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    viewModel.confirmDelete(photo)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(2)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        PhotoListView(projectId: 1)
    }
}
