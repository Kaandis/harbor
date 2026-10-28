import AppKit
import HarborKit
import Observation

/// One app's preferences, read from and written to its own domain, shaped by
/// the schema it ships.
@MainActor
@Observable
final class AppSettings {
    let schema: SettingsSchema
    private(set) var values: [String: JSONValue] = [:]
    /// A setting that only applies at launch was changed.
    private(set) var needsRelaunch = false
    private(set) var permissions: [String: Bool] = [:]

    init(schema: SettingsSchema) {
        self.schema = schema
        reload()
    }

    var domain: String { schema.defaultsDomain }

    func reload() {
        CFPreferencesSynchronize(domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        var read: [String: JSONValue] = [:]
        for setting in schema.groups.flatMap(\.settings) {
            let stored = SettingsBridge.read(setting.key, domain: domain)
            var value = stored.map(JSONValue.init(property:)) ?? setting.default ?? .null
            if case .string(let raw) = value, let canonical = setting.aliases?[raw] { value = .string(canonical) }
            read[setting.key] = value
        }
        values = read
        permissions = SettingsBridge.permissions(domain: domain)
    }

    func value(_ setting: SettingsSchema.Setting) -> JSONValue {
        values[setting.key] ?? setting.default ?? .null
    }

    func set(_ value: JSONValue, for setting: SettingsSchema.Setting) {
        guard values[setting.key] != value else { return }
        values[setting.key] = value
        // Writing the default back is the same as having no value; keep the
        // app's preferences file clean by removing it instead.
        let stored: Any? = value == setting.default || value == .null ? nil : value.property
        SettingsBridge.write(stored, key: setting.key, domain: domain)
        SettingsBridge.notify(domain: domain)
        if setting.restartRequired == true { needsRelaunch = true }
    }

    func didRelaunch() { needsRelaunch = false }

    /// Whether a setting's `visibleWhen` conditions hold right now.
    func isVisible(_ setting: SettingsSchema.Setting) -> Bool {
        guard let conditions = setting.visibleWhen else { return true }
        return conditions.allSatisfy { key, expected in values[key] == expected }
    }

    /// Options the running macOS can use.
    func options(_ setting: SettingsSchema.Setting) -> [SettingsSchema.Option] {
        (setting.options ?? []).filter { option in
            guard let needed = option.requires?["macOS"] else { return true }
            let parts = needed.split(separator: ".").compactMap { Int($0) }
            let version = OperatingSystemVersion(majorVersion: parts.first ?? 0,
                                                 minorVersion: parts.dropFirst().first ?? 0, patchVersion: 0)
            return ProcessInfo.processInfo.isOperatingSystemAtLeast(version)
        }
    }
}
