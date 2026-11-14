import SwiftUI
import Combine
import WatchConnectivity

struct FlowTask: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var detail: String
    var isComplete: Bool

    init(id: UUID = UUID(), title: String, detail: String, isComplete: Bool = false) {
        self.id = id
        self.title = title
        self.detail = detail
        self.isComplete = isComplete
    }
}

@MainActor
final class FlowStore: ObservableObject {
    @Published var tasks: [FlowTask] { didSet { saveAndSync() } }
    @Published var notes: [String] = ["Keep the morning clear for deep work."]
    @Published var isStandModePresented = false

    private let storageKey = "duoflow.tasks.v1"
    private var session: WCSession?
    private var bridge: WatchBridge?

    init() {
        if let data = UserDefaults.standard.data(forKey: "duoflow.tasks.v1"),
           let stored = try? JSONDecoder().decode([FlowTask].self, from: data) {
            tasks = stored
        } else {
            tasks = [
                FlowTask(title: "Review today’s priorities", detail: "Today · Personal"),
                FlowTask(title: "Send project update", detail: "Today · Work"),
                FlowTask(title: "Plan the weekend", detail: "Tomorrow · Personal")
            ]
        }
        configureWatchConnectivity()
    }

    func addTask(_ title: String) {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        tasks.insert(FlowTask(title: clean, detail: "Just added · Personal"), at: 0)
    }

    func toggle(_ task: FlowTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].isComplete.toggle()
    }

    private func saveAndSync() {
        guard let data = try? JSONEncoder().encode(tasks) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
        sendSnapshot()
    }

    private func configureWatchConnectivity() {
        guard WCSession.isSupported() else { return }
        let bridge = WCSession.default
        let delegate = WatchBridge(store: self)
        bridge.delegate = delegate
        session = bridge
        self.bridge = delegate
        bridge.activate()
    }

    private func sendSnapshot() {
        guard let session, session.activationState == .activated,
              let data = try? JSONEncoder().encode(tasks) else { return }
        try? session.updateApplicationContext(["tasks": data])
    }

    fileprivate func handleWatchMessage(_ message: [String: Any]) {
        if let taskID = message["completeTask"] as? String,
           let id = UUID(uuidString: taskID),
           let task = tasks.first(where: { $0.id == id }) {
            toggle(task)
        }
        if let note = message["quickNote"] as? String {
            let clean = note.trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty { notes.insert(clean, at: 0) }
        }
    }
}

private final class WatchBridge: NSObject, WCSessionDelegate {
    weak var store: FlowStore?
    init(store: FlowStore) { self.store = store }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        Task { @MainActor in store?.sendInitialSnapshot() }
    }
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in store?.handleWatchMessage(message) }
    }
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor in store?.handleWatchMessage(userInfo) }
    }
}

private extension FlowStore {
    fileprivate func sendInitialSnapshot() { sendSnapshot() }
}

@main
struct DuoFlowApp: App {
    @StateObject private var store = FlowStore()
    var body: some Scene {
        WindowGroup { RootView().environmentObject(store).preferredColorScheme(.dark) }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            DashboardView().tabItem { Label("Today", systemImage: "square.grid.2x2.fill") }
            TaskListView().tabItem { Label("Tasks", systemImage: "checklist") }
            NotesView().tabItem { Label("Notes", systemImage: "note.text") }
        }
        .tint(Color.duoPurple)
    }
}

struct DashboardView: View {
    @EnvironmentObject private var store: FlowStore
    @State private var isStandMode = false
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        return hour < 12 ? "Good morning" : (hour < 18 ? "Good afternoon" : "Good evening")
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    if proxy.size.width >= 700 {
                        HStack(alignment: .top, spacing: 16) {
                            VStack(spacing: 16) { clockCard; agendaCard; taskPreview }
                            VStack(spacing: 16) { weatherCard; noteCard; standButton }
                        }
                    } else {
                        clockCard; weatherCard; agendaCard; taskPreview; noteCard; standButton
                    }
                }
                .padding(.horizontal, proxy.size.width >= 700 ? 28 : 20)
                .padding(.top, 20)
                .padding(.bottom, 30)
                .frame(maxWidth: 1080)
                .frame(maxWidth: .infinity)
            }
            .background(Color.duoBackground.ignoresSafeArea())
        }
        .fullScreenCover(isPresented: $isStandMode) { StandModeView() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting).font(.system(size: 15, weight: .medium)).foregroundStyle(.secondary)
                Text("Your day, in flow.").font(.system(size: 27, weight: .bold, design: .rounded))
            }
            Spacer()
            Image(systemName: "sparkle").font(.title2.weight(.semibold)).foregroundStyle(Color.duoPurple)
                .frame(width: 46, height: 46).background(Color.duoSurface, in: Circle())
        }
    }
    private var clockCard: some View {
        DuoCard {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Date.now.formatted(date: .complete, time: .omitted)).font(.subheadline).foregroundStyle(.secondary)
                    Text(Date.now.formatted(date: .omitted, time: .shortened)).font(.system(size: 48, weight: .light, design: .rounded)).monospacedDigit()
                }
                Spacer()
                Image(systemName: "sun.max.fill").font(.system(size: 26)).foregroundStyle(.yellow)
            }
        }
    }
    private var weatherCard: some View {
        DuoCard {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Weather preview", systemImage: "cloud.sun.fill").font(.headline)
                    Text("WeatherKit connection coming next").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("—°").font(.system(size: 32, weight: .light, design: .rounded)).foregroundStyle(.secondary)
            }
        }
    }
    private var agendaCard: some View {
        DuoCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("Next up", icon: "calendar")
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.duoBlue).frame(width: 4, height: 42)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Focus block").font(.subheadline.weight(.semibold))
                        Text("Sample agenda · connect Calendar in a later step").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Text("10:00").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
        }
    }
    private var taskPreview: some View {
        DuoCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("Priority tasks", icon: "checkmark.circle")
                ForEach(store.tasks.filter { !$0.isComplete }.prefix(2)) { task in
                    Button { store.toggle(task) } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "circle").foregroundStyle(Color.duoPurple)
                            Text(task.title).font(.subheadline).foregroundStyle(.primary).lineLimit(1)
                            Spacer()
                        }
                    }.buttonStyle(.plain)
                }
                if store.tasks.allSatisfy(\.isComplete) { Text("You’re all caught up.").font(.subheadline).foregroundStyle(.secondary) }
            }
        }
    }
    private var noteCard: some View {
        DuoCard {
            VStack(alignment: .leading, spacing: 8) {
                sectionTitle("Quick note", icon: "note.text")
                Text(store.notes.first ?? "Capture a thought when it arrives.").font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
            }
        }
    }
    private var standButton: some View {
        Button { isStandMode = true } label: {
            Label("Open Stand Mode", systemImage: "rectangle.portrait.and.arrow.right")
                .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(LinearGradient(colors: [Color.duoPurple, Color.duoBlue], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(.plain)
    }
    private func sectionTitle(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon).font(.headline).foregroundStyle(.primary)
    }
}

struct TaskListView: View {
    @EnvironmentObject private var store: FlowStore
    @State private var draft = ""
    var body: some View {
        NavigationStack {
            List {
                Section("Add a task") {
                    HStack {
                        TextField("What needs doing?", text: $draft).onSubmit(add)
                        Button(action: add) { Image(systemName: "plus.circle.fill") }.disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                Section("Your list") {
                    ForEach(store.tasks) { task in
                        Button { store.toggle(task) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: task.isComplete ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(task.isComplete ? Color.duoBlue : Color.duoPurple)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(task.title).strikethrough(task.isComplete).foregroundStyle(.primary)
                                    Text(task.detail).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }.buttonStyle(.plain)
                    }.onDelete { store.tasks.remove(atOffsets: $0) }
                }
            }
            .scrollContentBackground(.hidden).background(Color.duoBackground)
            .navigationTitle("Tasks").toolbar { EditButton() }
        }
    }
    private func add() { store.addTask(draft); draft = "" }
}

struct NotesView: View {
    @EnvironmentObject private var store: FlowStore
    @State private var draft = ""
    var body: some View {
        NavigationStack {
            List {
                Section("Capture") {
                    TextField("Write a quick note…", text: $draft, axis: .vertical)
                    Button("Save note", systemImage: "plus") {
                        let value = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !value.isEmpty { store.notes.insert(value, at: 0); draft = "" }
                    }.disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Section("Recent") { ForEach(Array(store.notes.enumerated()), id: \.offset) { _, note in Text(note).padding(.vertical, 4) } }
            }
            .scrollContentBackground(.hidden).background(Color.duoBackground)
            .navigationTitle("Notes")
        }
    }
}

struct StandModeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: FlowStore
    var body: some View {
        ZStack {
            Color.duoBackground.ignoresSafeArea()
            GeometryReader { proxy in
                VStack(alignment: .leading, spacing: 24) {
                    HStack { Text("DUOFLOW").font(.caption.weight(.bold)).tracking(2).foregroundStyle(Color.duoPurple); Spacer(); Button("Done") { dismiss() }.foregroundStyle(.secondary) }
                    Text(Date.now.formatted(date: .complete, time: .omitted)).font(.title3).foregroundStyle(.secondary)
                    Text(Date.now.formatted(date: .omitted, time: .shortened)).font(.system(size: min(proxy.size.width * 0.17, 100), weight: .ultraLight, design: .rounded)).monospacedDigit().minimumScaleFactor(0.6)
                    HStack(spacing: 14) {
                        standTile(title: "NEXT", value: "Focus block", detail: "Sample agenda", icon: "calendar")
                        standTile(title: "WEATHER", value: "Preview", detail: "Connect WeatherKit later", icon: "cloud.sun")
                    }
                    DuoCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("UP NEXT").font(.caption.weight(.bold)).tracking(1.4).foregroundStyle(.secondary)
                            ForEach(store.tasks.filter { !$0.isComplete }.prefix(3)) { task in
                                HStack { Image(systemName: "circle").foregroundStyle(Color.duoPurple); Text(task.title).font(.subheadline); Spacer() }
                            }
                        }
                    }
                    Spacer(minLength: 0)
                    Text("Stand Mode stays on while open. This preview does not detect device posture.").font(.caption).foregroundStyle(.tertiary)
                }
                .padding(28).frame(maxWidth: 1000).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .statusBarHidden()
    }
    private func standTile(title: String, value: String, detail: String, icon: String) -> some View {
        DuoCard {
            VStack(alignment: .leading, spacing: 10) {
                Label(title, systemImage: icon).font(.caption.weight(.bold)).tracking(1).foregroundStyle(.secondary)
                Text(value).font(.headline)
                Text(detail).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct DuoCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.duoSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.06), lineWidth: 1))
    }
}

private extension Color {
    static let duoBackground = Color(red: 11/255, green: 13/255, blue: 18/255)
    static let duoSurface = Color(red: 23/255, green: 26/255, blue: 35/255)
    static let duoPurple = Color(red: 148/255, green: 117/255, blue: 1)
    static let duoBlue = Color(red: 120/255, green: 169/255, blue: 1)
}
