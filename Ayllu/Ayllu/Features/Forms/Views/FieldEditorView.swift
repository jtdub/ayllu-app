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

    // Number validation
    @State private var minValue = ""
    @State private var maxValue = ""

    // Text validation
    @State private var minLength = ""
    @State private var maxLength = ""
    @State private var pattern = ""
    @State private var patternMessage = ""

    // Date validation
    @State private var noFutureDates = false
    @State private var hasMinDate = false
    @State private var hasMaxDate = false
    @State private var minDate = Date()
    @State private var maxDate = Date()

    private var isEditing: Bool { existingField != nil }

    private var isoFormatter: ISO8601DateFormatter { FormRendererViewModel.isoDateFormatter }

    var body: some View {
        Form {
            Section("Field Properties") {
                TextField("Label (display name)", text: $label)
                    .onChange(of: label) { _, newValue in
                        if !isEditing {
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

            // Number validation
            if fieldType == .number {
                Section("Number Validation") {
                    TextField("Minimum value", text: $minValue)
                        .keyboardType(.decimalPad)
                    TextField("Maximum value", text: $maxValue)
                        .keyboardType(.decimalPad)
                }
            }

            // Text validation
            if fieldType == .text || fieldType == .textArea {
                Section("Text Validation") {
                    TextField("Minimum length", text: $minLength)
                        .keyboardType(.numberPad)
                    TextField("Maximum length", text: $maxLength)
                        .keyboardType(.numberPad)
                }

                Section("Pattern Validation (Optional)") {
                    TextField("Regex pattern", text: $pattern)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Error message for invalid pattern", text: $patternMessage)
                }
            }

            // Date validation
            if fieldType == .date {
                Section("Date Validation") {
                    Toggle("No future dates", isOn: $noFutureDates)

                    Toggle("Earliest date", isOn: $hasMinDate)
                    if hasMinDate {
                        DatePicker(
                            "Earliest",
                            selection: $minDate,
                            displayedComponents: .date
                        )
                    }

                    Toggle("Latest date", isOn: $hasMaxDate)
                    if hasMaxDate {
                        DatePicker(
                            "Latest",
                            selection: $maxDate,
                            displayedComponents: .date
                        )
                    }
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
                .disabled(
                    label.trimmingCharacters(in: .whitespaces).isEmpty ||
                    name.trimmingCharacters(in: .whitespaces).isEmpty
                )
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
                minValue = field.validationRules[ValidationRuleKey.min] ?? ""
                maxValue = field.validationRules[ValidationRuleKey.max] ?? ""
                minLength = field.validationRules[ValidationRuleKey.minLength] ?? ""
                maxLength = field.validationRules[ValidationRuleKey.maxLength] ?? ""
                pattern = field.validationRules[ValidationRuleKey.pattern] ?? ""
                patternMessage = field.validationRules[ValidationRuleKey.patternMessage] ?? ""
                noFutureDates = field.validationRules[ValidationRuleKey.noFutureDates] == "true"

                if let minDateStr = field.validationRules[ValidationRuleKey.minDate],
                   let date = isoFormatter.date(from: minDateStr) {
                    hasMinDate = true
                    minDate = date
                }
                if let maxDateStr = field.validationRules[ValidationRuleKey.maxDate],
                   let date = isoFormatter.date(from: maxDateStr) {
                    hasMaxDate = true
                    maxDate = date
                }
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
        if !minValue.isEmpty { rules[ValidationRuleKey.min] = minValue }
        if !maxValue.isEmpty { rules[ValidationRuleKey.max] = maxValue }
        if !minLength.isEmpty { rules[ValidationRuleKey.minLength] = minLength }
        if !maxLength.isEmpty { rules[ValidationRuleKey.maxLength] = maxLength }
        if !pattern.isEmpty { rules[ValidationRuleKey.pattern] = pattern }
        if !patternMessage.isEmpty { rules[ValidationRuleKey.patternMessage] = patternMessage }
        if noFutureDates { rules[ValidationRuleKey.noFutureDates] = "true" }
        if hasMinDate { rules[ValidationRuleKey.minDate] = isoFormatter.string(from: minDate) }
        if hasMaxDate { rules[ValidationRuleKey.maxDate] = isoFormatter.string(from: maxDate) }

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
