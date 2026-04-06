import SwiftUI

/// Dynamic form renderer that displays appropriate controls for each field type
struct FormRendererView: View {
    let fields: [FormField]
    @Binding var values: [String: String]

    var body: some View {
        ForEach(fields) { field in
            FieldView(field: field, value: binding(for: field))
        }
    }

    private func binding(for field: FormField) -> Binding<String> {
        Binding(
            get: { values[field.name] ?? field.defaultValue ?? "" },
            set: { values[field.name] = $0 }
        )
    }
}

// MARK: - Individual Field View

private struct FieldView: View {
    let field: FormField
    @Binding var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            fieldLabel

            switch field.fieldType {
            case .text:
                TextField(field.label, text: $value)
            case .textArea:
                TextField(field.label, text: $value, axis: .vertical)
                    .lineLimit(3...8)
            case .number:
                TextField(field.label, text: $value)
                    .keyboardType(.decimalPad)
            case .dropdown:
                Picker(field.label, selection: $value) {
                    Text("Select...").tag("")
                    ForEach(field.options, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .labelsHidden()
            case .multiSelect:
                MultiSelectView(options: field.options, value: $value)
            case .date:
                DateFieldView(value: $value)
            case .toggle:
                Toggle(field.label, isOn: toggleBinding)
                    .labelsHidden()
            case .gpsCoordinates:
                GPSFieldView(value: $value)
            case .photo:
                Text("Photo capture")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
    }

    @ViewBuilder
    private var fieldLabel: some View {
        HStack {
            Text(field.label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if field.isRequired {
                Text("*")
                    .foregroundStyle(.red)
            }
        }
    }

    private var toggleBinding: Binding<Bool> {
        Binding(
            get: { value == "true" },
            set: { value = $0 ? "true" : "false" }
        )
    }
}

// MARK: - Multi-Select View

private struct MultiSelectView: View {
    let options: [String]
    @Binding var value: String

    private var selectedOptions: Set<String> {
        Set(value.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
    }

    var body: some View {
        ForEach(options, id: \.self) { option in
            Toggle(option, isOn: Binding(
                get: { selectedOptions.contains(option) },
                set: { isSelected in
                    var selected = selectedOptions
                    if isSelected {
                        selected.insert(option)
                    } else {
                        selected.remove(option)
                    }
                    value = selected.sorted().joined(separator: ", ")
                }
            ))
        }
    }
}

// MARK: - Date Field View

private struct DateFieldView: View {
    @Binding var value: String
    @State private var date = Date()

    private let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    var body: some View {
        DatePicker("", selection: $date, displayedComponents: .date)
            .labelsHidden()
            .onChange(of: date) { _, newDate in
                value = formatter.string(from: newDate)
            }
            .onAppear {
                if let parsed = formatter.date(from: value) {
                    date = parsed
                }
            }
    }
}

// MARK: - GPS Field View

private struct GPSFieldView: View {
    @Binding var value: String

    private var lat: String {
        let parts = value.components(separatedBy: ",")
        return parts.first?.trimmingCharacters(in: .whitespaces) ?? ""
    }

    private var lon: String {
        let parts = value.components(separatedBy: ",")
        return parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
    }

    var body: some View {
        HStack {
            TextField("Latitude", text: Binding(
                get: { lat },
                set: { newLat in value = "\(newLat), \(lon)" }
            ))
            .keyboardType(.decimalPad)

            TextField("Longitude", text: Binding(
                get: { lon },
                set: { newLon in value = "\(lat), \(newLon)" }
            ))
            .keyboardType(.decimalPad)
        }
    }
}
