import Foundation
import SwiftUI

/// ViewModel for the project list
@Observable
final class ProjectListViewModel {
    // MARK: - State

    var projects: [Project] = []
    var searchText: String = ""
    var isLoading: Bool = false
    var error: Error?
    var showingCreateSheet: Bool = false
    var showingDeleteConfirmation: Bool = false
    var projectToDelete: Project?

    // MARK: - Dependencies

    private let repository: ProjectRepository

    // MARK: - Computed Properties

    var filteredProjects: [Project] {
        if searchText.isEmpty {
            return projects
        }
        return projects.filter { project in
            project.name.localizedCaseInsensitiveContains(searchText) ||
            (project.description?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var isEmpty: Bool {
        projects.isEmpty
    }

    var hasSearchResults: Bool {
        !filteredProjects.isEmpty
    }

    // MARK: - Initialization

    init(repository: ProjectRepository) {
        self.repository = repository
    }

    // MARK: - Actions

    func loadProjects() {
        isLoading = true
        error = nil

        do {
            projects = try repository.fetchAll()
        } catch {
            self.error = error
        }

        isLoading = false
    }

    func createProject(name: String, description: String?, startDate: Date?, endDate: Date?) {
        let project = Project(
            name: name,
            description: description,
            startDate: startDate,
            endDate: endDate
        )

        do {
            let newProject = try repository.create(project)
            projects.insert(newProject, at: 0)
        } catch {
            self.error = error
        }
    }

    func deleteProject(_ project: Project) {
        guard let id = project.id else { return }

        do {
            try repository.delete(id: id)
            withAnimation {
                projects.removeAll { $0.id == id }
            }
        } catch {
            self.error = error
        }
    }

    func confirmDelete(_ project: Project) {
        projectToDelete = project
        showingDeleteConfirmation = true
    }

    func statistics(for project: Project) -> ProjectStatistics? {
        guard let id = project.id else { return nil }
        return try? repository.statistics(for: id)
    }
}
