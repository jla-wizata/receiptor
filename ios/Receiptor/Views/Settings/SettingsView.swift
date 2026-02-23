import SwiftUI

struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()

    private let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        Group {
            if viewModel.isLoading {
                LoadingView()
            } else {
                form
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil), actions: {
            Button("OK") { viewModel.errorMessage = nil }
        }, message: {
            Text(viewModel.errorMessage ?? "")
        })
        .alert("Saved", isPresented: .constant(viewModel.successMessage != nil), actions: {
            Button("OK") { viewModel.successMessage = nil }
        }, message: {
            Text(viewModel.successMessage ?? "")
        })
    }

    private var form: some View {
        Form {
            Section("Country") {
                Picker("Working Country", selection: $viewModel.workingCountryCode) {
                    ForEach(viewModel.countries) { country in
                        Text(country.name).tag(country.countryCode)
                    }
                }
                Picker("Residence Country", selection: $viewModel.residenceCountryCode) {
                    ForEach(viewModel.countries) { country in
                        Text(country.name).tag(country.countryCode)
                    }
                }
            }

            Section("Compliance") {
                Stepper(
                    "Threshold: \(viewModel.homeworkingThreshold) days",
                    value: $viewModel.homeworkingThreshold,
                    in: 1...365
                )
            }

            Section("Working Days") {
                HStack(spacing: 8) {
                    ForEach(0..<7, id: \.self) { day in
                        DayToggle(
                            label: dayNames[day],
                            isOn: viewModel.workingDays.contains(day)
                        ) {
                            if viewModel.workingDays.contains(day) {
                                viewModel.workingDays.remove(day)
                            } else {
                                viewModel.workingDays.insert(day)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                Button(action: { Task { await viewModel.save() } }) {
                    if viewModel.isSaving {
                        HStack {
                            ProgressView()
                            Text("Saving...")
                        }
                    } else {
                        Text("Save Settings")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .disabled(viewModel.isSaving)
            }
        }
    }
}

struct DayToggle: View {
    let label: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(isOn ? .bold : .regular)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isOn ? Color.accentColor : Color(.tertiarySystemBackground))
                .foregroundColor(isOn ? .white : .secondary)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
