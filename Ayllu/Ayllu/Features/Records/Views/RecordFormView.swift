import SwiftUI

/// Form for creating or editing a record with dynamic form fields
struct RecordFormView: View {
    @Environment(DatabaseManager.self) private var database
    @Environment(\.dismiss) private var dismiss

    let projectId: Int64
    var parentRecordId: Int64?
    var existingRecord: Record?
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
    @State private var formViewModel: FormRendererViewModel?
    @State private var locationError: String?

    private var isEditing: Bool { existingRecord != nil }

    var body: some View {
        ScrollViewReader { proxy in
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

                    if let locationError {
                        Text(locationError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .id("location")

                if !formFields.isEmpty {
                    Section("Form Fields") {
                        FormRendererView(
                            fields: formFields,
                            values: $formValues,
                            validationErrors: formViewModel?.validationErrors ?? [:]
                        )
                    }
                }
            }
            .onChange(of: formViewModel?.firstErrorFieldName) { _, fieldName in
                if let fieldName {
                    withAnimation {
                        proxy.scrollTo(fieldName, anchor: .center)
                    }
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
                Menu {
                    Button {
                        save(asDraft: false)
                    } label: {
                        Label("Save", systemImage: "checkmark")
                    }

                    Button {
                        save(asDraft: true)
                    } label: {
                        Label("Save as Draft", systemImage: "doc.badge.clock")
                    }
                } label: {
                    Text(isEditing ? "Save" : "Create")
                } primaryAction: {
                    save(asDraft: false)
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || selectedTypeId == nil)
            }
        }
        .onChange(of: selectedTypeId) { _, newValue in
            loadFormFields(for: newValue)
        }
        .onChange(of: formValues) { oldValues, newValues in
            guard let vm = formViewModel else { return }
            // Only update changed fields to clear their validation errors
            for (key, value) in newValues where oldValues[key] != value {
                if let field = formFields.first(where: { $0.name == key }) {
                    vm.setValue(for: field, value: value)
                }
            }
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
        let repo = RecordTypeRepository(dbPool: database.dbPool)
        recordTypes = (try? repo.fetchAll(projectId: projectId)) ?? []
    }

    private func loadFormFields(for typeId: Int64?) {
        guard let typeId else {
            formFields = []
            formTemplate = nil
            formViewModel = nil
            return
        }
        let templateRepo = FormTemplateRepository(dbPool: database.dbPool)
        if let result = try? templateRepo.fetchWithFieldsByRecordType(typeId) {
            formTemplate = result.0
            formFields = result.1
            formViewModel = FormRendererViewModel(fields: result.1, values: formValues)
        } else {
            formFields = []
            formTemplate = nil
            formViewModel = nil
        }
    }

    private func validateLocation() -> Bool {
        locationError = nil

        let hasLat = !latitude.trimmingCharacters(in: .whitespaces).isEmpty
        let hasLon = !longitude.trimmingCharacters(in: .whitespaces).isEmpty

        if !hasLat && !hasLon { return true }

        if hasLat != hasLon {
            locationError = "Both latitude and longitude are required"
            return false
        }

        guard let lat = Double(latitude) else {
            locationError = "Latitude must be a number"
            return false
        }
        guard let lon = Double(longitude) else {
            locationError = "Longitude must be a number"
            return false
        }

        if !CoordinateFormatter.isValidLatitude(lat) {
            locationError = "Latitude must be between -90 and 90"
            return false
        }
        if !CoordinateFormatter.isValidLongitude(lon) {
            locationError = "Longitude must be between -180 and 180"
            return false
        }

        return true
    }

    private func save(asDraft: Bool) {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty, let typeId = selectedTypeId else { return }

        guard validateLocation() else { return }

        if let vm = formViewModel {
            vm.values = formValues
            if !vm.validate(asDraft: asDraft) {
                return
            }
        }

        let trimmedDesc = description.trimmingCharacters(in: .whitespaces)
        let lat = Double(latitude)
        let lon = Double(longitude)

        let repo = RecordRepository(dbPool: database.dbPool)

        if var existing = existingRecord {
            existing.name = trimmedName
            existing.description = trimmedDesc.isEmpty ? nil : trimmedDesc
            existing.latitude = lat
            existing.longitude = lon
            existing.formData = formValues
            existing.formTemplateVersion = formTemplate?.version
            existing.isDraft = asDraft
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
                formTemplateVersion: formTemplate?.version,
                isDraft: asDraft
            )
            try? repo.create(record)
        }

        onSave()
        dismiss()
    }
}
