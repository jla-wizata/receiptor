import SwiftUI

struct HolidaysView: View {
    @State private var viewModel = HolidaysViewModel()
    @State private var showAddHoliday = false
    @State private var showAddSchedule = false
    @State private var holidayToEdit: UserHoliday? = nil
    @State private var periodToEdit: WorkSchedulePeriod? = nil

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    LoadingView()
                } else {
                    holidaysList
                }
            }
            .navigationTitle("Holidays & Schedule")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Add Personal Holiday") { showAddHoliday = true }
                        Button("Add Schedule Period") { showAddSchedule = true }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
            .sheet(isPresented: $showAddHoliday) {
                AddHolidaySheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showAddSchedule) {
                AddSchedulePeriodSheet(viewModel: viewModel)
            }
            .sheet(item: $holidayToEdit) { holiday in
                EditHolidaySheet(viewModel: viewModel, holiday: holiday)
            }
            .sheet(item: $periodToEdit) { period in
                EditSchedulePeriodSheet(viewModel: viewModel, period: period)
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil), actions: {
                Button("OK") { viewModel.errorMessage = nil }
            }, message: {
                Text(viewModel.errorMessage ?? "")
            })
        }
    }

    private var holidaysList: some View {
        List {
            Section("Personal Holidays") {
                if viewModel.userHolidays.isEmpty {
                    Text("No personal holidays added")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(viewModel.userHolidays) { holiday in
                        HStack {
                            HolidayRow(holiday: holiday)
                            Spacer()
                            Button { holidayToEdit = holiday } label: {
                                Image(systemName: "pencil")
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.borderless)
                            Button {
                                Task { await viewModel.deleteHoliday(id: holiday.id) }
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }

            Section("Work Schedule Periods") {
                if viewModel.schedulePeriods.isEmpty {
                    Text("No custom schedule periods")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(viewModel.schedulePeriods) { period in
                        HStack(alignment: .top) {
                            SchedulePeriodRow(period: period)
                            Spacer()
                            Button { periodToEdit = period } label: {
                                Image(systemName: "pencil")
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.borderless)
                            Button {
                                Task { await viewModel.deleteSchedulePeriod(id: period.id) }
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
        }
    }
}

struct HolidayRow: View {
    let holiday: UserHoliday

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(holiday.startDate)
                Text("–")
                Text(holiday.endDate)
            }
            .font(.body)
            if let desc = holiday.description, !desc.isEmpty {
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct SchedulePeriodRow: View {
    let period: WorkSchedulePeriod
    private let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(period.startDate)
                Text("–")
                Text(period.endDate ?? "ongoing")
            }
            .font(.body)
            Text(period.workingDays.map { dayNames[$0] }.joined(separator: ", "))
                .font(.caption)
                .foregroundColor(.secondary)
            if let desc = period.description, !desc.isEmpty {
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Edit Holiday Sheet

struct EditHolidaySheet: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: HolidaysViewModel
    let holiday: UserHoliday

    @State private var startDate: Date
    @State private var endDate: Date
    @State private var description: String
    @State private var isSaving = false

    private static let fmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    init(viewModel: HolidaysViewModel, holiday: UserHoliday) {
        self.viewModel = viewModel
        self.holiday = holiday
        _startDate = State(initialValue: Self.fmt.date(from: holiday.startDate) ?? Date())
        _endDate = State(initialValue: Self.fmt.date(from: holiday.endDate) ?? Date())
        _description = State(initialValue: holiday.description ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Date Range") {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: .date)
                }
                Section("Description (optional)") {
                    TextField("e.g. Summer vacation", text: $description)
                }
            }
            .navigationTitle("Edit Holiday")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }.disabled(isSaving)
                }
            }
        }
    }

    private func save() {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        isSaving = true
        Task {
            await viewModel.updateHoliday(
                id: holiday.id,
                startDate: fmt.string(from: startDate),
                endDate: fmt.string(from: endDate),
                description: description.isEmpty ? nil : description
            )
            await MainActor.run { dismiss() }
        }
    }
}

// MARK: - Edit Schedule Period Sheet

struct EditSchedulePeriodSheet: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: HolidaysViewModel
    let period: WorkSchedulePeriod

    @State private var startDate: Date
    @State private var endDate: Date?
    @State private var hasEndDate: Bool
    @State private var workingDays: Set<Int>
    @State private var description: String
    @State private var isSaving = false

    private static let fmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()
    private let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    init(viewModel: HolidaysViewModel, period: WorkSchedulePeriod) {
        self.viewModel = viewModel
        self.period = period
        _startDate = State(initialValue: Self.fmt.date(from: period.startDate) ?? Date())
        let ed = period.endDate.flatMap { Self.fmt.date(from: $0) }
        _endDate = State(initialValue: ed)
        _hasEndDate = State(initialValue: ed != nil)
        _workingDays = State(initialValue: Set(period.workingDays))
        _description = State(initialValue: period.description ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Date Range") {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    Toggle("Has end date", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker("End Date", selection: Binding(
                            get: { endDate ?? startDate },
                            set: { endDate = $0 }
                        ), in: startDate..., displayedComponents: .date)
                    }
                }
                Section("Working Days") {
                    HStack(spacing: 8) {
                        ForEach(0..<7, id: \.self) { day in
                            DayToggle(label: dayNames[day], isOn: workingDays.contains(day)) {
                                if workingDays.contains(day) { workingDays.remove(day) }
                                else { workingDays.insert(day) }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section("Description (optional)") {
                    TextField("e.g. Part-time period", text: $description)
                }
            }
            .navigationTitle("Edit Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }.disabled(isSaving || workingDays.isEmpty)
                }
            }
        }
    }

    private func save() {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        isSaving = true
        let endStr = hasEndDate ? fmt.string(from: endDate ?? startDate) : nil
        Task {
            await viewModel.updateSchedulePeriod(
                id: period.id,
                startDate: fmt.string(from: startDate),
                endDate: endStr,
                workingDays: Array(workingDays).sorted(),
                description: description.isEmpty ? nil : description
            )
            await MainActor.run { dismiss() }
        }
    }
}

// MARK: - Add Holiday Sheet

struct AddHolidaySheet: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: HolidaysViewModel

    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var description = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Date Range") {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: .date)
                }
                Section("Description (optional)") {
                    TextField("e.g. Summer vacation", text: $description)
                }
            }
            .navigationTitle("Add Holiday")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .disabled(isSaving)
                }
            }
        }
    }

    private func save() {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        isSaving = true
        Task {
            await viewModel.createHoliday(
                startDate: fmt.string(from: startDate),
                endDate: fmt.string(from: endDate),
                description: description.isEmpty ? nil : description
            )
            await MainActor.run { dismiss() }
        }
    }
}

// MARK: - Add Schedule Period Sheet

struct AddSchedulePeriodSheet: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: HolidaysViewModel

    @State private var startDate = Date()
    @State private var endDate: Date? = nil
    @State private var hasEndDate = false
    @State private var workingDays: Set<Int> = [0, 1, 2, 3, 4]
    @State private var description = ""
    @State private var isSaving = false

    private let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Date Range") {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    Toggle("Has end date", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker("End Date", selection: Binding(
                            get: { endDate ?? startDate },
                            set: { endDate = $0 }
                        ), in: startDate..., displayedComponents: .date)
                    }
                }
                Section("Working Days") {
                    HStack(spacing: 8) {
                        ForEach(0..<7, id: \.self) { day in
                            DayToggle(label: dayNames[day], isOn: workingDays.contains(day)) {
                                if workingDays.contains(day) { workingDays.remove(day) }
                                else { workingDays.insert(day) }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section("Description (optional)") {
                    TextField("e.g. Part-time period", text: $description)
                }
            }
            .navigationTitle("Add Schedule Period")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .disabled(isSaving || workingDays.isEmpty)
                }
            }
        }
    }

    private func save() {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        isSaving = true
        let endStr = hasEndDate ? fmt.string(from: endDate ?? startDate) : nil
        Task {
            await viewModel.createSchedulePeriod(
                startDate: fmt.string(from: startDate),
                endDate: endStr,
                workingDays: Array(workingDays).sorted(),
                description: description.isEmpty ? nil : description
            )
            await MainActor.run { dismiss() }
        }
    }
}
