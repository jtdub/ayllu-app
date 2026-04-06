import SwiftUI

/// Form for creating or editing a record type
struct RecordTypeFormView: View {
    @Environment(DatabaseManager.self) private var database
    @Environment(\.dismiss) private var dismiss

    let projectId: Int64
    var existingRecordType: RecordType?

    @State private var name = ""
    @State private var description = ""
    @State private var parentTypeId: Int64?
    @State private var iconName = "doc"
    @State private var color = "#007AFF"
    @State private var availableTypes: [RecordType] = []

    private var isEditing: Bool { existingRecordType != nil }

    private let iconOptions = [
        "doc", "building.columns", "square.stack.3d.up",
        "rectangle.stack", "fossil.shell", "leaf",
        "map", "flag", "pin", "cube", "archivebox",
        "testtube.2", "camera", "eye", "ruler"
    ]

    private let colorOptions = [
        "#007AFF", "#FF3B30", "#FF9500", "#FFCC00",
        "#34C759", "#5AC8FA", "#AF52DE", "#FF2D55",
        "#8E8E93", "#A2845E"
    ]

    var body: some View {
        Form {
            Section("Basic Information") {
                TextField("Name", text: $name)
                TextField("Description (optional)", text: $description)
            }

            Section("Parent Type") {
                Picker("Parent Type", selection: $parentTypeId) {
                    Text("None (Root Level)").tag(nil as Int64?)
                    ForEach(availableTypes.filter { $0.id != existingRecordType?.id }) { type in
                        Text(type.name).tag(type.id as Int64?)
                    }
                }
            }

            Section("Icon") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                    ForEach(iconOptions, id: \.self) { icon in
                        Button {
                            iconName = icon
                        } label: {
                            Image(systemName: icon)
                                .font(.title2)
                                .frame(width: 44, height: 44)
                                .background(iconName == icon ? Color.accentColor.opacity(0.2) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section("Color") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                    ForEach(colorOptions, id: \.self) { hex in
                        Button {
                            color = hex
                        } label: {
                            Circle()
                                .fill(Color(hex: hex) ?? .accentColor)
                                .frame(width: 36, height: 36)
                                .overlay {
                                    if color == hex {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.white)
                                            .font(.caption.bold())
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if isEditing {
                Section {
                    NavigationLink("Edit Form Fields") {
                        if let typeId = existingRecordType?.id {
                            FormBuilderView(recordTypeId: typeId)
                        }
                    }
                }
            }
        }
        .navigationTitle(isEditing ? "Edit Record Type" : "New Record Type")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                if !isEditing {
                    Button("Cancel") { dismiss() }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isEditing ? "Save" : "Create") {
                    save()
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear {
            loadAvailableTypes()
            if let existing = existingRecordType {
                name = existing.name
                description = existing.description ?? ""
                parentTypeId = existing.parentTypeId
                iconName = existing.iconName ?? "doc"
                color = existing.color ?? "#007AFF"
            }
        }
    }

    private func loadAvailableTypes() {
        let repo = RecordTypeRepository(dbPool: database.dbPool)
        availableTypes = (try? repo.fetchAll(projectId: projectId)) ?? []
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedDesc = description.trimmingCharacters(in: .whitespaces)

        if isEditing {
            guard var existing = existingRecordType else { return }
            existing.name = trimmedName
            existing.description = trimmedDesc.isEmpty ? nil : trimmedDesc
            existing.parentTypeId = parentTypeId
            existing.iconName = iconName
            existing.color = color

            let repo = RecordTypeRepository(dbPool: database.dbPool)
            try? repo.update(existing)
        } else {
            let viewModel = RecordTypeListViewModel(dbPool: database.dbPool, projectId: projectId)
            viewModel.createRecordType(
                name: trimmedName,
                description: trimmedDesc.isEmpty ? nil : trimmedDesc,
                parentTypeId: parentTypeId,
                iconName: iconName,
                color: color
            )
        }
        dismiss()
    }
}
