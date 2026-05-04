#!/bin/bash

# 检查 Swift 编译器是否可用
if ! command -v swiftc &> /dev/null; then
    echo "错误: 未找到 Swift 编译器。请确保已安装 Xcode 命令行工具。"
    echo "可以通过运行以下命令安装："
    echo "xcode-select --install"
    exit 1
fi

# 清理旧的构建
rm -rf dist

# 创建目录结构
mkdir -p dist/MacVimSwitch.app/Contents/{MacOS,Resources}
# 复制 Info.plist 和图标
# 先检查 AppIcon.icns 是否存在
if [ -f "AppIcon.icns" ]; then
    cp AppIcon.icns dist/MacVimSwitch.app/Contents/Resources/
    echo "已复制应用图标到资源文件夹"
else
    echo "警告：未找到 AppIcon.icns 文件，将使用默认图标"
fi
cp Info.plist dist/MacVimSwitch.app/Contents/

# 构建 ARM64 版本
echo "构建 ARM64 版本..."
if ! swiftc -o dist/MacVimSwitch.app/Contents/MacOS/macvimswitch-arm64 \
  inputsource.swift \
  CustomShortcutManager.swift \
  main.swift \
  AppDelegate.swift \
  StatusBarManager.swift \
  InputMethodManager.swift \
  UserPreferences.swift \
  LaunchManager.swift \
  UpdateManager.swift \
  -framework Cocoa \
  -framework Carbon \
  -target arm64-apple-macos11 \
  -sdk $(xcrun --show-sdk-path) \
  -O \
  -whole-module-optimization \
  -Xlinker -rpath \
  -Xlinker @executable_path/../Frameworks; then
    echo "ARM64 构建失败。"
    exit 1
fi

# 构建 x86_64 版本
echo "构建 x86_64 版本..."
if ! swiftc -o dist/MacVimSwitch.app/Contents/MacOS/macvimswitch-x86_64 \
  inputsource.swift \
  CustomShortcutManager.swift \
  main.swift \
  AppDelegate.swift \
  StatusBarManager.swift \
  InputMethodManager.swift \
  UserPreferences.swift \
  LaunchManager.swift \
  UpdateManager.swift \
  -framework Cocoa \
  -framework Carbon \
  -target x86_64-apple-macos11 \
  -sdk $(xcrun --show-sdk-path) \
  -O \
  -whole-module-optimization \
  -Xlinker -rpath \
  -Xlinker @executable_path/../Frameworks; then
    echo "x86_64 构建失败。"
    exit 1
fi

# 合并为通用二进制
echo "合并为通用二进制..."
if ! lipo -create \
  dist/MacVimSwitch.app/Contents/MacOS/macvimswitch-arm64 \
  dist/MacVimSwitch.app/Contents/MacOS/macvimswitch-x86_64 \
  -output dist/MacVimSwitch.app/Contents/MacOS/macvimswitch; then
    echo "合并二进制失败。"
    exit 1
fi

# 清理临时文件
rm dist/MacVimSwitch.app/Contents/MacOS/macvimswitch-arm64
rm dist/MacVimSwitch.app/Contents/MacOS/macvimswitch-x86_64

# 创建 Info.plist
cat > dist/MacVimSwitch.app/Contents/Info.plist << EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>macvimswitch</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.jackiexiao.macvimswitch</string>
    <key>CFBundleName</key>
    <string>MacVimSwitch</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.7.3</string>
    <key>CFBundleVersion</key>
    <string>0.7.3</string>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>MacVimSwitch needs to control system events to manage input sources.</string>
    <key>NSAppleScriptEnabled</key>
    <true/>
    <key>LSBackgroundOnly</key>
    <false/>
    <key>NSAccessibilityUsageDescription</key>
    <string>MacVimSwitch needs accessibility access to monitor keyboard events.</string>
</dict>
</plist>
EOL

# 创建 entitlements.plist
cat > entitlements.plist << EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
    <key>com.apple.security.temporary-exception.apple-events</key>
    <array>
        <string>com.apple.systemevents</string>
    </array>
    <key>com.apple.security.cs.allow-jit</key>
    <true/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
</dict>
</plist>
EOL

# 设置执行权限
chmod +x dist/MacVimSwitch.app/Contents/MacOS/macvimswitch

# 使用自签名
if ! codesign --force --deep --sign - --entitlements entitlements.plist dist/MacVimSwitch.app; then
    echo "签名失败。请确保你的开发环境正确配置。"
    exit 1
fi

# 创建 DMG（可选）
if [ "$1" = "--create-dmg" ]; then
    # 创建临时挂载点
    mkdir -p /tmp/dmg

    # 创建应用程序文件夹符号链接
    ln -s /Applications /tmp/dmg/Applications

    # 复制应用
    cp -r dist/MacVimSwitch.app /tmp/dmg/

    # 创建 DMG
    if ! hdiutil create -volname "MacVimSwitch" -srcfolder /tmp/dmg -ov -format UDZO MacVimSwitch.dmg; then
        echo "创建 DMG 失败。请确保你的开发环境正确配置。"
        exit 1
    fi

    # 清理
    rm -rf /tmp/dmg

    echo "DMG created: MacVimSwitch.dmg"
fi

echo "构建成功完成！生成了通用二进制（Universal Binary）应用程序。"
echo "该应用程序可以在 Intel 和 Apple Silicon Mac 上原生运行，无需 Rosetta。"
