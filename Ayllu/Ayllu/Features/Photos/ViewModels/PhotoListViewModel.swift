import Foundation
import SwiftUI

/// ViewModel for the photo list
@Observable
final class PhotoListViewModel {
    // MARK: - State

    var photos: [Photo] = []
    var searchText: String = ""
    var isLoading: Bool = false
    var error: Error?
    var showingCaptureSheet: Bool = false
    var showingDeleteConfirmation: Bool = false
    var showingError: Bool = false
    var photoToDelete: Photo?

    // MARK: - Dependencies

    private let repository: PhotoRepository
    let projectId: Int64?

    // MARK: - Computed Properties

    var filteredPhotos: [Photo] {
        var result = photos

        if !searchText.isEmpty {
            result = result.filter { photo in
                (photo.caption?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        return result
    }

    var isEmpty: Bool {
        photos.isEmpty
    }

    var hasSearchResults: Bool {
        !filteredPhotos.isEmpty
    }

    // MARK: - Initialization

    init(repository: PhotoRepository, projectId: Int64? = nil) {
        self.repository = repository
        self.projectId = projectId
    }

    // MARK: - Actions

    func loadPhotos() {
        isLoading = true
        error = nil

        do {
            photos = try repository.fetchAll(projectId: projectId)
        } catch {
            self.error = error
            showingError = true
        }

        isLoading = false
    }

    func deletePhoto(_ photo: Photo) {
        guard let id = photo.id else { return }

        do {
            // Delete photo AND cleanup files
            try repository.deleteWithCleanup(photo)

            withAnimation {
                photos.removeAll { $0.id == id }
            }
        } catch {
            self.error = error
            showingError = true
        }
    }

    func confirmDelete(_ photo: Photo) {
        photoToDelete = photo
        showingDeleteConfirmation = true
    }

    func photoAdded(_ photo: Photo) {
        photos.insert(photo, at: 0)
    }
}
