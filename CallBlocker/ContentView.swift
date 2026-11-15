import SwiftUI
import CallKit

/// Bundle ID of the embedded Call Directory extension. Read from the bundle
/// because sideloading tools rewrite bundle identifiers when re-signing.
private let extensionBundleID: String = {
    if let dir = Bundle.main.builtInPlugInsURL,
       let items = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
        for item in items where item.pathExtension == "appex" {
            if let id = Bundle(url: item)?.bundleIdentifier { return id }
        }
    }
    return (Bundle.main.bundleIdentifier ?? "com.callblocker.app") + ".BlockerExtension"
}()

struct ContentView: View {
    @State private var rules: [Rule] = RuleStore.load()
    @State private var showingAdd = false
    @State private var status: String = ""
    @State private var extState: String = "Unknown"

    var totalBlocked: Int {
        RuleExpander.totalCount(rules)
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Text("Total numbers blocked")
                        Spacer()
                        Text("\(totalBlocked)").foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Extension status")
                        Spacer()
                        Text(extState).foregroundColor(.secondary)
                    }
                }
                if totalBlocked > RuleExpander.recommendedTotal {
                    Section {
                        Text("iOS limits how many numbers one blocker can hold (about 2 million). The reload may fail with this many.")
                            .font(.caption).foregroundColor(.orange)
                    }
                }
                if !RuleStore.isShared {
                    Section {
                        Text("Shared storage (App Group) is unavailable, so the blocker extension cannot see your rules. Re-install the app with App Groups kept enabled in your signing tool.")
                            .font(.caption).foregroundColor(.red)
                    }
                }
                Section(header: Text("Rules")) {
                    if rules.isEmpty {
                        Text("Tap + to add a number or pattern").foregroundColor(.secondary)
                    }
                    ForEach($rules) { $rule in
                        HStack {
                            Toggle("", isOn: $rule.enabled).labelsHidden()
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rule.pattern).font(.body.monospaced())
                                if !rule.label.isEmpty {
                                    Text(rule.label).font(.caption).foregroundColor(.secondary)
                                }
                                Text("\(RuleExpander.count(rule.pattern)) numbers")
                                    .font(.caption2).foregroundColor(.secondary)
                            }
                        }
                    }
                    .onDelete { rules.remove(atOffsets: $0) }
                }
                Section {
                    Button("Reload Blocker Extension") { reload() }
                    if !status.isEmpty {
                        Text(status).font(.caption).foregroundColor(.secondary)
                    }
                }
                Section(header: Text("Setup")) {
                    Text("Enable in: Settings → Phone → Call Blocking & Identification → CallBlocker")
                        .font(.caption)
                }
            }
            .navigationTitle("CallBlocker")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAdd = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddRuleView { rule in
                    rules.append(rule)
                }
            }
            .onChange(of: rules) { _ in
                RuleStore.save(rules)
            }
            .onAppear { checkStatus() }
        }
    }

    func reload() {
        RuleStore.save(rules)
        CXCallDirectoryManager.sharedInstance.reloadExtension(withIdentifier: extensionBundleID) { error in
            DispatchQueue.main.async {
                if let error = error {
                    status = "Error: \(error.localizedDescription)"
                } else {
                    let t = Date().formatted(date: .omitted, time: .standard)
                    status = "Reloaded at \(t) (\(totalBlocked) numbers)"
                }
                checkStatus()
            }
        }
    }

    func checkStatus() {
        CXCallDirectoryManager.sharedInstance.getEnabledStatusForExtension(withIdentifier: extensionBundleID) { s, _ in
            DispatchQueue.main.async {
                switch s {
                case .enabled: extState = "Enabled"
                case .disabled: extState = "Disabled (enable in Settings)"
                case .unknown: extState = "Unknown"
                @unknown default: extState = "Unknown"
                }
            }
        }
    }
}

struct AddRuleView: View {
    @Environment(\.dismiss) var dismiss
    @State private var pattern = ""
    @State private var label = ""
    var onAdd: (Rule) -> Void

    var expansion: Int {
        RuleExpander.count(pattern)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Pattern")) {
                    TextField("e.g. 919876543210 or 91987654xxxx", text: $pattern)
                        .keyboardType(.phonePad)
                        .font(.body.monospaced())
                        .autocorrectionDisabled()
                    Text("Digits + wildcards (x, ?, *). Include country code. Up to 6 wildcards (1,000,000 numbers) per rule.")
                        .font(.caption).foregroundColor(.secondary)
                    if !pattern.isEmpty {
                        Text(expansion == 0
                             ? "Invalid or too large (>1M numbers)"
                             : "Will block \(expansion) number\(expansion == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(expansion == 0 ? .red : .green)
                    }
                }
                Section(header: Text("Label (optional)")) {
                    TextField("e.g. Spam callers", text: $label)
                }
            }
            .navigationTitle("Add Rule")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(Rule(pattern: pattern, label: label))
                        dismiss()
                    }
                    .disabled(expansion == 0)
                }
            }
        }
    }
}
