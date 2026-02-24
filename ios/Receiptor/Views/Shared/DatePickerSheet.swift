import SwiftUI

struct DatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    @Binding var date: Date
    var min: Date? = nil
    var max: Date? = nil

    var body: some View {
        NavigationStack {
            pickerView
                .datePickerStyle(.graphical)
                .padding(.horizontal)
                .labelsHidden()
                .onChange(of: date) { _, _ in dismiss() }
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }

    @ViewBuilder
    private var pickerView: some View {
        if let min, let max {
            DatePicker("", selection: $date, in: min...max, displayedComponents: .date)
        } else if let min {
            DatePicker("", selection: $date, in: min..., displayedComponents: .date)
        } else if let max {
            DatePicker("", selection: $date, in: ...max, displayedComponents: .date)
        } else {
            DatePicker("", selection: $date, displayedComponents: .date)
        }
    }
}
