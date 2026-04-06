import SwiftUI
import GRDB

/// Form for creating or editing a record with dynamic form fields
struct RecordFormView: View {
    @Environment(\.dismiss) private var dismiss

    let projectId: Int64
    var parentRecordId: Int64?
    var existingRecord: Record?
    let dbPool: DatabasePool
    var onSave: () -> Void

    @State private var name = ""
    @State private var description = ""
    @State private var selectedTypeId: Int64?
    @State private var latitude = ""
    @State private var longitude = ""
    @State private var formValues: [String: String] = [:]
    @State private var formFields: [FormField] = []
    @State private var recordTypes: [RecordType] = []
    @State private var formTemplate: FormTemplate?

    private var isEditing: Bool { existingRecord != nil }

    var body: some View {
        Form {
            Section("Basic Information") {
                TextField("Name", text: $name)

                Picker("Record Type", selection: $selectedTypeId) {
                    Text("Select Type").tag(nil as Int64?)
                    ForEach(recordTypes) { type in
                        Text(type.name).tag(type.id as Int64?)
                    }
                }
                .disabled(isEditing)

                TextField("Description (optional)", text: $description, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section("Location (Optional)") {
                TextField("Latitude", text: $latitude)
                    .keyboardType(.decimalPad)
                TextField("Longitude", text: $longitude)
                    .keyboardType(.decimalPad)
            }

            // Dynamic form fields
            if !formFields.isEmpty {
                Section("Form Fields") {
                    FormRendererView(fields: formFields, values: $formValues)
                }
            }
        }
        .navigationTitle(isEditing ? "Edit Record" : "New Record")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isEditing ? "Save" : "Create") {
                    save()
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || selectedTypeId == nil)
            }
        }
        .onChange(of: selectedTypeId) { _, newValue in
            loadFormFields(for: newValue)
        }
        .onAppear {
            loadRecordTypes()
            if let existing = existingRecord {
                name = existing.name
                description = existing.description ?? ""
                selectedTypeId = existing.recordTypeId
                formValues = existing.formData
                if let lat = existing.latitude {
                    latitude = String(format: "%.6f", lat)
                }
                if let lon = existing.longitude {
                    longitude = String(format: "%.6f", lon)
                }
                loadFormFields(for: existing.recordTypeId)
            }
        }
    }

    private func loadRecordTypes() {
        let repo = RecordTypeRepository(dbPool: dbPool)
        recordTypes = (try? repo.fetchAll(projectId: projectId)) ?? []
    }

    private func loadFormFields(for typeId: Int64?) {
        guard let typeId else {
            formFields = []
            formTemplate = nil
            return
        }
        let templateRepo = FormTemplateRepository(dbPool: dbPool)
        if let result = try? templateRepo.fetchWithFieldsByRecordType(typeId) {
            formTemplate = result.0
            formFields = result.1
        } else {
            formFields = []
            formTemplate = nil
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedDesc = description.trimmingCharacters(in: .whitespaces)
        guard let typeId = selectedTypeId else { return }

        let lat = Double(latitude)
        let lon = Double(longitude)

        let repo = RecordRepository(dbPool: dbPool)

        if var existing = existingRecord {
            existing.name = trimmedName
            existing.description = trimmedDesc.isEmpty ? nil : trimmedDesc
            existing.latitude = lat
            existing.longitude = lon
            existing.formData = formValues
            existing.formTemplateVersion = formTemplate?.version
            try? repo.update(existing)
        } else {
            let record = Record(
                projectId: projectId,
                recordTypeId: typeId,
                parentRecordId: parentRecordId,
                name: trimmedName,
                description: trimmedDesc.isEmpty ? nil : trimmedDesc,
                latitude: lat,
                longitude: lon,
                formData: formValues,
                formTemplateVersion: formTemplate?.version
            )
            try? repo.create(record)
        }

        onSave()
        dismiss()
    }
}
