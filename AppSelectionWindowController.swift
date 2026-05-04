import Cocoa

class AppSelectionWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    private weak var appDelegate: AppDelegate?
    private let searchField = NSSearchField()
    private let tableView = NSTableView()
    private var apps: [(name: String, bundleId: String)] = []
    private var filteredApps: [(name: String, bundleId: String)] = []

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 520),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Esc 生效的应用"
        window.minSize = NSSize(width: 520, height: 360)
        window.isReleasedWhenClosed = false

        super.init(window: window)

        setupContent()
        reloadApps()
        window.center()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func reloadApps() {
        apps = appDelegate?.systemApps ?? []
        applyFilter()
    }

    private func setupContent() {
        guard let contentView = window?.contentView else { return }

        let titleLabel = NSTextField(labelWithString: "选择按 Esc 时自动切换到英文输入法的应用")
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = .labelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        searchField.placeholderString = "搜索应用或 Bundle ID"
        searchField.delegate = self
        searchField.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = nil
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsMultipleSelection = true
        tableView.rowHeight = 30

        let enabledColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("enabled"))
        enabledColumn.title = ""
        enabledColumn.width = 38
        enabledColumn.minWidth = 38
        enabledColumn.maxWidth = 38
        tableView.addTableColumn(enabledColumn)

        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = "应用"
        nameColumn.width = 220
        tableView.addTableColumn(nameColumn)

        let bundleColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("bundleId"))
        bundleColumn.title = "Bundle ID"
        bundleColumn.width = 360
        tableView.addTableColumn(bundleColumn)

        scrollView.documentView = tableView

        let selectVisibleButton = NSButton(title: "全选可见", target: self, action: #selector(selectVisibleApps))
        let deselectVisibleButton = NSButton(title: "取消可见", target: self, action: #selector(deselectVisibleApps))
        let refreshButton = NSButton(title: "刷新列表", target: self, action: #selector(refreshApps))
        let doneButton = NSButton(title: "完成", target: self, action: #selector(closeWindow))
        doneButton.keyEquivalent = "\r"

        let buttonStack = NSStackView(views: [
            selectVisibleButton,
            deselectVisibleButton,
            refreshButton,
            doneButton
        ])
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 8
        buttonStack.alignment = .centerY
        buttonStack.distribution = .gravityAreas
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(titleLabel)
        contentView.addSubview(searchField)
        contentView.addSubview(scrollView)
        contentView.addSubview(buttonStack)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            searchField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            searchField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            searchField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: buttonStack.topAnchor, constant: -12),

            buttonStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            buttonStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            buttonStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
    }

    private func applyFilter() {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if query.isEmpty {
            filteredApps = apps
        } else {
            filteredApps = apps.filter { app in
                app.name.lowercased().contains(query) ||
                app.bundleId.lowercased().contains(query)
            }
        }

        tableView.reloadData()
    }

    func controlTextDidChange(_ obj: Notification) {
        applyFilter()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredApps.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < filteredApps.count,
              let identifier = tableColumn?.identifier else {
            return nil
        }

        let app = filteredApps[row]

        switch identifier.rawValue {
        case "enabled":
            let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggleAppFromCheckbox(_:)))
            checkbox.tag = row
            checkbox.state = appDelegate?.allowedApps.contains(app.bundleId) == true ? .on : .off
            return checkbox

        case "name":
            let field = NSTextField(labelWithString: app.name)
            field.lineBreakMode = .byTruncatingTail
            return field

        case "bundleId":
            let field = NSTextField(labelWithString: app.bundleId)
            field.textColor = .secondaryLabelColor
            field.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            field.lineBreakMode = .byTruncatingTail
            return field

        default:
            return nil
        }
    }

    @objc private func toggleAppFromCheckbox(_ sender: NSButton) {
        guard sender.tag < filteredApps.count,
              let appDelegate = appDelegate else {
            return
        }

        let app = filteredApps[sender.tag]
        var allowedApps = appDelegate.allowedApps

        if sender.state == .on {
            allowedApps.insert(app.bundleId)
        } else {
            allowedApps.remove(app.bundleId)
        }

        appDelegate.allowedApps = allowedApps
        appDelegate.statusBarManager.createAndShowMenu()
    }

    @objc private func selectVisibleApps() {
        setVisibleAppsEnabled(true)
    }

    @objc private func deselectVisibleApps() {
        setVisibleAppsEnabled(false)
    }

    private func setVisibleAppsEnabled(_ enabled: Bool) {
        guard let appDelegate = appDelegate else { return }

        var allowedApps = appDelegate.allowedApps
        for app in filteredApps {
            if enabled {
                allowedApps.insert(app.bundleId)
            } else {
                allowedApps.remove(app.bundleId)
            }
        }

        appDelegate.allowedApps = allowedApps
        tableView.reloadData()
        appDelegate.statusBarManager.createAndShowMenu()
    }

    @objc private func refreshApps() {
        appDelegate?.refreshAppList()
        reloadApps()
    }

    @objc private func closeWindow() {
        window?.close()
    }
}
