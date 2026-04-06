import SwiftUI
import GRDB

/// Detail view for a single record showing form data, children, and geometries
struct RecordDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let record: Record
    let dbPool: DatabasePool

    @State private var recordType: RecordType?
    @State private var formFields: [FormField] = []
    @State private var childCount = 0
    @State private var geometryCount = 0
    @State private var showingEdit = false

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        List {
            // Header
            Section("Record Information") {
                LabeledContent("Name", value: record.name)

                if let typeName = recordType?.name {
                    LabeledContent("Type", value: typeName)
                }

                if let description = record.description, !description.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Description")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(description)
                    }
                }

                LabeledContent("Created", value: dateFormatter.string(from: record.createdAt))
            }

            // Location
            if let latitude = record.latitude, let longitude = record.longitude {
                Section("Location") {
                    LabeledContent("Latitude", value: String(format: "%.6f", latitude))
                    LabeledContent("Longitude", value: String(format: "%.6f", longitude))
                    if let altitude = record.altitude {
                        LabeledContent("Altitude", value: String(format: "%.1f m", altitude))
                    }
                }
            }

            // Form data
            if !record.formData.isEmpty && !formFields.isEmpty {
                Section("Form Data") {
                    ForEach(formFields) { field in
                        if let value = record.formData[field.name], !value.isEmpty {
                            LabeledContent(field.label, value: value)
                        }
                    }
                }
            } else if !record.formData.isEmpty {
                Section("Form Data") {
                    ForEach(Array(record.formData.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                        LabeledContent(key, value: value)
                    }
                }
            }

            // Children and geometries
            Section("Related") {
                LabeledContent("Child Records", value: "\(childCount)")
                LabeledContent("Geometries", value: "\(geometryCount)")
            }

            // Actions
            Section {
                Button {
                    showingEdit = true
                } label: {
                    Label("Edit Record", systemImage: "pencil")
                }
            }
        }
        .navigationTitle(record.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
        .sheet(isPresented: $showingEdit) {
            NavigationStack {
                RecordFormView(
                    projectId: record.projectId,
                    parentRecordId: record.parentRecordId,
                    existingRecord: record,
                    dbPool: dbPool
                ) {}
            }
        }
        .onAppear {
            loadDetails()
        }
    }

    private func loadDetails() {
        // Load record type
        let typeRepo = RecordTypeRepository(dbPool: dbPool)
        recordType = try? typeRepo.fetchById(record.recordTypeId)

        // Load form fields for display
        let templateRepo = FormTemplateRepository(dbPool: dbPool)
        if let result = try? templateRepo.fetchWithFieldsByRecordType(record.recordTypeId) {
            formFields = result.1
        }

        // Load counts
        if let id = record.id {
            let recordRepo = RecordRepository(dbPool: dbPool)
            childCount = (try? recordRepo.countChildren(parentRecordId: id)) ?? 0

            let geometryRepo = GeometryRepository(dbPool: dbPool)
            let geometries = (try? geometryRepo.fetchByRecord(id)) ?? []
            geometryCount = geometries.count
        }
    }
}
