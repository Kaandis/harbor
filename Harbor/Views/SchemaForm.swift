import AppKit
import HarborKit
import SwiftUI
import UniformTypeIdentifiers

/// Draws an app's settings from the schema it ships: a switch for a bool, a
/// segmented control or menu for a choice, a slider for a number, a list for
/// apps. Each change is written to the app at once.
struct SchemaForm: View {
    var settings: AppSettings
    let language: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ForEach(settings.schema.groups) { group in
                VStack(alignment: .leading, spacing: 0) {
                    Text(group.title.localized(language).uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(Theme.ink3)
                        .padding(.bottom, 6)
                    ForEach(group.settings.filter(settings.isVisible)) { setting in
                        Row(setting: setting, settings: settings, language: language)
                            .transition(.opacity)
                        if setting.key != group.settings.filter(settings.isVisible).last?.key {
                            Divider().overlay(Theme.hairline)
                        }
                    }
                }
            }
        }
        .animation(reduceMotion ? nil : .harborPresent, value: settings.values)
    }
}

private struct Row: View {
    let setting: SettingsSchema.Setting
    var settings: AppSettings
    let language: String

    var body: some View {
        let wide = setting.type == .appList
        Group {
            if wide {
                VStack(alignment: .leading, spacing: 10) {
                    labels
                    control
                }
            } else {
                HStack(alignment: .center, spacing: 16) {
                    labels
                    Spacer(minLength: 12)
                    control
                }
            }
        }
        .padding(.vertical, 11)
    }

    private var labels: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(setting.title.localized(language))
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(Theme.ink)
            if let description = setting.description {
                Text(description.localized(language))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var control: some View {
        let value = settings.value(setting)
        switch setting.type {
        case .bool:
            Toggle("", isOn: Binding(get: { value == .bool(true) }, set: { settings.set(.bool($0), for: setting) }))
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
        case .enum where setting.key == "accentColor":
            // Highlight colours read best as the colours themselves.
            AccentPicker(selection: Binding(get: { value.description }, set: { settings.set(.string($0), for: setting) }))
        case .enum, .language:
            let options = settings.options(setting)
            let binding = Binding(get: { value.description }, set: { picked in
                if let option = options.first(where: { $0.value.description == picked }) {
                    settings.set(option.value, for: setting)
                }
            })
            if options.count <= 3 && setting.type == .enum {
                Picker("", selection: binding) {
                    ForEach(options) { Text($0.title.localized(language)).tag($0.value.description) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            } else {
                Picker("", selection: binding) {
                    ForEach(options) { Text($0.title.localized(language)).tag($0.value.description) }
                }
                .labelsHidden()
                .fixedSize()
            }
        case .number:
            let number: Double = if case .number(let n) = value { n } else { setting.min ?? 0 }
            HStack(spacing: 10) {
                Slider(value: Binding(get: { number }, set: { settings.set(.number(($0 * 100).rounded() / 100), for: setting) }),
                       in: (setting.min ?? 0)...(setting.max ?? 1), step: setting.step ?? 0.05)
                    .frame(width: 180)
                    .controlSize(.small)
                Text(format(number))
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(Theme.ink2)
                    .frame(width: 44, alignment: .trailing)
            }
        case .appList:
            AppListEditor(ids: value, set: { settings.set($0, for: setting) })
        case .string:
            TextField("", text: Binding(get: { if case .string(let s) = value { s } else { "" } },
                                        set: { settings.set(.string($0), for: setting) }))
                .frame(width: 200)
        }
    }

    private func format(_ number: Double) -> String {
        let text = number.formatted(.number.precision(.fractionLength(0...2)))
        return setting.unit == "seconds" ? "\(text) s" : text
    }
}

/// A list of apps by bundle identifier, with Add and Remove.
private struct AppListEditor: View {
    let ids: JSONValue
    let set: (JSONValue) -> Void

    private var list: [String] {
        if case .array(let values) = ids { return values.compactMap { if case .string(let s) = $0 { s } else { nil } } }
        return []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(list, id: \.self) { id in
                HStack(spacing: 8) {
                    let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)
                    Image(nsImage: url.map { NSWorkspace.shared.icon(forFile: $0.path) } ?? NSWorkspace.shared.icon(for: .application))
                        .resizable()
                        .frame(width: 20, height: 20)
                    Text(url.map { FileManager.default.displayName(atPath: $0.path) } ?? id)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Button {
                        set(.array(list.filter { $0 != id }.map(JSONValue.string)))
                    } label: {
                        Image(systemName: "minus.circle.fill").foregroundStyle(Theme.ink3)
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel(Text("Remove"))
                }
            }
            Button("Add App…", action: add)
                .buttonStyle(HarborButtonStyle(prominent: false))
                .padding(.top, 2)
        }
    }

    private func add() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        let added = panel.urls.compactMap { Bundle(url: $0)?.bundleIdentifier }
        set(.array(Array(Set(list + added)).sorted().map(JSONValue.string)))
    }
}
