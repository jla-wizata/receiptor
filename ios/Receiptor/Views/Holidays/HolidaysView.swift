import SwiftUI

struct HolidaysView: View {
    @State private var viewModel = HolidaysViewModel()
    @State private var showAddHoliday = false
    @State private var showAddSchedule = false
    @State private var holidayToEdit: UserHoliday? = nil
    @State private var periodToEdit: WorkSchedulePeriod? = nil
    @State private var showPublicHolidays = false

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
                ToolbarItem(placement: .topBarLeading) {
                    yearPicker
                }
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
            .onChange(of: viewModel.year) { Task { await viewModel.load() } }
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

    private var yearPicker: some View {
        HStack(spacing: 4) {
            Button { viewModel.year -= 1 } label: {
                Image(systemName: "chevron.left").imageScale(.small)
            }
            Text(String(viewModel.year))
                .font(.headline).monospacedDigit().frame(minWidth: 48)
            Button { viewModel.year += 1 } label: {
                Image(systemName: "chevron.right").imageScale(.small)
            }
        }
        .buttonStyle(.borderless)
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

            Section {
                DisclosureGroup(
                    isExpanded: $showPublicHolidays,
                    content: {
                        if viewModel.publicHolidays.isEmpty {
                            Text("No public holidays found")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        } else {
                            ForEach(viewModel.publicHolidays) { holiday in
                                PublicHolidayRow(holiday: holiday)
                            }
                        }
                    },
                    label: {
                        Text("Public Holidays (\(String(viewModel.year)))")
                            .font(.headline)
                    }
                )
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

// MARK: - Public Holiday Row

struct PublicHolidayRow: View {
    let holiday: PublicHoliday

    private var displayDate: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        guard let date = fmt.date(from: holiday.date) else { return holiday.date }
        let out = DateFormatter()
        out.dateFormat = "EEE, MMM d"
        return out.string(from: date)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(holiday.name).font(.body)
                Text(holiday.localName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text(displayDate)
                .font(.caption)
                .foregroundColor(.secondary)
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
    @State private var showStartPicker = false
    @State private var showEndPicker = false

    private static let fmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()
    private let displayFmt: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; return f
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
                    Button { showStartPicker = true } label: {
                        HStack {
                            Text("Start Date").foregroundColor(.primary)
                            Spacer()
                            Text(displayFmt.string(from: startDate)).foregroundColor(.secondary)
                        }
                    }
                    Button { showEndPicker = true } label: {
                        HStack {
                            Text("End Date").foregroundColor(.primary)
                            Spacer()
                            Text(displayFmt.string(from: endDate)).foregroundColor(.secondary)
                        }
                    }
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
            .sheet(isPresented: $showStartPicker) {
                DatePickerSheet(title: "Start Date", date: $startDate)
            }
            .sheet(isPresented: $showEndPicker) {
                DatePickerSheet(title: "End Date", date: $endDate, min: startDate)
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
    @State private var showStartPicker = false
    @State private var showEndPicker = false

    private static let fmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()
    private let displayFmt: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; return f
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
                    Button { showStartPicker = true } label: {
                        HStack {
                            Text("Start Date").foregroundColor(.primary)
                            Spacer()
                            Text(displayFmt.string(from: startDate)).foregroundColor(.secondary)
                        }
                    }
                    Toggle("Has end date", isOn: $hasEndDate)
                    if hasEndDate {
                        Button { showEndPicker = true } label: {
                            HStack {
                                Text("End Date").foregroundColor(.primary)
                                Spacer()
                                Text(displayFmt.string(from: endDate ?? startDate)).foregroundColor(.secondary)
                            }
                        }
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
            .sheet(isPresented: $showStartPicker) {
                DatePickerSheet(title: "Start Date", date: $startDate)
            }
            .sheet(isPresented: $showEndPicker) {
                DatePickerSheet(title: "End Date", date: Binding(
                    get: { endDate ?? startDate },
                    set: { endDate = $0 }
                ), min: startDate)
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
    @State private var showStartPicker = false
    @State private var showEndPicker = false

    private let displayFmt: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; return f
    }()

    var body: some View {
        NavigationStack {
            Form {
                Section("Date Range") {
                    Button { showStartPicker = true } label: {
                        HStack {
                            Text("Start Date").foregroundColor(.primary)
                            Spacer()
                            Text(displayFmt.string(from: startDate)).foregroundColor(.secondary)
                        }
                    }
                    Button { showEndPicker = true } label: {
                        HStack {
                            Text("End Date").foregroundColor(.primary)
                            Spacer()
                            Text(displayFmt.string(from: endDate)).foregroundColor(.secondary)
                        }
                    }
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
            .sheet(isPresented: $showStartPicker) {
                DatePickerSheet(title: "Start Date", date: $startDate)
            }
            .sheet(isPresented: $showEndPicker) {
                DatePickerSheet(title: "End Date", date: $endDate, min: startDate)
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
    @State private var showStartPicker = false
    @State private var showEndPicker = false

    private let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    private let displayFmt: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; return f
    }()

    var body: some View {
        NavigationStack {
            Form {
                Section("Date Range") {
                    Button { showStartPicker = true } label: {
                        HStack {
                            Text("Start Date").foregroundColor(.primary)
                            Spacer()
                            Text(displayFmt.string(from: startDate)).foregroundColor(.secondary)
                        }
                    }
                    Toggle("Has end date", isOn: $hasEndDate)
                    if hasEndDate {
                        Button { showEndPicker = true } label: {
                            HStack {
                                Text("End Date").foregroundColor(.primary)
                                Spacer()
                                Text(displayFmt.string(from: endDate ?? startDate)).foregroundColor(.secondary)
                            }
                        }
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
            .sheet(isPresented: $showStartPicker) {
                DatePickerSheet(title: "Start Date", date: $startDate)
            }
            .sheet(isPresented: $showEndPicker) {
                DatePickerSheet(title: "End Date", date: Binding(
                    get: { endDate ?? startDate },
                    set: { endDate = $0 }
                ), min: startDate)
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
