import Foundation

/// ViewModel for rendering and validating dynamic form data
@Observable
final class FormRendererViewModel {
    let fields: [FormField]
    var values: [String: String]
    var validationErrors: [String: String] = [:]

    init(fields: [FormField], values: [String: String] = [:]) {
        self.fields = fields
        self.values = values

        // Initialize defaults
        for field in fields where values[field.name] == nil {
            if let defaultValue = field.defaultValue {
                self.values[field.name] = defaultValue
            }
        }
    }

    func setValue(for field: FormField, value: String) {
        values[field.name] = value
        // Clear validation error on edit
        validationErrors.removeValue(forKey: field.name)
    }

    func validate() -> Bool {
        validationErrors.removeAll()

        for field in fields {
            let value = values[field.name] ?? ""

            // Required check
            if field.isRequired && value.trimmingCharacters(in: .whitespaces).isEmpty {
                validationErrors[field.name] = "\(field.label) is required"
                continue
            }

            // Skip further validation if empty and not required
            if value.isEmpty { continue }

            // Number validation
            if field.fieldType == .number {
                guard let numValue = Double(value) else {
                    validationErrors[field.name] = "\(field.label) must be a number"
                    continue
                }

                if let minStr = field.validationRules["min"], let min = Double(minStr), numValue < min {
                    validationErrors[field.name] = "\(field.label) must be at least \(minStr)"
                }
                if let maxStr = field.validationRules["max"], let max = Double(maxStr), numValue > max {
                    validationErrors[field.name] = "\(field.label) must be at most \(maxStr)"
                }
            }
        }

        return validationErrors.isEmpty
    }
}
