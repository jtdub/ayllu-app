import Foundation

private typealias VK = ValidationRuleKey

/// ViewModel for rendering and validating dynamic form data
@Observable
final class FormRendererViewModel {
    let fields: [FormField]
    var values: [String: String]
    var validationErrors: [String: String] = [:]
    var firstErrorFieldName: String?

    static let isoDateFormatter: ISO8601DateFormatter = {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withFullDate]
        return fmt
    }()

    static let displayDateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        return fmt
    }()

    init(fields: [FormField], values: [String: String] = [:]) {
        self.fields = fields
        self.values = values

        for field in fields where values[field.name] == nil {
            if let defaultValue = field.defaultValue {
                self.values[field.name] = defaultValue
            }
        }
    }

    func setValue(for field: FormField, value: String) {
        values[field.name] = value
        validationErrors.removeValue(forKey: field.name)
    }

    /// Validates all fields. When `asDraft` is true, required checks are skipped
    /// but format/range validation still runs.
    func validate(asDraft: Bool = false) -> Bool {
        validationErrors.removeAll()
        firstErrorFieldName = nil

        for field in fields {
            let value = values[field.name] ?? ""

            if field.isRequired && !asDraft && value.trimmingCharacters(in: .whitespaces).isEmpty {
                validationErrors[field.name] = "\(field.label) is required"
                continue
            }

            if value.isEmpty { continue }

            switch field.fieldType {
            case .number:
                validateNumber(field: field, value: value)
            case .text, .textArea:
                validateText(field: field, value: value)
            case .gpsCoordinates:
                validateGPSCoordinates(field: field, value: value)
            case .date:
                validateDate(field: field, value: value)
            case .dropdown, .multiSelect, .photo, .toggle:
                break
            }
        }

        firstErrorFieldName = fields.first { validationErrors[$0.name] != nil }?.name
        return validationErrors.isEmpty
    }

    // MARK: - Number Validation

    private func validateNumber(field: FormField, value: String) {
        guard let numValue = Double(value) else {
            validationErrors[field.name] = "\(field.label) must be a number"
            return
        }

        if let minStr = field.validationRules[VK.min],
           let min = Double(minStr), numValue < min {
            validationErrors[field.name] = "\(field.label) must be at least \(minStr)"
            return
        }
        if let maxStr = field.validationRules[VK.max],
           let max = Double(maxStr), numValue > max {
            validationErrors[field.name] = "\(field.label) must be at most \(maxStr)"
        }
    }

    // MARK: - Text Validation

    private func validateText(field: FormField, value: String) {
        if let minLenStr = field.validationRules[VK.minLength],
           let minLen = Int(minLenStr), value.count < minLen {
            validationErrors[field.name] = "\(field.label) must be at least \(minLen) characters"
            return
        }
        if let maxLenStr = field.validationRules[VK.maxLength],
           let maxLen = Int(maxLenStr), value.count > maxLen {
            validationErrors[field.name] = "\(field.label) must be at most \(maxLen) characters"
            return
        }
        if let pattern = field.validationRules[VK.pattern], !pattern.isEmpty {
            do {
                let regex = try NSRegularExpression(pattern: pattern)
                let range = NSRange(value.startIndex..., in: value)
                if regex.firstMatch(in: value, range: range) == nil {
                    let message = field.validationRules[VK.patternMessage]
                        ?? "\(field.label) has an invalid format"
                    validationErrors[field.name] = message
                }
            } catch {
                // Invalid regex — skip rather than crash; caught at design time
            }
        }
    }

    // MARK: - GPS Coordinate Validation

    private func validateGPSCoordinates(field: FormField, value: String) {
        let parts = value.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2 else {
            validationErrors[field.name] = "\(field.label) must be latitude, longitude"
            return
        }

        guard let lat = Double(parts[0]) else {
            validationErrors[field.name] = "Latitude must be a number"
            return
        }
        guard let lon = Double(parts[1]) else {
            validationErrors[field.name] = "Longitude must be a number"
            return
        }

        if !CoordinateFormatter.isValidLatitude(lat) {
            validationErrors[field.name] = "Latitude must be between -90 and 90"
            return
        }
        if !CoordinateFormatter.isValidLongitude(lon) {
            validationErrors[field.name] = "Longitude must be between -180 and 180"
        }
    }

    // MARK: - Date Validation

    private func validateDate(field: FormField, value: String) {
        guard let date = Self.displayDateFormatter.date(from: value) else {
            return
        }

        if field.validationRules[VK.noFutureDates] == "true" && date > Date() {
            validationErrors[field.name] = "\(field.label) cannot be a future date"
            return
        }

        if let minDateStr = field.validationRules[VK.minDate],
           let minDate = Self.isoDateFormatter.date(from: minDateStr),
           date < minDate {
            let formatted = Self.displayDateFormatter.string(from: minDate)
            validationErrors[field.name] = "\(field.label) must be on or after \(formatted)"
            return
        }

        if let maxDateStr = field.validationRules[VK.maxDate],
           let maxDate = Self.isoDateFormatter.date(from: maxDateStr),
           date > maxDate {
            let formatted = Self.displayDateFormatter.string(from: maxDate)
            validationErrors[field.name] = "\(field.label) must be on or before \(formatted)"
        }
    }
}
