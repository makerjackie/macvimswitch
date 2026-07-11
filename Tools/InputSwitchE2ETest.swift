import Cocoa
import Carbon
import Foundation

private let iterations = Int(CommandLine.arguments.dropFirst().first ?? "30") ?? 30
private let cjkvTypingDelayMs = Int(CommandLine.arguments.dropFirst(2).first ?? "160") ?? 160
private let useDirectTIS = CommandLine.arguments.dropFirst(3).first == "direct"

private func inputSource(withID id: String) -> TISInputSource {
    let filter = [kTISPropertyInputSourceID as String: id] as CFDictionary
    let sources = TISCreateInputSourceList(filter, false).takeRetainedValue() as NSArray
    guard let source = sources.firstObject else {
        fatalError("Input source not found: \(id)")
    }
    return source as! TISInputSource
}

private let englishInputSource = inputSource(withID: "com.apple.keylayout.ABC")
private let cjkvInputSource = inputSource(withID: "com.bytedance.inputmethod.doubaoime.pinyin")

private func selectDirectly(_ source: TISInputSource) {
    let status = TISSelectInputSource(source)
    guard status == noErr else {
        fatalError("TISSelectInputSource failed: \(status)")
    }
}

private func axValue(_ element: AXUIElement, _ attribute: CFString) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else {
        return nil
    }
    return value
}

private func findInputMenuExtra(
    in element: AXUIElement,
    depth: Int = 0
) -> AXUIElement? {
    guard depth <= 4 else { return nil }
    let role = axValue(element, kAXRoleAttribute as CFString) as? String
    let subrole = axValue(element, kAXSubroleAttribute as CFString) as? String
    if role == kAXMenuBarItemRole as String, subrole == "AXMenuExtra" {
        let description = axValue(element, kAXDescriptionAttribute as CFString) as? String
        if description == "ABC" || description == "豆包输入法" {
            return element
        }
    }

    guard let children = axValue(element, kAXChildrenAttribute as CFString) as? [AXUIElement] else {
        return nil
    }
    for child in children {
        if let found = findInputMenuExtra(in: child, depth: depth + 1) {
            return found
        }
    }
    return nil
}

private let textInputMenuAgent = NSRunningApplication.runningApplications(
    withBundleIdentifier: "com.apple.TextInputMenuAgent"
).first!
private let textInputMenuAgentAX = AXUIElementCreateApplication(textInputMenuAgent.processIdentifier)

private func globalInputSourceDescription() -> String {
    guard let item = findInputMenuExtra(in: textInputMenuAgentAX) else {
        return ""
    }
    return axValue(item, kAXDescriptionAttribute as CFString) as? String ?? ""
}

private func waitForInputSource(_ expectedDescription: String, timeout: TimeInterval = 2.0) -> TimeInterval? {
    let start = CFAbsoluteTimeGetCurrent()
    repeat {
        if globalInputSourceDescription() == expectedDescription {
            return CFAbsoluteTimeGetCurrent() - start
        }
        usleep(2_000)
    } while CFAbsoluteTimeGetCurrent() - start < timeout
    return nil
}

private func postKey(_ keyCode: CGKeyCode, flags: CGEventFlags = []) {
    guard let source = CGEventSource(stateID: .hidSystemState),
          let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
          let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
        fatalError("Unable to create keyboard event")
    }
    down.flags = flags
    up.flags = flags
    down.post(tap: .cghidEventTap)
    usleep(8_000)
    up.post(tap: .cghidEventTap)
}

private func postSingleShift() {
    guard let source = CGEventSource(stateID: .hidSystemState),
          let down = CGEvent(keyboardEventSource: source, virtualKey: 0x38, keyDown: true),
          let up = CGEvent(keyboardEventSource: source, virtualKey: 0x38, keyDown: false) else {
        fatalError("Unable to create Shift event")
    }
    down.type = .flagsChanged
    down.flags = .maskShift
    up.type = .flagsChanged
    up.flags = []
    down.post(tap: .cghidEventTap)
    usleep(40_000)
    up.post(tap: .cghidEventTap)
}

private func textEditApplication() -> NSRunningApplication {
    if let running = NSRunningApplication.runningApplications(
        withBundleIdentifier: "com.apple.TextEdit"
    ).first {
        return running
    }

    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = true
    let semaphore = DispatchSemaphore(value: 0)
    var launched: NSRunningApplication?
    NSWorkspace.shared.openApplication(
        at: URL(fileURLWithPath: "/System/Applications/TextEdit.app"),
        configuration: configuration
    ) { application, error in
        if let error {
            fputs("Unable to launch TextEdit: \(error)\n", stderr)
        }
        launched = application
        semaphore.signal()
    }
    semaphore.wait()
    guard let launched else {
        fatalError("TextEdit did not launch")
    }
    return launched
}

private let textEdit = textEditApplication()
private let textEditAX = AXUIElementCreateApplication(textEdit.processIdentifier)

private func focusedTextEditElement() -> AXUIElement {
    var value: CFTypeRef?
    let status = AXUIElementCopyAttributeValue(
        textEditAX,
        kAXFocusedUIElementAttribute as CFString,
        &value
    )
    guard status == .success, let value else {
        fatalError("Unable to get TextEdit focused element: \(status.rawValue)")
    }
    return unsafeBitCast(value, to: AXUIElement.self)
}

private func focusEmptyTextEditDocument() {
    var focused: AXUIElement?
    for _ in 0..<100 {
        var value: CFTypeRef?
        if AXUIElementCopyAttributeValue(
            textEditAX,
            kAXFocusedUIElementAttribute as CFString,
            &value
        ) == .success, let value {
            focused = unsafeBitCast(value, to: AXUIElement.self)
            break
        }
        usleep(5_000)
    }
    guard let focused else {
        fatalError("TextEdit does not have a focused editor")
    }
    let status = AXUIElementSetAttributeValue(
        focused,
        kAXValueAttribute as CFString,
        "" as CFString
    )
    guard status == .success else {
        fatalError("Unable to clear TextEdit: \(status.rawValue)")
    }
}

private func textEditContents() -> String {
    var value: CFTypeRef?
    let status = AXUIElementCopyAttributeValue(
        focusedTextEditElement(),
        kAXValueAttribute as CFString,
        &value
    )
    guard status == .success else {
        fatalError("Unable to read TextEdit: \(status.rawValue)")
    }
    return value as? String ?? ""
}

private func percentile(_ values: [Double], _ fraction: Double) -> Double {
    guard !values.isEmpty else { return 0 }
    let sorted = values.sorted()
    let index = min(sorted.count - 1, Int(Double(sorted.count - 1) * fraction))
    return sorted[index]
}

guard AXIsProcessTrusted() else {
    fatalError("Accessibility permission is required")
}

let defaults = UserDefaults(suiteName: "com.jackiexiao.macvimswitch")!
let originalAllowedApps = defaults.array(forKey: "allowedApps") as? [String] ?? []
var allowedApps = Set(originalAllowedApps)
allowedApps.insert("com.apple.TextEdit")
defaults.set(Array(allowedApps), forKey: "allowedApps")
defaults.synchronize()

defer {
    defaults.set(originalAllowedApps, forKey: "allowedApps")
    defaults.synchronize()
    _ = AXUIElementSetAttributeValue(
        focusedTextEditElement(),
        kAXValueAttribute as CFString,
        "" as CFString
    )
}

focusEmptyTextEditDocument()

var englishLatencies: [Double] = []
var cjkvLatencies: [Double] = []
var failures: [String] = []

for iteration in 1...iterations {
    focusEmptyTextEditDocument()

    if useDirectTIS {
        selectDirectly(englishInputSource)
    } else {
        postKey(0x35) // Escape: MacVimSwitch should select the configured English source.
    }
    guard let englishElapsed = waitForInputSource("ABC") else {
        failures.append("iteration \(iteration): English source timeout, current=\(globalInputSourceDescription())")
        continue
    }
    englishLatencies.append(englishElapsed * 1_000)
    usleep(120_000)
    postKey(0x07) // x
    usleep(40_000)
    let englishText = textEditContents()
    if englishText != "x" {
        failures.append("iteration \(iteration): English functional check got \(englishText.debugDescription)")
    }

    focusEmptyTextEditDocument()
    if useDirectTIS {
        selectDirectly(cjkvInputSource)
    } else {
        postSingleShift() // A single Shift toggles back to the saved CJKV source.
    }
    guard let cjkvElapsed = waitForInputSource("豆包输入法") else {
        failures.append("iteration \(iteration): CJKV source timeout, current=\(globalInputSourceDescription())")
        continue
    }
    cjkvLatencies.append(cjkvElapsed * 1_000)
    usleep(useconds_t(cjkvTypingDelayMs * 1_000))
    postKey(0x00) // a
    usleep(60_000)
    postKey(0x31) // space, committing the first Chinese candidate
    usleep(200_000)
    let cjkvText = textEditContents()
    if cjkvText.unicodeScalars.allSatisfy({ $0.isASCII }) {
        failures.append("iteration \(iteration): CJKV functional check got ASCII \(cjkvText.debugDescription)")
    }
}

fputs("iterations=\(iterations)\n", stderr)
fputs(String(format: "english latency ms: p50=%.1f p95=%.1f max=%.1f\n", percentile(englishLatencies, 0.50), percentile(englishLatencies, 0.95), englishLatencies.max() ?? 0), stderr)
fputs(String(format: "CJKV latency ms: p50=%.1f p95=%.1f max=%.1f\n", percentile(cjkvLatencies, 0.50), percentile(cjkvLatencies, 0.95), cjkvLatencies.max() ?? 0), stderr)
fputs("failures=\(failures.count)\n", stderr)
for failure in failures {
    fputs("FAIL: \(failure)\n", stderr)
}

fflush(stderr)
exit(failures.isEmpty ? 0 : 1)
