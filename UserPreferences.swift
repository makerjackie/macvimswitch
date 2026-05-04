import Foundation

class UserPreferences {
    static let shared = UserPreferences()
    private let defaults = UserDefaults.standard

    // 键名常量
    private struct Keys {
        static let allowedApps = "allowedApps"
        static let selectedInputMethod = "selectedInputMethod"
        static let selectedEnglishInputMethod = "selectedEnglishInputMethod"
        static let useShiftSwitch = "useShiftSwitch"
        static let launchAtLogin = "launchAtLogin"
        static let useJkSwitch = "useJkSwitch"
        static let customShortcutsVersion = "customShortcutsVersion"
    }
    
    // Esc 生效的应用
    var allowedApps: Set<String> {
        get {
            let array = defaults.array(forKey: Keys.allowedApps) as? [String] ?? []
            return Set(array)
        }
        set {
            defaults.set(Array(newValue), forKey: Keys.allowedApps)
        }
    }
    
    // 选择的中文输入法
    var selectedInputMethod: String? {
        get {
            defaults.string(forKey: Keys.selectedInputMethod)
        }
        set {
            defaults.set(newValue, forKey: Keys.selectedInputMethod)
        }
    }
    
    // 选择的英文输入法
    var selectedEnglishInputMethod: String {
        get {
            defaults.string(forKey: Keys.selectedEnglishInputMethod) ?? "com.apple.keylayout.ABC"
        }
        set {
            defaults.set(newValue, forKey: Keys.selectedEnglishInputMethod)
        }
    }
    
    // 是否使用 shift 切换输入法（兼容旧版本）
    var useShiftSwitch: Bool {
        get {
            defaults.bool(forKey: Keys.useShiftSwitch)
        }
        set {
            defaults.set(newValue, forKey: Keys.useShiftSwitch)
            // 同步到新的快捷键系统
            CustomShortcutPreferences.shared.setEnabled(.singleShift, enabled: newValue)
        }
    }

    // 是否使用 jk 组合键切换输入法（兼容旧版本）
    var useJkSwitch: Bool {
        get {
            defaults.bool(forKey: Keys.useJkSwitch)
        }
        set {
            defaults.set(newValue, forKey: Keys.useJkSwitch)
            // 同步到新的快捷键系统
            CustomShortcutPreferences.shared.setEnabled(.jkSequence, enabled: newValue)
        }
    }

    // 是否开机启动
    var launchAtLogin: Bool {
        get {
            defaults.bool(forKey: Keys.launchAtLogin)
        }
        set {
            defaults.set(newValue, forKey: Keys.launchAtLogin)
        }
    }

    private init() {
        // 设置默认值
        if defaults.object(forKey: Keys.allowedApps) == nil {
            allowedApps = Set([
                "com.apple.Terminal",
                "com.microsoft.VSCode",
                "com.vim.MacVim",
                "com.exafunction.windsurf",
                "md.obsidian",
                "dev.warp.Warp-Stable",
                "com.todesktop.230313mzl4w4u92"
            ])
        }

        // 注意：不要在这里设置默认值，让迁移逻辑处理
        // 这样可以确保新安装的用户也能正确初始化默认快捷键

        if defaults.object(forKey: Keys.selectedEnglishInputMethod) == nil {
            selectedEnglishInputMethod = "com.apple.keylayout.ABC"
        }

        // 初始化快捷键系统
        initializeCustomShortcuts()
    }

    // 初始化自定义快捷键系统
    private func initializeCustomShortcuts() {
        let currentVersion = defaults.integer(forKey: Keys.customShortcutsVersion)

        // 如果是新安装或首次运行，迁移旧设置
        if currentVersion < 1 {
            migrateLegacySettings()
            defaults.set(1, forKey: Keys.customShortcutsVersion)
        }
    }

    // 迁移旧的快捷键设置到新系统
    private func migrateLegacySettings() {
        let customPrefs = CustomShortcutPreferences.shared

        // 检查是否已经有旧的设置需要迁移
        let hasShiftSetting = defaults.object(forKey: Keys.useShiftSwitch) != nil
        let hasJkSetting = defaults.object(forKey: "useJkSwitch") != nil

        if hasShiftSetting || hasJkSetting {
            // 迁移现有设置
            customPrefs.migrateLegacySettings()
        } else {
            // 新安装用户：设置默认值（只启用 Shift 切换）
            customPrefs.setEnabled(.singleShift, enabled: true)

            // 同时设置旧版本的默认值
            defaults.set(true, forKey: Keys.useShiftSwitch)
        }
    }

    // MARK: - 新的快捷键管理方法

    /// 获取所有启用的快捷键
    func getEnabledCustomShortcuts() -> Set<CustomShortcutType> {
        return CustomShortcutPreferences.shared.getAllEnabledShortcuts()
    }

    /// 设置启用的快捷键
    func setEnabledCustomShortcuts(_ types: Set<CustomShortcutType>) {
        CustomShortcutPreferences.shared.setEnabledShortcuts(types)

        // 刷新快捷键管理器的缓存
        CustomShortcutManager.shared.refreshCache()

        // 同步到旧的设置（向后兼容）
        defaults.set(types.contains(.singleShift), forKey: Keys.useShiftSwitch)
        defaults.set(types.contains(.jkSequence), forKey: Keys.useJkSwitch)
    }

    /// 检查特定快捷键是否启用
    func isCustomShortcutEnabled(_ type: CustomShortcutType) -> Bool {
        return CustomShortcutPreferences.shared.isEnabled(type)
    }

    /// 设置特定快捷键的启用状态
    func setCustomShortcutEnabled(_ type: CustomShortcutType, enabled: Bool) {
        CustomShortcutPreferences.shared.setEnabled(type, enabled: enabled)

        // 刷新快捷键管理器的缓存
        CustomShortcutManager.shared.refreshCache()

        // 同步到旧的设置（向后兼容）
        if type == .singleShift {
            defaults.set(enabled, forKey: Keys.useShiftSwitch)
        } else if type == .jkSequence {
            defaults.set(enabled, forKey: Keys.useJkSwitch)
        }
    }
}
