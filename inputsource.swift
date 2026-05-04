import Cocoa
import Carbon
import Foundation
import ServiceManagement

// 添加 InputSource 类
class InputSource: Equatable {
    static func == (lhs: InputSource, rhs: InputSource) -> Bool {
        return lhs.id == rhs.id
    }

    let tisInputSource: TISInputSource

    var id: String {
        return tisInputSource.id
    }

    var name: String {
        return tisInputSource.name
    }

    var isCJKV: Bool {
        return tisInputSource.sourceLanguages.contains { lang in
            return lang == "ko" || lang == "ja" || lang == "vi" || lang.hasPrefix("zh")
        }
    }

    init(tisInputSource: TISInputSource) {
        self.tisInputSource = tisInputSource
    }

    @discardableResult
    func select() -> Bool {
        let currentSource = InputSourceManager.getCurrentSource()
        if currentSource.id == self.id {
            if self.isCJKV {
                usleep(InputSourceManager.cjkvSettleUSeconds)
            }
            InputSourceManager.forceRefreshInputContext()
            return InputSourceManager.waitUntilCurrentSource(id: self.id, timeoutUseconds: 80_000)
        }

        if self.isCJKV {
            return switchCJKVSource()
        } else {
            return selectWithRetry()
        }
    }

    private func selectWithRetry(maxAttempts: Int = 3) -> Bool {
        for attempt in 1...maxAttempts {
            let status = TISSelectInputSource(tisInputSource)
            if status != noErr {
                print("切换输入法失败: \(id), status=\(status), attempt=\(attempt)")
            }

            if InputSourceManager.waitUntilCurrentSource(id: self.id) {
                InputSourceManager.forceRefreshInputContext()
                return InputSourceManager.waitUntilCurrentSource(id: self.id, timeoutUseconds: 120_000)
            }

            if attempt < maxAttempts {
                usleep(InputSourceManager.retryDelayUSeconds)
            }
        }

        print("输入法切换未确认成功: \(id)")
        return false
    }

    private func switchCJKVSource() -> Bool {
        if selectWithRetry(maxAttempts: 2) {
            return true
        }

        if let nonCJKV = InputSourceManager.nonCJKVSource() {
            print("直接切换 CJKV 输入法未确认，尝试通过 \(nonCJKV.id) 中转")
            _ = TISSelectInputSource(nonCJKV.tisInputSource)
            _ = InputSourceManager.waitUntilCurrentSource(id: nonCJKV.id, timeoutUseconds: 120_000)

            for attempt in 1...3 {
                let status = TISSelectInputSource(tisInputSource)
                if status != noErr {
                    print("CJKV 中转切换失败: \(id), status=\(status), attempt=\(attempt)")
                }

                if InputSourceManager.waitUntilCurrentSource(id: self.id, timeoutUseconds: 220_000) {
                    usleep(InputSourceManager.cjkvSettleUSeconds)
                    guard InputSourceManager.getCurrentSource().id == self.id else {
                        continue
                    }

                    InputSourceManager.forceRefreshInputContext()
                    return InputSourceManager.waitUntilCurrentSource(id: self.id, timeoutUseconds: 120_000)
                }

                usleep(InputSourceManager.retryDelayUSeconds)
            }

            if InputSourceManager.getCurrentSource().id == self.id {
                InputSourceManager.forceRefreshInputContext()
                return true
            }
        }

        print("CJKV 输入法切换未确认成功: \(id)")
        return false
    }
}

// 修改 InputSourceManager 类
class InputSourceManager {
    static var inputSources: [InputSource] = []
    static var uSeconds: UInt32 = 20_000
    static var retryDelayUSeconds: UInt32 = 45_000
    static var cjkvSettleUSeconds: UInt32 = 80_000
    static var keyboardOnly: Bool = true

    static func initialize() {
        let inputSourceNSArray = TISCreateInputSourceList(nil, false)
            .takeRetainedValue() as NSArray
        var inputSourceList = inputSourceNSArray as! [TISInputSource]
        if self.keyboardOnly {
            inputSourceList = inputSourceList.filter({ $0.category == TISInputSource.Category.keyboardInputSource })
        }

        inputSources = inputSourceList.filter({ $0.isSelectable })
            .map { InputSource(tisInputSource: $0) }
    }

    static func getCurrentSource() -> InputSource {
        return InputSource(
            tisInputSource: TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        )
    }

    static func getInputSource(name: String) -> InputSource? {
        return inputSources.first(where: { $0.id == name })
    }

    static func nonCJKVSource() -> InputSource? {
        return inputSources.first(where: { !$0.isCJKV })
    }

    static func selectPrevious() {
        let shortcut = getSelectPreviousShortcut()
        if (shortcut == nil) {
            print("Shortcut to select previous input source does not exist")
            return
        }

        let src = CGEventSource(stateID: .hidSystemState)
        let key = CGKeyCode(shortcut!.0)
        let flag = CGEventFlags(rawValue: shortcut!.1)

        let down = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: true)!
        down.flags = flag
        down.post(tap: .cghidEventTap)

        let up = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: false)!
        up.post(tap: .cghidEventTap)
        usleep(uSeconds)
    }

    static func getSelectPreviousShortcut() -> (Int, UInt64)? {
        guard let dict = UserDefaults.standard.persistentDomain(forName: "com.apple.symbolichotkeys"),
              let symbolichotkeys = dict["AppleSymbolicHotKeys"] as? NSDictionary,
              let symbolichotkey = symbolichotkeys["60"] as? NSDictionary,
              (symbolichotkey["enabled"] as? NSNumber)?.intValue == 1,
              let value = symbolichotkey["value"] as? NSDictionary,
              let parameters = value["parameters"] as? NSArray else {
            return nil
        }

        return ((parameters[1] as! NSNumber).intValue,
                (parameters[2] as! NSNumber).uint64Value)
    }

    static func isCJKVSource(_ source: InputSource) -> Bool {
        return source.isCJKV
    }

    static func getSourceID(_ source: InputSource) -> String {
        return source.id
    }

    static func getNonCJKVSource() -> InputSource? {
        return nonCJKVSource()
    }

    static func waitUntilCurrentSource(
        id: String,
        timeoutUseconds: UInt32 = 180_000,
        pollIntervalUseconds: UInt32 = 10_000
    ) -> Bool {
        var waited: UInt32 = 0
        while waited <= timeoutUseconds {
            if getCurrentSource().id == id {
                return true
            }

            usleep(pollIntervalUseconds)
            waited += pollIntervalUseconds
        }

        return false
    }

    static func forceRefreshInputContext() {
        let current = TISCopyCurrentKeyboardInputSource().takeRetainedValue()

        _ = TISSelectInputSource(current)
        usleep(5_000)
        _ = TISSelectInputSource(current)
        usleep(10_000)
    }
}

// 添加 TISInputSource 扩展
extension TISInputSource {
    enum Category {
        static var keyboardInputSource: String {
            return kTISCategoryKeyboardInputSource as String
        }
    }

    private func getProperty(_ key: CFString) -> AnyObject? {
        let cfType = TISGetInputSourceProperty(self, key)
        if (cfType != nil) {
            return Unmanaged<AnyObject>.fromOpaque(cfType!).takeUnretainedValue()
        }
        return nil
    }

    var id: String {
        return getProperty(kTISPropertyInputSourceID) as! String
    }

    var name: String {
        return getProperty(kTISPropertyLocalizedName) as! String
    }

    var category: String {
        return getProperty(kTISPropertyInputSourceCategory) as! String
    }

    var isSelectable: Bool {
        return getProperty(kTISPropertyInputSourceIsSelectCapable) as! Bool
    }

    var sourceLanguages: [String] {
        return getProperty(kTISPropertyInputSourceLanguages) as! [String]
    }
}

// 添加代理协议
protocol KeyboardManagerDelegate: AnyObject {
    func keyboardManagerDidUpdateState()
    func shouldSwitchInputSource() -> Bool
}

class KeyboardManager {
    static let shared = KeyboardManager()
    weak var delegate: KeyboardManagerDelegate?  // 添加代理属性
    private var eventTap: CFMachPort?

    private enum KeyCode {
        static let esc: Int64 = 0x35
        static let j: Int64 = 0x26
        static let k: Int64 = 0x28
        static let space: Int64 = 0x31
        static let openBracket: Int64 = 0x21
        static let capsLock: Int64 = 0x39
        static let q: Int64 = 0x0C
        static let h: Int64 = 0x23
    }

    // 自定义快捷键管理器
    private let customShortcutManager = CustomShortcutManager.shared

    var englishInputSource: String {
        get { UserPreferences.shared.selectedEnglishInputMethod }
        set { UserPreferences.shared.selectedEnglishInputMethod = newValue }
    }
    var useShiftSwitch: Bool {
        get { UserPreferences.shared.useShiftSwitch }
        set {
            UserPreferences.shared.useShiftSwitch = newValue
            delegate?.keyboardManagerDidUpdateState()
        }
    }
    var useJkSwitch: Bool {
        get { UserPreferences.shared.useJkSwitch }
        set {
            UserPreferences.shared.useJkSwitch = newValue
            delegate?.keyboardManagerDidUpdateState()
        }
    }
    var lastShiftPressTime: TimeInterval = 0

    // 添加属性来跟踪上一个输入法
    private(set) var lastInputSource: String? {
        get {
            let value = UserPreferences.shared.selectedInputMethod
            print("[KeyboardManager] 获取 lastInputSource: \(value ?? "nil")")
            return value
        }
        set {
            print("[KeyboardManager] 设置 lastInputSource: \(newValue ?? "nil")")
            UserPreferences.shared.selectedInputMethod = newValue
        }
    }
    private var isShiftPressed = false
    private var lastKeyDownTime: TimeInterval = 0  // 修改变量名使其更明确
    private var isKeyDown = false  // 添加新变量跟踪是否有按键被按下

    private var keyDownTime: TimeInterval = 0  // 记录最后一次按键时间
    private var lastFlagChangeTime: TimeInterval = 0  // 记录最一次修饰键变化时

    private var keySequence: [TimeInterval] = []  // 记录按键序列的时间戳
    private var lastKeyEventTime: TimeInterval = 0  // 记录最后一次按键事件的时间
    private static let KEY_SEQUENCE_WINDOW: TimeInterval = 0.3  // 按键序列的时间窗口

    private var shiftPressStartTime: TimeInterval = 0  // 记录 Shift 下的开始时间
    private var hasOtherKeysDuringShift = false       // 记录 Shift 按下期间是否有其他键按下
    private var waitingForKAfterJ = false             // 记录是否等待 k 以组成 jk 序列
    private var lastJKeyTime: TimeInterval = 0        // 记录最近一次 j 键的时间
    private static let JK_SEQUENCE_WINDOW: TimeInterval = 0.35
    private var pendingShiftSwitchWorkItem: DispatchWorkItem?
    private var pendingShiftSwitchScheduledAt: TimeInterval = 0
    private var shouldSkipCurrentShiftRelease = false
    private static let SHIFT_DOUBLE_TAP_WINDOW: TimeInterval = 0.32
    private var suppressNextCtrlOpenBracketKeyUp = false

    private init() {
        // 从 UserPreferences 加载配置
        useShiftSwitch = UserPreferences.shared.useShiftSwitch
        useJkSwitch = UserPreferences.shared.useJkSwitch
        lastInputSource = UserPreferences.shared.selectedInputMethod
    }

    func start() {
        InputSourceManager.initialize()
        initializeInputSources()
        setupEventTap()

        // 设置自定义快捷键管理器的代理
        customShortcutManager.delegate = self

        // 检查当前输入法，如果是英文且有保存的上一个输入法，则更新 lastInputSource
        let currentSource = InputSourceManager.getCurrentSource()
        if currentSource.id == englishInputSource,
           let savedSource = UserPreferences.shared.selectedInputMethod {
            lastInputSource = savedSource
        } else if currentSource.id != englishInputSource {
            // 如果当前不是英文，就保存当前输入法
            lastInputSource = currentSource.id
            UserPreferences.shared.selectedInputMethod = currentSource.id
        }
    }

    private func initializeInputSources() {
        // 如果已经有保存的输入法设置，就不需要初始化
        if UserPreferences.shared.selectedInputMethod != nil {
            return
        }

        if let source = InputSourceManager.inputSources.first(where: { $0.id != englishInputSource && $0.isCJKV }) {
            lastInputSource = source.id
            print("Found CJKV input source: \(source.id)")
        } else {
            print("No CJKV input source found. Please select one from the menu.")
        }

        print("Initialized with input source: \(lastInputSource ?? "none")")
    }

    func setupEventTap() {
        // 修改事件掩码，添加 keyUp 事件的监听
        let eventMask = (1 << CGEventType.keyDown.rawValue) |
                       (1 << CGEventType.keyUp.rawValue) |
                       (1 << CGEventType.flagsChanged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: eventCallback,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            print("Failed to create event tap")
            exit(1)
        }

        eventTap = tap
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private let eventCallback: CGEventTapCallBack = { proxy, type, event, refcon in
        guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
        let manager = Unmanaged<KeyboardManager>.fromOpaque(refcon).takeUnretainedValue()

        switch type {
        case .keyDown:
            manager.handleKeyDown(true)

            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags

            // 首先处理自定义快捷键
            if let shortcutType = manager.customShortcutManager.handleKeyEvent(keyCode: keyCode, flags: flags, isKeyDown: true) {
                print("🎯 检测到自定义快捷键: \(shortcutType.displayName)")
                if shortcutType == .ctrlOpenBracket {
                    if manager.handleCtrlOpenBracketShortcut() {
                        return nil
                    }
                } else {
                    // 通过委托方法处理快捷键触发
                    manager.customShortcutManager.delegate?.shortcutManagerDidTriggerAction(shortcutType)
                }
            } else {
                manager.handleJkSequence(keyCode: keyCode, flags: flags)
            }

            // 处理传统 ESC 键
            if keyCode == KeyboardManager.KeyCode.esc {
                print("ESC key pressed")
                // 检查是否应该切换输入法
                if let delegate = manager.delegate,
                   delegate.shouldSwitchInputSource() {
                    manager.switchToEnglish()
                }
            }

        case .keyUp:
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            if manager.shouldSuppressCtrlOpenBracketKeyUp(keyCode: keyCode) {
                return nil
            }
            manager.handleKeyDown(false)

        case .flagsChanged:
            let flags = event.flags
            let previousFlags = manager.lastFlags

            // 处理自定义快捷键的修饰键变化
            if let shortcutType = manager.customShortcutManager.handleModifierChange(flags: flags, previousFlags: previousFlags) {
                print("🎯 检测到自定义快捷键 (修饰键): \(shortcutType.displayName)")
                // 通过委托方法处理快捷键触发
                manager.customShortcutManager.delegate?.shortcutManagerDidTriggerAction(shortcutType)
            }

            manager.handleModifierFlags(flags)

        default:
            break
        }

        // 总是让事件继续传播
        return Unmanaged.passUnretained(event)
    }

    private func handleCtrlOpenBracketShortcut() -> Bool {
        guard let delegate = delegate,
              delegate.shouldSwitchInputSource() else {
            return false
        }

        print("⌨️ Ctrl+[ 已启用，发送 ESC 并切换到英文输入法")
        switchToEnglish()
        suppressNextCtrlOpenBracketKeyUp = true
        postEscKeyPress()
        return true
    }

    private func shouldSuppressCtrlOpenBracketKeyUp(keyCode: Int64) -> Bool {
        guard suppressNextCtrlOpenBracketKeyUp,
              keyCode == KeyboardManager.KeyCode.openBracket else {
            return false
        }

        suppressNextCtrlOpenBracketKeyUp = false
        return true
    }

    private func postEscKeyPress() {
        let source = CGEventSource(stateID: .hidSystemState)
        let escKey = CGKeyCode(KeyboardManager.KeyCode.esc)

        if let down = CGEvent(keyboardEventSource: source, virtualKey: escKey, keyDown: true) {
            down.flags = []
            down.post(tap: .cghidEventTap)
        }

        if let up = CGEvent(keyboardEventSource: source, virtualKey: escKey, keyDown: false) {
            up.flags = []
            up.post(tap: .cghidEventTap)
        }
    }

    func switchInputMethod() {
        let currentSource = InputSourceManager.getCurrentSource()

        if currentSource.id == englishInputSource {
            // 从英文切换到保存的输入法
            if let lastSource = lastInputSource,
               let targetSource = InputSourceManager.getInputSource(name: lastSource) {
                guard targetSource.select() else {
                    print("切换到保存的输入法失败: \(lastSource)")
                    return
                }
            }
        } else {
            // 从其他输入法切换到英文
            lastInputSource = currentSource.id
            UserPreferences.shared.selectedInputMethod = currentSource.id
            if let englishSource = InputSourceManager.getInputSource(name: englishInputSource) {
                guard englishSource.select() else {
                    print("切换到英文输入法失败: \(englishInputSource)")
                    return
                }
            }
        }

        delegate?.keyboardManagerDidUpdateState()
    }

    private func updateLastInputSource(_ currentSource: InputSource) {
        if currentSource.id != englishInputSource {
            lastInputSource = currentSource.id
            print("初始化上一个输入法: \(currentSource.id)")
        }
        InputSourceManager.initialize()
    }

    // 添加新方法：专门用于ESC键的切换
    func switchToEnglish() {
        print("⌨️ KeyboardManager: 开始切换到英文输入法")
        if let englishSource = InputSourceManager.getInputSource(name: englishInputSource) {
            let currentSource = InputSourceManager.getCurrentSource()
            print("⌨️ 当前输入法: \(currentSource.id), 目标英文输入法: \(englishInputSource)")
            if currentSource.id != englishInputSource {
                // 保存当前输入法作为lastInputSource
                lastInputSource = currentSource.id
                print("⌨️ 保存上一个输入法: \(currentSource.id)")
                if englishSource.select() {
                    delegate?.keyboardManagerDidUpdateState()
                    print("⌨️ 已切换到英文输入法")
                } else {
                    print("⚠️ 英文输入法切换未确认成功: \(englishInputSource)")
                }
            } else {
                print("⌨️ 当前已经是英文输入法，无需切换")
            }
        } else {
            print("⚠️ 找不到英文输入法: \(englishInputSource)")
        }
    }

    // 优化事件处理逻辑
    private var lastFlags: CGEventFlags = CGEventFlags(rawValue: 0)

    func handleModifierFlags(_ flags: CGEventFlags) {
        let currentTime = Date().timeIntervalSince1970

        // 打印当前修饰键的原始值，用于调试
        // print("修饰键 flags 原始值: 0x\(String(flags.rawValue, radix: 16))（\(flags.rawValue))")

        // 检测Shift键状态的改进逻辑：支持左右Shift键
        // 左Shift: 0x20102, 右Shift: 0x20104
        let currentHasShift = flags.contains(.maskShift)
        let previousHasShift = lastFlags.contains(.maskShift)

        // Shift键按下：当前有Shift但之前没有
        let isShiftKey = currentHasShift && !previousHasShift
        // Shift键释放：之前有Shift但当前没有
        let isShiftRelease = !currentHasShift && previousHasShift

        // 检查是否有其他修饰键（当前或之前的状态）
        let hasOtherModifiers = flags.contains(.maskCommand) || flags.contains(.maskControl) ||
                                flags.contains(.maskAlternate) || flags.contains(.maskSecondaryFn) ||
                                lastFlags.contains(.maskCommand) || lastFlags.contains(.maskControl) ||
                                lastFlags.contains(.maskAlternate) || lastFlags.contains(.maskSecondaryFn)

        // 打印具体的修饰键状态
        if hasOtherModifiers {
            var modifiers: [String] = []
            if flags.contains(.maskCommand) || lastFlags.contains(.maskCommand) { modifiers.append("Command") }
            if flags.contains(.maskControl) || lastFlags.contains(.maskControl) { modifiers.append("Control") }
            if flags.contains(.maskAlternate) || lastFlags.contains(.maskAlternate) { modifiers.append("Option") }
            if flags.contains(.maskSecondaryFn) || lastFlags.contains(.maskSecondaryFn) { modifiers.append("Fn") }
            // print("检测到其他修饰键: \(modifiers.joined(separator: ", "))，忽略此次事件")

            isShiftPressed = false
            hasOtherKeysDuringShift = true
            lastFlags = flags
            return
        }

        // 更新上一次的修饰键状态
        lastFlags = flags

        if isShiftKey {
            handleShiftPress(currentTime)
        } else if isShiftRelease {
            handleShiftRelease(currentTime)
        }
    }

    private func handleShiftPress(_ time: TimeInterval) {
        if let pending = pendingShiftSwitchWorkItem,
           time - pendingShiftSwitchScheduledAt <= KeyboardManager.SHIFT_DOUBLE_TAP_WINDOW {
            pending.cancel()
            pendingShiftSwitchWorkItem = nil
            shouldSkipCurrentShiftRelease = true
            print("检测到双击 Shift，跳过 MacVimSwitch 单击 Shift 切换")
        }

        if !isShiftPressed {
            isShiftPressed = true
            shiftPressStartTime = time
            hasOtherKeysDuringShift = false
        }
    }

    private func handleShiftRelease(_ time: TimeInterval) {
        if isShiftPressed {
            let pressDuration = time - shiftPressStartTime
            // print("Shift 释放 - hasOtherKeysDuringShift: \(hasOtherKeysDuringShift), pressDuration: \(pressDuration)")
            if shouldSkipCurrentShiftRelease {
                print("双击 Shift 已交给当前应用处理")
            } else if useShiftSwitch && !hasOtherKeysDuringShift && pressDuration < 0.5 {
                if shouldDelaySingleShiftSwitchForDoubleTap() {
                    scheduleSingleShiftSwitch(time)
                } else {
                    switchInputMethod()
                }
            }
        }
        isShiftPressed = false
        hasOtherKeysDuringShift = false
        shouldSkipCurrentShiftRelease = false
    }

    private func shouldDelaySingleShiftSwitchForDoubleTap() -> Bool {
        guard let bundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else {
            return false
        }

        return bundleId.hasPrefix("com.jetbrains.") ||
               bundleId == "com.google.android.studio"
    }

    private func scheduleSingleShiftSwitch(_ time: TimeInterval) {
        pendingShiftSwitchWorkItem?.cancel()
        pendingShiftSwitchScheduledAt = time

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.pendingShiftSwitchWorkItem = nil
            self.switchInputMethod()
        }

        pendingShiftSwitchWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + KeyboardManager.SHIFT_DOUBLE_TAP_WINDOW,
            execute: workItem
        )
    }

    private func handleJkSequence(keyCode: Int64, flags: CGEventFlags) {
        guard useJkSwitch else {
            waitingForKAfterJ = false
            return
        }

        let currentTime = Date().timeIntervalSince1970

        if waitingForKAfterJ && currentTime - lastJKeyTime > KeyboardManager.JK_SEQUENCE_WINDOW {
            waitingForKAfterJ = false
        }

        // 当有修饰键（除 CapsLock 外）按下时，认为不是 jk 序列
        let disallowedModifiers: CGEventFlags = [
            .maskCommand,
            .maskControl,
            .maskAlternate,
            .maskSecondaryFn,
            .maskShift
        ]
        if !flags.intersection(disallowedModifiers).isEmpty {
            if keyCode != KeyboardManager.KeyCode.j {
                waitingForKAfterJ = false
            }
            return
        }

        if keyCode == KeyboardManager.KeyCode.j {
            waitingForKAfterJ = true
            lastJKeyTime = currentTime
            return
        }

        if keyCode == KeyboardManager.KeyCode.k {
            if waitingForKAfterJ && currentTime - lastJKeyTime <= KeyboardManager.JK_SEQUENCE_WINDOW {
                waitingForKAfterJ = false
                if let delegate = delegate, delegate.shouldSwitchInputSource() {
                    switchToEnglish()
                }
            } else {
                waitingForKAfterJ = false
            }
            return
        }

        waitingForKAfterJ = false
    }

    private func cleanupKeySequence(_ currentTime: TimeInterval) {
        // 移除超过时间窗口的按键记录
        keySequence = keySequence.filter {
            currentTime - $0 < KeyboardManager.KEY_SEQUENCE_WINDOW
        }
    }

    private func shouldTriggerSwitch(_ currentTime: TimeInterval) -> Bool {
        // 如果在时间窗口内有其他按键事件，不触发切换
        if keySequence.count > 1 {
            return false
        }

        // 如果最近有其他按键事件，不触发切换
        if currentTime - lastKeyDownTime < 0.1 {
            return false
        }

        return true
    }

    // 修改键盘事件记录方法
    func handleKeyDown(_ down: Bool) {
        if down && isShiftPressed {
            hasOtherKeysDuringShift = true
        }
    }

    func setLastInputSource(_ sourceId: String) {
        lastInputSource = sourceId
        if let source = InputSourceManager.getInputSource(name: sourceId) {
            source.select()
        }
        // 保存到 UserPreferences
        UserPreferences.shared.selectedInputMethod = sourceId
    }

    // 添加新的辅助方法来处理 CJKV 输入法切换
    private func switchToCJKV(_ source: InputSource) {
        // 第一步：切换到目标输入法
        TISSelectInputSource(source.tisInputSource)
        usleep(InputSourceManager.uSeconds)

        // 第二步：切换到英文
        if let englishSource = InputSourceManager.getInputSource(name: englishInputSource) {
            TISSelectInputSource(englishSource.tisInputSource)
            usleep(InputSourceManager.uSeconds)

            // 第三步：再切回目标输入法
            TISSelectInputSource(source.tisInputSource)
            usleep(InputSourceManager.uSeconds)

            // 第四步：验证切换结果
            let finalSource = InputSourceManager.getCurrentSource()
            if finalSource.id != source.id {
                // 如果失败，尝试使用另一种序列
                if let nonCJKV = InputSourceManager.nonCJKVSource() {
                    TISSelectInputSource(nonCJKV.tisInputSource)
                    usleep(InputSourceManager.uSeconds)
                    TISSelectInputSource(source.tisInputSource)
                    usleep(InputSourceManager.uSeconds)
                }
            }
        }
    }

    // 添加公共方法来访问和控制 eventTap
    func disableEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
    }

    // MARK: - CustomShortcutManagerDelegate

    /// 获取所有启用的快捷键
    func getEnabledCustomShortcuts() -> Set<CustomShortcutType> {
        return UserPreferences.shared.getEnabledCustomShortcuts()
    }

    /// 设置启用的快捷键
    func setEnabledCustomShortcuts(_ types: Set<CustomShortcutType>) {
        UserPreferences.shared.setEnabledCustomShortcuts(types)
        // 缓存刷新已在 UserPreferences 中处理
        delegate?.keyboardManagerDidUpdateState()
    }

    /// 检查特定快捷键是否启用
    func isCustomShortcutEnabled(_ type: CustomShortcutType) -> Bool {
        return UserPreferences.shared.isCustomShortcutEnabled(type)
    }

    /// 设置特定快捷键的启用状态
    func setCustomShortcutEnabled(_ type: CustomShortcutType, enabled: Bool) {
        UserPreferences.shared.setCustomShortcutEnabled(type, enabled: enabled)
        // 缓存刷新已在 UserPreferences 中处理
        delegate?.keyboardManagerDidUpdateState()
    }
}

// MARK: - CustomShortcutManagerDelegate Extension
extension KeyboardManager: ShortcutManagerDelegate {
    func shortcutManagerDidTriggerAction(_ type: CustomShortcutType) {
        // 当自定义快捷键被触发时，检查是否应该切换输入法
        print("🔥 KeyboardManager: 快捷键触发 \(type.displayName)")

        // 检查是否应该切换输入法
        if let delegate = delegate,
           delegate.shouldSwitchInputSource() {
            print("🔥 满足切换条件，执行切换到英文输入法")
            switchToEnglish()
        } else {
            print("⚠️ 不满足切换条件，跳过输入法切换")
        }
    }
}
