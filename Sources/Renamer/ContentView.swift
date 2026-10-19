import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var files: [RenameItem] = []
    @State private var rules = RenameRules()
    @State private var lastRenamed: [RenameRecord] = []
    @State private var errorMessage: String?
    @State private var isTargeted = false

    private var items: [RenameItem] { RenameEngine.preview(items: files, rules: rules) }
    private var pendingCount: Int { items.filter { $0.changed && $0.problem == nil }.count }
    private var problemCount: Int { items.filter { $0.problem != nil }.count }

    var body: some View {
        HSplitView {
            rulesPanel
                .frame(minWidth: 280, idealWidth: 300, maxWidth: 360)
            fileList
                .frame(minWidth: 420)
        }
        .toolbar {
            ToolbarItemGroup {
                Button { addFilesWithPanel() } label: { Label("Add Files", systemImage: "plus") }
                Button { files.removeAll() } label: { Label("Clear", systemImage: "trash") }
                    .disabled(files.isEmpty)
                Button { undo() } label: { Label("Undo", systemImage: "arrow.uturn.backward") }
                    .disabled(lastRenamed.isEmpty)
                Button { rename() } label: { Label("Rename", systemImage: "checkmark.circle.fill") }
                    .disabled(pendingCount == 0 || problemCount > 0)
                    .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .alert("Couldn't rename", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: Rules

    private var rulesPanel: some View {
        Form {
            Section("Find & Replace") {
                TextField("Find", text: $rules.find)
                TextField("Replace with", text: $rules.replace)
                Toggle("Regular expression", isOn: $rules.useRegex)
                Toggle("Match case", isOn: $rules.caseSensitive)
            }
            Section("Add Text") {
                TextField("Prefix", text: $rules.prefix)
                TextField("Suffix", text: $rules.suffix)
            }
            Section("Case") {
                Picker("Name", selection: $rules.caseMode) {
                    ForEach(CaseMode.allCases) { Text($0.rawValue).tag($0) }
                }
                Toggle("Lowercase extension", isOn: $rules.lowercaseExtension)
            }
            Section("Numbering") {
                Toggle("Add sequence number", isOn: $rules.numbering)
                if rules.numbering {
                    Stepper("Start at \(rules.start)", value: $rules.start, in: 0...99999)
                    Stepper("Step \(rules.step)", value: $rules.step, in: 1...1000)
                    Stepper("Digits \(rules.padding)", value: $rules.padding, in: 1...8)
                    TextField("Separator", text: $rules.separator)
                    Picker("Position", selection: $rules.numberPosition) {
                        ForEach(NumberPosition.allCases) { Text($0.rawValue).tag($0) }
                    }
                }
            }
            Section {
                Button("Reset Rules") { rules = RenameRules() }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: File list

    private var fileList: some View {
        ZStack {
            if files.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "square.and.arrow.down.on.square")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)
                    Text("Drop files or folders here")
                        .font(.title3)
                    Text("or click Add Files")
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(spacing: 0) {
                    Table(items) {
                        TableColumn("Original") { item in
                            Text(item.originalName).lineLimit(1).truncationMode(.middle)
                        }
                        TableColumn("New Name") { item in
                            HStack(spacing: 6) {
                                Text(item.newName)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .foregroundStyle(item.problem != nil ? .red : (item.changed ? .primary : .secondary))
                                if let problem = item.problem {
                                    Text(problem).font(.caption).foregroundStyle(.red)
                                }
                            }
                        }
                    }
                    Divider()
                    HStack {
                        Text("\(files.count) item\(files.count == 1 ? "" : "s") · \(pendingCount) to rename")
                        if problemCount > 0 {
                            Text("· \(problemCount) with problems").foregroundStyle(.red)
                        }
                        Spacer()
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if isTargeted {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [8]))
                    .padding(6)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url { DispatchQueue.main.async { add([url]) } }
                }
            }
            return true
        }
    }

    // MARK: Actions

    private func add(_ urls: [URL]) {
        let existing = Set(files.map { $0.url.standardizedFileURL })
        for url in urls where !existing.contains(url.standardizedFileURL) {
            files.append(RenameItem(url: url))
        }
        lastRenamed = []
    }

    private func addFilesWithPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        if panel.runModal() == .OK { add(panel.urls) }
    }

    private func rename() {
        do {
            let records = try RenameEngine.apply(items: items)
            lastRenamed = records
            let renamed = Dictionary(uniqueKeysWithValues: records.map { ($0.from.standardizedFileURL, $0.to) })
            files = files.map { item in
                if let newURL = renamed[item.url.standardizedFileURL] { return RenameItem(url: newURL) }
                return item
            }
            rules = RenameRules()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func undo() {
        do {
            try RenameEngine.undo(lastRenamed)
            let back = Dictionary(uniqueKeysWithValues: lastRenamed.map { ($0.to.standardizedFileURL, $0.from) })
            files = files.map { item in
                if let old = back[item.url.standardizedFileURL] { return RenameItem(url: old) }
                return item
            }
            lastRenamed = []
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
