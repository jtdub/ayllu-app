import SwiftUI

/// Sheet for creating or editing a single form field
struct FieldEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let viewModel: FormBuilderViewModel
    var existingField: FormField?

    @State private var name = ""
    @State private var label = ""
    @State private var fieldType: FieldType = .text
    @State private var isRequired = false
    @State private var defaultValue = ""
    @State private var optionsText = ""
    @State private var minValue = ""
    @State private var maxValue = ""

    private var isEditing: Bool { existingField != nil }

    var body: some View {
        Form {
            Section("Field Properties") {
                TextField("Label (display name)", text: $label)
                    .onChange(of: label) { _, newValue in
                        if !isEditing {
                            // Auto-generate name from label
                            name = newValue.lowercased()
                                .replacingOccurrences(of: " ", with: "_")
                                .filter { $0.isLetter || $0.isNumber || $0 == "_" }
                        }
                    }

                TextField("Field name (internal key)", text: $name)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Picker("Type", selection: $fieldType) {
                    ForEach(FieldType.allCases, id: \.self) { type in
                        Label(type.displayName, systemImage: type.iconName)
                            .tag(type)
                    }
                }

                Toggle("Required", isOn: $isRequired)
            }

            Section("Default Value") {
                TextField("Default value (optional)", text: $defaultValue)
            }

            // Options for dropdown/multiSelect
            if fieldType == .dropdown || fieldType == .multiSelect {
                Section("Options (one per line)") {
                    TextEditor(text: $optionsText)
                        .frame(minHeight: 100)
                }
            }

            // Validation for number fields
            if fieldType == .number {
                Section("Validation") {
                    TextField("Minimum value", text: $minValue)
                        .keyboardType(.decimalPad)
                    TextField("Maximum value", text: $maxValue)
                        .keyboardType(.decimalPad)
                }
            }
        }
        .navigationTitle(isEditing ? "Edit Field" : "Add Field")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isEditing ? "Save" : "Add") {
                    save()
                }
                .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty ||
                          name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear {
            if let field = existingField {
                name = field.name
                label = field.label
                fieldType = field.fieldType
                isRequired = field.isRequired
                defaultValue = field.defaultValue ?? ""
                optionsText = field.options.joined(separator: "\n")
                minValue = field.validationRules["min"] ?? ""
                maxValue = field.validationRules["max"] ?? ""
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedLabel = label.trimmingCharacters(in: .whitespaces)

        let options = optionsText
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var rules: [String: String] = [:]
        if !minValue.isEmpty { rules["min"] = minValue }
        if !maxValue.isEmpty { rules["max"] = maxValue }

        if var existing = existingField {
            existing.name = trimmedName
            existing.label = trimmedLabel
            existing.fieldType = fieldType
            existing.isRequired = isRequired
            existing.defaultValue = defaultValue.isEmpty ? nil : defaultValue
            existing.options = options
            existing.validationRules = rules
            viewModel.updateField(existing)
        } else {
            guard let templateId = viewModel.template?.id else { return }
            let field = FormField(
                formTemplateId: templateId,
                name: trimmedName,
                label: trimmedLabel,
                fieldType: fieldType,
                isRequired: isRequired,
                defaultValue: defaultValue.isEmpty ? nil : defaultValue,
                options: options,
                validationRules: rules
            )
            viewModel.addField(field)
        }
        dismiss()
    }
}
