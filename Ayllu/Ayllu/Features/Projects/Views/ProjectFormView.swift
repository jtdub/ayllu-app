import SwiftUI

/// Form for creating or editing a project
struct ProjectFormView: View {
    enum Mode {
        case create
        case edit(Project)

        var title: String {
            switch self {
            case .create: return "New Project"
            case .edit: return "Edit Project"
            }
        }

        var buttonTitle: String {
            switch self {
            case .create: return "Create"
            case .edit: return "Save"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss

    let mode: Mode
    let onSave: (String, String?, Date?, Date?) -> Void

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var hasStartDate = false
    @State private var startDate = Date()
    @State private var hasEndDate = false
    @State private var endDate = Date()

    init(mode: Mode, onSave: @escaping (String, String?, Date?, Date?) -> Void) {
        self.mode = mode
        self.onSave = onSave

        if case .edit(let project) = mode {
            _name = State(initialValue: project.name)
            _description = State(initialValue: project.description ?? "")
            _hasStartDate = State(initialValue: project.startDate != nil)
            _startDate = State(initialValue: project.startDate ?? Date())
            _hasEndDate = State(initialValue: project.endDate != nil)
            _endDate = State(initialValue: project.endDate ?? Date())
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Project Details") {
                    TextField("Project Name", text: $name)
                        .textInputAutocapitalization(.words)

                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Dates") {
                    Toggle("Start Date", isOn: $hasStartDate)

                    if hasStartDate {
                        DatePicker(
                            "Start",
                            selection: $startDate,
                            displayedComponents: .date
                        )
                    }

                    Toggle("End Date", isOn: $hasEndDate)

                    if hasEndDate {
                        DatePicker(
                            "End",
                            selection: $endDate,
                            in: startDate...,
                            displayedComponents: .date
                        )
                    }
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(mode.buttonTitle) {
                        save()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)

        onSave(
            trimmedName,
            trimmedDescription.isEmpty ? nil : trimmedDescription,
            hasStartDate ? startDate : nil,
            hasEndDate ? endDate : nil
        )

        dismiss()
    }
}

#Preview("Create") {
    ProjectFormView(mode: .create) { _, _, _, _ in }
}

#Preview("Edit") {
    ProjectFormView(mode: .edit(Project(
        id: 1,
        name: "Test Project",
        description: "A test description",
        startDate: Date()
    ))) { _, _, _, _ in }
}
