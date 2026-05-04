import Cocoa

class StatusBarManager {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var menu: NSMenu?
    private var appSelectionWindowController: AppSelectionWindowController?
    weak var appDelegate: AppDelegate?

    func setupStatusBarItem() {
        if let button = statusItem.button {
            updateStatusBarIcon()
            createAndShowMenu()
            button.isEnabled = true
        } else {
            print("错误：无法创建状态栏按钮")
        }
    }

    func updateStatusBarIcon() {
        guard let button = statusItem.button else {
            print("Status item button not found")
            return
        }

        let enabledShortcuts = KeyboardManager.shared.getEnabledCustomShortcuts()
        if enabledShortcuts.isEmpty {
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "MacVimSwitch")
        } else {
            button.image = NSImage(systemSymbolName: "keyboard.badge.ellipsis", accessibilityDescription: "MacVimSwitch (\(enabledShortcuts.count) shortcuts enabled)")
        }

        button.isEnabled = true
    }

    func createAndShowMenu() {
        print("开始创建菜单...")
        let newMenu = NSMenu()

        let homepageItem = NSMenuItem(title: "使用说明", action: #selector(openHomepage), keyEquivalent: "")
        homepageItem.target = self
        newMenu.addItem(homepageItem)

        newMenu.addItem(NSMenuItem.separator())

        print("添加输入法菜单...")
        // 添加输入法选择子菜单
        let inputMethodMenu = NSMenu()
        let inputMethodItem = NSMenuItem(title: "选择中文输入法", action: nil, keyEquivalent: "")
        inputMethodItem.submenu = inputMethodMenu

        // 获取所有CJKV输入法并添加到子菜单
        if let inputMethods = InputMethodManager.shared.getAvailableCJKVInputMethods() {
            print("当前保存的中文输入法: \(KeyboardManager.shared.lastInputSource ?? "nil")")
            print("UserPreferences中的中文输入法: \(UserPreferences.shared.selectedInputMethod ?? "nil")")
            
            for (sourceId, name) in inputMethods {
                print("添加CJKV输入法菜单项: \(name) (\(sourceId))")
                let item = NSMenuItem(
                    title: name,
                    action: #selector(selectCJKVInputMethod(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = sourceId
                // 检查是否是当前选中的输入法
                if sourceId == KeyboardManager.shared.lastInputSource {
                    print("设置中文输入法选中状态: \(name) (\(sourceId))")
                    item.state = .on
                }
                inputMethodMenu.addItem(item)
            }
        }

        newMenu.addItem(inputMethodItem)
        
        // 添加英文输入法选择子菜单
        let englishInputMethodMenu = NSMenu()
        let englishInputMethodItem = NSMenuItem(title: "选择英文输入法", action: nil, keyEquivalent: "")
        englishInputMethodItem.submenu = englishInputMethodMenu

        // 获取所有英文输入法并添加到子菜单
        if let englishInputMethods = InputMethodManager.shared.getAvailableEnglishInputMethods() {
            print("当前保存的英文输入法: \(KeyboardManager.shared.englishInputSource)")
            
            for (sourceId, name) in englishInputMethods {
                print("添加英文输入法菜单项: \(name) (\(sourceId))")
                let item = NSMenuItem(
                    title: name,
                    action: #selector(selectEnglishInputMethod(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = sourceId
                // 检查是否是当前选中的输入法
                if sourceId == KeyboardManager.shared.englishInputSource {
                    print("设置英文输入法选中状态: \(name) (\(sourceId))")
                    item.state = .on
                }
                englishInputMethodMenu.addItem(item)
            }
        }

        newMenu.addItem(englishInputMethodItem)
        newMenu.addItem(NSMenuItem.separator())

        // 添加应用列表子菜单
        if let delegate = appDelegate {
            let appsMenu = NSMenu()
            let appsMenuItem = NSMenuItem(title: "Esc生效的应用", action: nil, keyEquivalent: "")
            appsMenuItem.submenu = appsMenu

            let manageAppsItem = NSMenuItem(title: "批量管理应用...", action: #selector(openAppSelectionWindow), keyEquivalent: "")
            manageAppsItem.target = self
            appsMenu.addItem(manageAppsItem)
            appsMenu.addItem(NSMenuItem.separator())

            // 添加所有应用到子菜单
            for app in delegate.systemApps {
                let item = NSMenuItem(title: app.name, action: #selector(AppDelegate.toggleApp(_:)), keyEquivalent: "")
                item.state = delegate.allowedApps.contains(app.bundleId) ? .on : .off
                item.representedObject = app.bundleId
                item.target = delegate
                appsMenu.addItem(item)
            }

            // 添加刷新应用列表选项
            appsMenu.addItem(NSMenuItem.separator())
            let refreshItem = NSMenuItem(title: "刷新应用列表", action: #selector(AppDelegate.refreshAppList), keyEquivalent: "r")
            refreshItem.target = delegate
            appsMenu.addItem(refreshItem)

            newMenu.addItem(appsMenuItem)
            newMenu.addItem(NSMenuItem.separator())
        }

        print("添加简化的自定义快捷键菜单...")
        // 添加自定义快捷键子菜单 - 修复版本
        let shortcutsMenu = NSMenu()
        let shortcutsMenuItem = NSMenuItem(title: "快捷键设置", action: nil, keyEquivalent: "")
        shortcutsMenuItem.submenu = shortcutsMenu

        // 添加基础的快捷键选项（暂时不获取启用状态）
        let basicShortcuts: [(CustomShortcutType, String)] = [
            (.commandSpace, "Command+Space → ESC"),
            (.capsLock, "CapsLock → ESC"),
            (.ctrlOpenBracket, "Ctrl+[ → ESC"),
            (.jkSequence, "JK 序列 → ESC"),
            (.singleShift, "单击 Shift → ESC")
        ]

        for (shortcutType, displayName) in basicShortcuts {
            let item = NSMenuItem(
                title: displayName,
                action: #selector(toggleCustomShortcut(_:)),
                keyEquivalent: ""
            )
            item.representedObject = shortcutType
            item.target = self

            // 获取真实的启用状态
            let isEnabled = UserPreferences.shared.isCustomShortcutEnabled(shortcutType)
            item.state = isEnabled ? .on : .off

            shortcutsMenu.addItem(item)
            print("添加快捷键菜单项: \(displayName) - 状态: \(isEnabled ? "启用" : "禁用")")
        }

        // 添加分隔线和重置选项
        shortcutsMenu.addItem(NSMenuItem.separator())

        let resetShortcutsItem = NSMenuItem(
            title: "重置为默认设置",
            action: #selector(resetShortcutsToDefault),
            keyEquivalent: ""
        )
        resetShortcutsItem.target = self
        shortcutsMenu.addItem(resetShortcutsItem)

        newMenu.addItem(shortcutsMenuItem)
        newMenu.addItem(NSMenuItem.separator())

        // 添加开机启动选项
        let launchAtLoginItem = NSMenuItem(
            title: "开机启动",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchAtLoginItem.target = self
        launchAtLoginItem.state = UserPreferences.shared.launchAtLogin ? .on : .off
        newMenu.addItem(launchAtLoginItem)

        newMenu.addItem(NSMenuItem.separator())

        // 添加检查更新选项
        let checkUpdateItem = NSMenuItem(title: "检查更新", action: #selector(checkForUpdates), keyEquivalent: "")
        checkUpdateItem.target = self
        newMenu.addItem(checkUpdateItem)

        newMenu.addItem(NSMenuItem.separator())

        // 添加退出选项
        let quitItem = NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp
        newMenu.addItem(quitItem)

        print("设置状态栏菜单...")
        statusItem.menu = newMenu
        self.menu = newMenu
        print("菜单创建完成！")
    }

    @objc private func openHomepage() {
        if let url = URL(string: "https://github.com/Jackiexiao/macvimswitch") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openAppSelectionWindow() {
        guard let delegate = appDelegate else { return }

        if appSelectionWindowController == nil {
            appSelectionWindowController = AppSelectionWindowController(appDelegate: delegate)
        } else {
            appSelectionWindowController?.reloadApps()
        }

        appSelectionWindowController?.showWindow(nil)
        appSelectionWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func toggleCustomShortcut(_ sender: NSMenuItem) {
        guard let shortcutType = sender.representedObject as? CustomShortcutType else {
            print("无法获取快捷键类型")
            return
        }

        print("切换快捷键: \(shortcutType.displayName)")

        // 获取当前状态
        let isEnabled = UserPreferences.shared.isCustomShortcutEnabled(shortcutType)
        let newState = !isEnabled

        // 设置新状态
        UserPreferences.shared.setCustomShortcutEnabled(shortcutType, enabled: newState)

        // 更新UI
        sender.state = newState ? .on : .off
        updateStatusBarIcon()
        createAndShowMenu()

        print("快捷键 \(shortcutType.displayName) 已\(newState ? "启用" : "禁用")")
    }

    @objc private func resetShortcutsToDefault() {
        let alert = NSAlert()
        alert.messageText = "重置快捷键设置"
        alert.informativeText = "确定要重置所有快捷键设置为默认值吗？\n\n默认启用：单击 Shift → ESC"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "确定")
        alert.addButton(withTitle: "取消")

        if alert.runModal() == .alertFirstButtonReturn {
            // 重置为默认设置（只启用 Shift）
            UserPreferences.shared.setEnabledCustomShortcuts([.singleShift])
            updateStatusBarIcon()
            createAndShowMenu()
            print("快捷键设置已重置为默认值")
        }
    }

    @objc private func selectCJKVInputMethod(_ sender: NSMenuItem) {
        guard let sourceId = sender.representedObject as? String else { return }
        print("[StatusBarManager] 选择CJKV输入法: \(sourceId)")
        KeyboardManager.shared.setLastInputSource(sourceId)
        createAndShowMenu()  // 重新创建菜单以更新选中状态
    }
    
    @objc private func selectEnglishInputMethod(_ sender: NSMenuItem) {
        guard let sourceId = sender.representedObject as? String else { return }
        print("[StatusBarManager] 选择英文输入法: \(sourceId)")
        KeyboardManager.shared.englishInputSource = sourceId
        createAndShowMenu()  // 重新创建菜单以更新选中状态
    }

    @objc private func toggleLaunchAtLogin() {
        if LaunchManager.shared.toggleLaunchAtLogin() {
            // 操作成功，重新创建菜单以更新状态
            createAndShowMenu()
        } else {
            // 操作失败，显示错误提示
            let alert = NSAlert()
            alert.messageText = "设置失败"
            alert.informativeText = "无法修改开机启动设置，请检查系统权限。"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "确定")
            alert.runModal()
        }
    }

    @objc private func checkForUpdates() {
        UpdateManager.shared.checkForUpdates(silent: false)
    }

    @objc private func quitApp() {
        KeyboardManager.shared.disableEventTap()
        NSApplication.shared.terminate(self)
    }
}
