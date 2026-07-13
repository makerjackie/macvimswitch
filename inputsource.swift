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
    func select(useSystemPreviousShortcut: Bool = true) -> Bool {
        let startedAt = CFAbsoluteTimeGetCurrent()
        let currentSource = InputSourceManager.getCurrentSource()
        if currentSource.id == self.id {
            let success = InputSourceManager.waitUntilCurrentSourceStable(id: self.id)
            logResult(success: success, strategy: "already-selected", startedAt: startedAt)
            return success
        }

        let success: Bool
        if self.isCJKV {
            success = switchCJKVSource(
                useSystemPreviousShortcut: useSystemPreviousShortcut
            )
        } else {
            success = selectDirectlyWithRetry()
        }
        logResult(
            success: success,
            strategy: self.isCJKV && useSystemPreviousShortcut
                ? "system-previous-with-tis-fallback"
                : "direct",
            startedAt: startedAt
        )
        return success
    }

    private func selectDirectlyWithRetry(maxAttempts: Int = 3) -> Bool {
        for attempt in 1...maxAttempts {
            let status = TISSelectInputSource(tisInputSource)
            if status != noErr {
                print("切换输入法失败: \(id), status=\(status), attempt=\(attempt)")
            }

            if InputSourceManager.waitUntilCurrentSourceStable(id: self.id) {
                return true
            }

            if attempt < maxAttempts {
                usleep(InputSourceManager.retryDelayUSeconds)
            }
        }

        print("输入法切换未确认成功: \(id)")
        return false
    }

    private func switchCJKVSource(useSystemPreviousShortcut: Bool) -> Bool {
        // ESC just moved from this CJKV source to the configured English
        // source, so macOS already has the exact target in its previous-source
        // history. Let the system restore that text-input session directly.
        if useSystemPreviousShortcut,
           InputSourceManager.selectPreviousInputSource(),
           InputSourceManager.waitUntilCurrentSource(
                id: id,
                timeoutUseconds: InputSourceManager.systemShortcutTimeoutUSeconds
           ),
           InputSourceManager.waitUntilCurrentSourceStable(
                id: id,
                stableUseconds: InputSourceManager.cjkvSettleUSeconds
           ) {
            InputSourceManager.postInputContextRefreshPulse()
            return true
        }

        if useSystemPreviousShortcut {
            print("系统输入法快捷键恢复未确认，回退到 TIS: \(id)")
        }

        for attempt in 1...InputSourceManager.cjkvMaxAttempts {
            let status = TISSelectInputSource(tisInputSource)
            if status != noErr {
                print("CJKV 切换失败: \(id), status=\(status), attempt=\(attempt)")
            }

            if status == noErr,
               InputSourceManager.waitUntilCurrentSource(id: id),
               InputSourceManager.waitUntilCurrentSourceStable(
                    id: id,
                    stableUseconds: InputSourceManager.cjkvSettleUSeconds
               ) {
                InputSourceManager.postInputContextRefreshPulse()
                return true
            }

            if attempt < InputSourceManager.cjkvMaxAttempts,
               let bridge = InputSourceManager.nonCJKVSource(excluding: id) {
                print("CJKV 切换未稳定，通过 \(bridge.id) 重建输入上下文")
                _ = TISSelectInputSource(bridge.tisInputSource)
                _ = InputSourceManager.waitUntilCurrentSource(
                    id: bridge.id,
                    timeoutUseconds: 160_000
                )
                usleep(InputSourceManager.retryDelayUSeconds)
            }
        }

        print("CJKV 输入法切换未确认成功: \(id)")
        return false
    }

    private func logResult(success: Bool, strategy: String, startedAt: CFAbsoluteTime) {
        let elapsedMs = (CFAbsoluteTimeGetCurrent() - startedAt) * 1_000
        print(
            String(
                format: "[InputSwitch] target=%@ strategy=%@ success=%@ elapsed=%.1fms",
                id,
                strategy,
                success ? "true" : "false",
                elapsedMs
            )
        )
    }
}

// 修改 InputSourceManager 类
class InputSourceManager {
    static var inputSources: [InputSource] = []
    static var uSeconds: UInt32 = 20_000
    static var retryDelayUSeconds: UInt32 = 45_000
    static var cjkvSettleUSeconds: UInt32 = 80_000
    static var systemShortcutTimeoutUSeconds: UInt32 = 360_000
    static var cjkvMaxAttempts: Int = 3
    static var keyboardOnly: Bool = true
    static let syntheticEventMarker: Int64 = 0x4D5653

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

    static func nonCJKVSource(excluding excludedID: String? = nil) -> InputSource? {
        return inputSources.first(where: { !$0.isCJKV && $0.id != excludedID })
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

    @discardableResult
    static func selectPreviousInputSource() -> Bool {
        guard let shortcut = getSelectPreviousShortcut(),
              let source = CGEventSource(stateID: .hidSystemState),
              let down = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(shortcut.0),
                keyDown: true
              ),
              let up = CGEvent(
                keyboardEventSource: source,
                virtualKey: CGKeyCode(shortcut.0),
                keyDown: false
              ) else {
            return false
        }

        let flags = CGEventFlags(rawValue: shortcut.1)
        down.flags = flags
        up.flags = flags
        down.setIntegerValueField(.eventSourceUserData, value: syntheticEventMarker)
        up.setIntegerValueField(.eventSourceUserData, value: syntheticEventMarker)
        down.post(tap: .cghidEventTap)
        usleep(20_000)
        up.post(tap: .cghidEventTap)
        return true
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

    static func waitUntilCurrentSourceStable(
        id: String,
        timeoutUseconds: UInt32 = 240_000,
        stableUseconds: UInt32 = 30_000,
        pollIntervalUseconds: UInt32 = 10_000
    ) -> Bool {
        var waited: UInt32 = 0
        var stableFor: UInt32 = 0

        while waited <= timeoutUseconds {
            if getCurrentSource().id == id {
                stableFor += pollIntervalUseconds
                if stableFor >= stableUseconds {
                    return true
                }
            } else {
                stableFor = 0
            }

            usleep(pollIntervalUseconds)
            waited += pollIntervalUseconds
        }

        return false
    }

    static func postInputContextRefreshPulse() {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let down = CGEvent(
                keyboardEventSource: source,
                virtualKey: 0x3F,
                keyDown: true
              ),
              let up = CGEvent(
                keyboardEventSource: source,
                virtualKey: 0x3F,
                keyDown: false
              ) else {
            return
        }

        down.type = .flagsChanged
        down.flags = .maskSecondaryFn
        up.type = .flagsChanged
        up.flags = []
        down.setIntegerValueField(.eventSourceUserData, value: syntheticEventMarker)
        up.setIntegerValueField(.eventSourceUserData, value: syntheticEventMarker)
        down.post(tap: .cghidEventTap)
        usleep(1_000)
        up.post(tap: .cghidEventTap)
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
    private static let SHIFT_SOURCE_SWITCH_DELAY: TimeInterval = 0.01
    private var suppressNextCtrlOpenBracketKeyUp = false
    private var canRestoreLastInputSourceWithSystemShortcut = false
    private enum CJKVSwitchPhase {
        case systemShortcut
        case direct
    }

    private var isSwitchingToCJKV = false
    private var bufferedKeyEvents: [CGEvent] = []
    private var cjkvSwitchStartedAt: CFAbsoluteTime = 0
    private var cjkvSwitchTarget: InputSource?
    private var cjkvSwitchPhase: CJKVSwitchPhase?
    private var cjkvSwitchDeadline: CFAbsoluteTime = 0
    private var cjkvStableSince: CFAbsoluteTime?
    private var cjkvDirectAttempt = 0
    private static let CJKV_POLL_INTERVAL: TimeInterval = 0.01
    private static let CJKV_DIRECT_TIMEOUT: TimeInterval = 0.24

    var isInputSourceSwitchInProgress: Bool {
        return isSwitchingToCJKV
    }

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

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            manager.reenableEventTap(reason: type)
            return Unmanaged.passUnretained(event)
        }

        if event.getIntegerValueField(.eventSourceUserData) == InputSourceManager.syntheticEventMarker {
            return Unmanaged.passUnretained(event)
        }

        if (type == .keyDown || type == .keyUp),
           manager.bufferKeyEventDuringCJKVSwitch(type: type, event: event) {
            return nil
        }

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
        guard !isSwitchingToCJKV else {
            print("[InputSwitch] 已在切换到中文输入法，忽略重复请求")
            return
        }

        let currentSource = InputSourceManager.getCurrentSource()

        if currentSource.id == englishInputSource {
            // 从英文切换到保存的输入法
            if let lastSource = lastInputSource,
               let targetSource = InputSourceManager.getInputSource(name: lastSource) {
                let useSystemShortcut = canRestoreLastInputSourceWithSystemShortcut
                canRestoreLastInputSourceWithSystemShortcut = false
                beginCJKVSwitch(target: targetSource)
                DispatchQueue.main.asyncAfter(
                    deadline: .now() + KeyboardManager.SHIFT_SOURCE_SWITCH_DELAY
                ) { [weak self] in
                    self?.startCJKVSwitch(useSystemShortcut: useSystemShortcut)
                }
            }
        } else {
            // 从其他输入法切换到英文
            lastInputSource = currentSource.id
            UserPreferences.shared.selectedInputMethod = currentSource.id
            DispatchQueue.main.asyncAfter(
                deadline: .now() + KeyboardManager.SHIFT_SOURCE_SWITCH_DELAY
            ) { [weak self] in
                guard let self = self,
                      let englishSource = InputSourceManager.getInputSource(name: self.englishInputSource) else {
                    return
                }
                guard englishSource.select() else {
                    print("切换到英文输入法失败: \(self.englishInputSource)")
                    return
                }
                self.canRestoreLastInputSourceWithSystemShortcut = true
                self.notifyStateUpdated()
            }
        }
    }

    private func beginCJKVSwitch(target: InputSource) {
        isSwitchingToCJKV = true
        bufferedKeyEvents.removeAll(keepingCapacity: true)
        cjkvSwitchStartedAt = CFAbsoluteTimeGetCurrent()
        cjkvSwitchTarget = target
        cjkvSwitchPhase = nil
        cjkvStableSince = nil
        cjkvDirectAttempt = 0
        notifyStateUpdated()
    }

    private func startCJKVSwitch(useSystemShortcut: Bool) {
        guard isSwitchingToCJKV else { return }

        if useSystemShortcut,
           InputSourceManager.selectPreviousInputSource() {
            cjkvSwitchPhase = .systemShortcut
            cjkvSwitchDeadline = CFAbsoluteTimeGetCurrent() +
                TimeInterval(InputSourceManager.systemShortcutTimeoutUSeconds) / 1_000_000
            pollCJKVSwitch()
        } else {
            startDirectCJKVAttempt()
        }
    }

    private func startDirectCJKVAttempt() {
        guard isSwitchingToCJKV,
              let target = cjkvSwitchTarget else {
            return
        }

        cjkvDirectAttempt += 1
        cjkvSwitchPhase = .direct
        cjkvStableSince = nil
        cjkvSwitchDeadline = CFAbsoluteTimeGetCurrent() + KeyboardManager.CJKV_DIRECT_TIMEOUT

        let status = TISSelectInputSource(target.tisInputSource)
        if status != noErr {
            print(
                "CJKV 切换失败: \(target.id), status=\(status), attempt=\(cjkvDirectAttempt)"
            )
        }
        pollCJKVSwitch()
    }

    private func pollCJKVSwitch() {
        guard isSwitchingToCJKV,
              let target = cjkvSwitchTarget,
              let phase = cjkvSwitchPhase else {
            return
        }

        let now = CFAbsoluteTimeGetCurrent()
        if InputSourceManager.getCurrentSource().id == target.id {
            if cjkvStableSince == nil {
                cjkvStableSince = now
            }

            let stableFor = now - (cjkvStableSince ?? now)
            let requiredStableTime = TimeInterval(InputSourceManager.cjkvSettleUSeconds) /
                1_000_000
            if stableFor >= requiredStableTime {
                InputSourceManager.postInputContextRefreshPulse()
                finishCJKVSwitch(success: true, targetID: target.id)
                return
            }
        } else {
            cjkvStableSince = nil
            if now >= cjkvSwitchDeadline {
                if phase == .systemShortcut {
                    print("系统输入法快捷键恢复未确认，回退到 TIS: \(target.id)")
                    startDirectCJKVAttempt()
                } else {
                    retryOrFinishDirectCJKVSwitch(target: target)
                }
                return
            }
        }

        DispatchQueue.main.asyncAfter(
            deadline: .now() + KeyboardManager.CJKV_POLL_INTERVAL
        ) { [weak self] in
            self?.pollCJKVSwitch()
        }
    }

    private func retryOrFinishDirectCJKVSwitch(target: InputSource) {
        guard cjkvDirectAttempt < InputSourceManager.cjkvMaxAttempts else {
            finishCJKVSwitch(success: false, targetID: target.id)
            return
        }

        if let bridge = InputSourceManager.nonCJKVSource(excluding: target.id) {
            print("CJKV 切换未稳定，通过 \(bridge.id) 重建输入上下文")
            _ = TISSelectInputSource(bridge.tisInputSource)
        }

        DispatchQueue.main.asyncAfter(
            deadline: .now() +
                TimeInterval(InputSourceManager.retryDelayUSeconds) / 1_000_000
        ) { [weak self] in
            self?.startDirectCJKVAttempt()
        }
    }

    private func finishCJKVSwitch(success: Bool, targetID: String) {
        let elapsedMs = (CFAbsoluteTimeGetCurrent() - cjkvSwitchStartedAt) * 1_000
        let events = bufferedKeyEvents
        bufferedKeyEvents.removeAll(keepingCapacity: true)
        isSwitchingToCJKV = false
        cjkvSwitchTarget = nil
        cjkvSwitchPhase = nil
        cjkvStableSince = nil

        print(
            String(
                format: "[InputSwitch] ready target=%@ success=%@ elapsed=%.1fms bufferedEvents=%d",
                targetID,
                success ? "true" : "false",
                elapsedMs,
                events.count
            )
        )

        if !success {
            print("切换到保存的输入法失败: \(targetID)，原样回放暂存按键")
        }

        notifyStateUpdated()
        replayBufferedKeyEvents(events)
    }

    private func bufferKeyEventDuringCJKVSwitch(
        type: CGEventType,
        event: CGEvent
    ) -> Bool {
        if !isSwitchingToCJKV,
           type == .keyDown,
           pendingShiftSwitchWorkItem != nil {
            pendingShiftSwitchWorkItem?.cancel()
            pendingShiftSwitchWorkItem = nil
            switchInputMethod()
        }

        guard isSwitchingToCJKV,
              let copiedEvent = event.copy() else {
            return false
        }

        bufferedKeyEvents.append(copiedEvent)
        return true
    }

    private func replayBufferedKeyEvents(_ events: [CGEvent]) {
        for event in events {
            event.setIntegerValueField(
                .eventSourceUserData,
                value: InputSourceManager.syntheticEventMarker
            )
            event.post(tap: .cghidEventTap)
        }
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
        DispatchQueue.main.async { [weak self] in
            self?.performSwitchToEnglish()
        }
    }

    private func performSwitchToEnglish() {
        print("⌨️ KeyboardManager: 开始切换到英文输入法")
        if let englishSource = InputSourceManager.getInputSource(name: englishInputSource) {
            let currentSource = InputSourceManager.getCurrentSource()
            print("⌨️ 当前输入法: \(currentSource.id), 目标英文输入法: \(englishInputSource)")
            if currentSource.id != englishInputSource {
                // 保存当前输入法作为lastInputSource
                lastInputSource = currentSource.id
                print("⌨️ 保存上一个输入法: \(currentSource.id)")
                if englishSource.select() {
                    canRestoreLastInputSourceWithSystemShortcut = true
                    notifyStateUpdated()
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
        canRestoreLastInputSourceWithSystemShortcut = false
        // 保存到 UserPreferences
        UserPreferences.shared.selectedInputMethod = sourceId
        DispatchQueue.main.async {
            if let source = InputSourceManager.getInputSource(name: sourceId) {
                _ = source.select(useSystemPreviousShortcut: false)
            }
        }
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

    private func reenableEventTap(reason: CGEventType) {
        guard let tap = eventTap else { return }
        print("⚠️ 键盘事件监听被系统禁用，立即恢复: \(reason.rawValue)")
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func notifyStateUpdated() {
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.keyboardManagerDidUpdateState()
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
