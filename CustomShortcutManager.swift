import Foundation
import Carbon

// MARK: - 快捷键类型定义
enum CustomShortcutType: String, CaseIterable, Identifiable {
    case capsLock = "capsLock"
    case ctrlOpenBracket = "ctrlOpenBracket"
    case commandSpace = "commandSpace"
    case doubleJ = "doubleJ"
    case doubleK = "doubleK"
    case jkSequence = "jkSequence"
    case singleShift = "singleShift"
    case fnQ = "fnQ"
    case fnH = "fnH"
    case fnJ = "fnJ"

    var id: String { rawValue }

    // 显示名称
    var displayName: String {
        switch self {
        case .capsLock: return "CapsLock → ESC"
        case .ctrlOpenBracket: return "Ctrl+[ → ESC"
        case .commandSpace: return "Command+Space → ESC"
        case .doubleJ: return "双击 J → ESC"
        case .doubleK: return "双击 K → ESC"
        case .jkSequence: return "JK 序列 → ESC"
        case .singleShift: return "单击 Shift → ESC"
        case .fnQ: return "Fn+Q → ESC"
        case .fnH: return "Fn+H → ESC"
        case .fnJ: return "Fn+J → ESC"
        }
    }

    // 描述信息
    var description: String {
        switch self {
        case .capsLock: return "将 CapsLock 键映射为 ESC (最流行)"
        case .ctrlOpenBracket: return "使用 Ctrl+[ 替代 ESC (Vim 原生)"
        case .commandSpace: return "Command+Space 组合键切换到英文"
        case .doubleJ: return "快速按两次 J 键切换到英文"
        case .doubleK: return "快速按两次 K 键切换到英文"
        case .jkSequence: return "依次按 J 和 K 键切换到英文"
        case .singleShift: return "单独按 Shift 键切换到英文"
        case .fnQ: return "Fn+Q 组合键切换到英文"
        case .fnH: return "Fn+H 组合键切换到英文"
        case .fnJ: return "Fn+J 组合键切换到英文"
        }
    }

    // 是否需要特殊处理
    var requiresSpecialHandling: Bool {
        switch self {
        case .capsLock:
            return true // 需要系统级权限或特殊处理
        case .commandSpace, .fnQ, .fnH, .fnJ:
            return true // 涉及修饰键组合
        case .ctrlOpenBracket, .doubleJ, .doubleK, .jkSequence, .singleShift:
            return false // 普通按键处理
        }
    }
}

// MARK: - 快捷键配置结构
struct ShortcutConfig {
    let type: CustomShortcutType
    let enabled: Bool
    let keyCode: Int64?
    let modifiers: CGEventFlags?
    let sequence: [String]? // 用于序列按键

    init(type: CustomShortcutType, enabled: Bool = false) {
        self.type = type
        self.enabled = enabled

        // 根据类型设置键码和修饰键
        switch type {
        case .capsLock:
            keyCode = 0x39 // CapsLock 键码
            modifiers = nil
        case .ctrlOpenBracket:
            keyCode = 0x21 // [ 键码
            modifiers = .maskControl
        case .commandSpace:
            keyCode = 0x31 // 空格键键码
            modifiers = .maskCommand
        case .doubleJ, .jkSequence:
            keyCode = 0x26 // J 键码
            modifiers = nil
        case .doubleK:
            keyCode = 0x28 // K 键码
            modifiers = nil
        case .singleShift:
            keyCode = nil // Shift 是修饰键，特殊处理
            modifiers = .maskShift
        case .fnQ:
            keyCode = 0x0C // Q 键码
            modifiers = .maskSecondaryFn
        case .fnH:
            keyCode = 0x23 // H 键码
            modifiers = .maskSecondaryFn
        case .fnJ:
            keyCode = 0x26 // J 键码
            modifiers = .maskSecondaryFn
        }

        // 设置按键序列
        switch type {
        case .jkSequence:
            sequence = ["j", "k"]
        default:
            sequence = nil
        }
    }
}

// MARK: - 快捷键管理器协议
protocol ShortcutManagerDelegate: AnyObject {
    func shortcutManagerDidTriggerAction(_ type: CustomShortcutType)
}

// MARK: - 快捷键管理器
class CustomShortcutManager {
    static let shared = CustomShortcutManager()
    weak var delegate: ShortcutManagerDelegate?

    // MARK: - 状态跟踪
    private var shortcutStates: [CustomShortcutType: Any] = [:]
    private var lastKeyPressTime: [CustomShortcutType: TimeInterval] = [:]

    // 缓存启用的快捷键，避免每次都查询
    private var cachedEnabledShortcuts: Set<CustomShortcutType> = []
    private var lastPreferencesUpdate: TimeInterval = 0

    // 时间窗口配置
    private static let DOUBLE_CLICK_WINDOW: TimeInterval = 0.3
    private static let DEBOUNCE_DELAY: TimeInterval = 0.05

    private init() {
        updateCachedShortcuts()
    }

    // MARK: - 公共方法

    /// 更新缓存的快捷键设置
    private func updateCachedShortcuts() {
        cachedEnabledShortcuts = CustomShortcutPreferences.shared.getAllEnabledShortcuts()
        lastPreferencesUpdate = Date().timeIntervalSince1970
    }

    /// 处理键盘事件
    func handleKeyEvent(keyCode: Int64, flags: CGEventFlags, isKeyDown: Bool) -> CustomShortcutType? {
        // 如果没有启用任何快捷键，直接返回
        if cachedEnabledShortcuts.isEmpty {
            return nil
        }

        let currentTime = Date().timeIntervalSince1970

        // 每5秒更新一次缓存，确保设置变化能及时生效
        if currentTime - lastPreferencesUpdate > 5.0 {
            updateCachedShortcuts()
        }

        // 只遍历启用的快捷键
        for type in cachedEnabledShortcuts {
            if let matchedType = processShortcut(type: type, keyCode: keyCode, flags: flags, isKeyDown: isKeyDown, currentTime: currentTime) {
                print("🎯 CustomShortcutManager: 匹配到快捷键 \(matchedType.displayName)")
                return matchedType
            }
        }

        return nil
    }

    /// 处理修饰键变化
    func handleModifierChange(flags: CGEventFlags, previousFlags: CGEventFlags) -> CustomShortcutType? {
        // 如果没有启用任何快捷键，直接返回
        if cachedEnabledShortcuts.isEmpty {
            return nil
        }

        let currentTime = Date().timeIntervalSince1970

        // 只遍历启用的快捷键
        for type in cachedEnabledShortcuts {
            if let matchedType = processModifierShortcut(type: type, currentFlags: flags, previousFlags: previousFlags, currentTime: currentTime) {
                return matchedType
            }
        }

        return nil
    }

    /// 重置状态（用于清理）
    func resetStates() {
        shortcutStates.removeAll()
        lastKeyPressTime.removeAll()
        updateCachedShortcuts()
    }

    /// 手动刷新缓存（当设置更改时调用）
    func refreshCache() {
        updateCachedShortcuts()
    }

    // MARK: - 私有方法

    private func processShortcut(type: CustomShortcutType, keyCode: Int64, flags: CGEventFlags, isKeyDown: Bool, currentTime: TimeInterval) -> CustomShortcutType? {
        guard isKeyDown else { return nil } // 只处理按键按下事件

        switch type {
        case .capsLock:
            return processCapsLock(keyCode: keyCode, currentTime: currentTime)

        case .ctrlOpenBracket:
            return processCtrlOpenBracket(keyCode: keyCode, flags: flags, currentTime: currentTime)

        case .commandSpace:
            return processCommandSpace(keyCode: keyCode, flags: flags, currentTime: currentTime)

        case .doubleJ:
            return processDoubleClick(type: type, keyCode: keyCode, currentTime: currentTime)

        case .doubleK:
            return processDoubleClick(type: type, keyCode: keyCode, currentTime: currentTime)

        case .jkSequence:
            // JK 序列复用 KeyboardManager 里的时间窗口逻辑，避免两套缓冲状态互相干扰。
            return nil

        case .fnQ, .fnH, .fnJ:
            return processFnCombo(type: type, keyCode: keyCode, flags: flags, currentTime: currentTime)

        case .singleShift:
            // 单击 Shift 使用 KeyboardManager 里的按下时长和组合键判断。
            return nil
        }
    }

    private func processModifierShortcut(type: CustomShortcutType, currentFlags: CGEventFlags, previousFlags: CGEventFlags, currentTime: TimeInterval) -> CustomShortcutType? {
        switch type {
        case .singleShift:
            // 单击 Shift 需要记录按下时长和期间是否输入过其他键，交给 KeyboardManager 的旧逻辑处理。
            return nil

        case .commandSpace:
            // Command+Space 需要同时检测 Command 和 Space
            return processCommandSpaceModifier(currentFlags: currentFlags, previousFlags: previousFlags, currentTime: currentTime)

        default:
            return nil
        }
    }

    // MARK: - 具体快捷键处理方法

    private func processCapsLock(keyCode: Int64, currentTime: TimeInterval) -> CustomShortcutType? {
        // CapsLock 键码是 0x39
        if keyCode == 0x39 {
            return .capsLock
        }
        return nil
    }

    private func processCtrlOpenBracket(keyCode: Int64, flags: CGEventFlags, currentTime: TimeInterval) -> CustomShortcutType? {
        // [ 键码是 0x21，需要 Control 修饰键
        if keyCode == 0x21 && flags.contains(.maskControl) && !flags.contains(.maskCommand) && !flags.contains(.maskAlternate) {
            return .ctrlOpenBracket
        }
        return nil
    }

    private func processCommandSpace(keyCode: Int64, flags: CGEventFlags, currentTime: TimeInterval) -> CustomShortcutType? {
        // 空格键码是 0x31，需要 Command 修饰键
        if keyCode == 0x31 && flags.contains(.maskCommand) && !flags.contains(.maskControl) && !flags.contains(.maskAlternate) {
            return .commandSpace
        }
        return nil
    }

    private func processCommandSpaceModifier(currentFlags: CGEventFlags, previousFlags: CGEventFlags, currentTime: TimeInterval) -> CustomShortcutType? {
        // 检测 Command+Space 的释放
        let hadCommand = previousFlags.contains(.maskCommand)
        let hasCommand = currentFlags.contains(.maskCommand)

        // Command 键释放时检查是否按了 Space
        if hadCommand && !hasCommand {
            // 这里需要结合实际的按键事件来判断
            // 简化实现：在 handleKeyEvent 中已经处理了
        }

        return nil
    }

    private func processDoubleClick(type: CustomShortcutType, keyCode: Int64, currentTime: TimeInterval) -> CustomShortcutType? {
        let targetKeyCode: Int64
        switch type {
        case .doubleJ: targetKeyCode = 0x26 // J
        case .doubleK: targetKeyCode = 0x28 // K
        default: return nil
        }

        if keyCode == targetKeyCode {
            let lastTime = lastKeyPressTime[type] ?? 0
            let timeDiff = currentTime - lastTime

            if timeDiff < CustomShortcutManager.DOUBLE_CLICK_WINDOW {
                lastKeyPressTime[type] = nil // 重置
                return type
            }

            lastKeyPressTime[type] = currentTime
        }

        return nil
    }

    private func processFnCombo(type: CustomShortcutType, keyCode: Int64, flags: CGEventFlags, currentTime: TimeInterval) -> CustomShortcutType? {
        let targetKeyCode: Int64
        switch type {
        case .fnQ: targetKeyCode = 0x0C // Q
        case .fnH: targetKeyCode = 0x23 // H
        case .fnJ: targetKeyCode = 0x26 // J
        default: return nil
        }

        if keyCode == targetKeyCode && flags.contains(.maskSecondaryFn) {
            return type
        }

        return nil
    }
}

// MARK: - 快捷键偏好设置
class CustomShortcutPreferences {
    static let shared = CustomShortcutPreferences()

    private let defaults = UserDefaults.standard
    private let prefix = "customShortcut_"

    private init() {}

    func isEnabled(_ type: CustomShortcutType) -> Bool {
        return defaults.bool(forKey: "\(prefix)enabled_\(type.rawValue)")
    }

    func setEnabled(_ type: CustomShortcutType, enabled: Bool) {
        defaults.set(enabled, forKey: "\(prefix)enabled_\(type.rawValue)")
    }

    func getAllEnabledShortcuts() -> Set<CustomShortcutType> {
        return Set(CustomShortcutType.allCases.filter { isEnabled($0) })
    }

    func setEnabledShortcuts(_ types: Set<CustomShortcutType>) {
        // 先禁用所有
        for type in CustomShortcutType.allCases {
            setEnabled(type, enabled: false)
        }
        // 启用指定的
        for type in types {
            setEnabled(type, enabled: true)
        }
    }

    // 迁移现有的设置
    func migrateLegacySettings() {
        let defaults = UserDefaults.standard

        // 迁移 useShiftSwitch
        if defaults.object(forKey: "useShiftSwitch") != nil {
            let useShiftSwitch = defaults.bool(forKey: "useShiftSwitch")
            setEnabled(.singleShift, enabled: useShiftSwitch)
        }

        // 迁移 useJkSwitch
        if defaults.object(forKey: "useJkSwitch") != nil {
            let useJkSwitch = defaults.bool(forKey: "useJkSwitch")
            setEnabled(.jkSequence, enabled: useJkSwitch)
        }
    }
}
