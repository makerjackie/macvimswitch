# MacVimSwitch

> 这个项目的代码除了 [macism](https://github.com/laishulu/macism)  的部分，其他完全由 AI 生成，我本人不会 swift

[中文说明](README.md) | [English](README_EN.md) | [日本語](README_JA.md) | [한국어](README_KO.md)

MacVimSwitch 是一个 macOS 输入法切换工具，专为 Vim 用户和经常需要切换中文输入法的用户设计。避免在按 Esc 切换到 Normal 模式时，输入法还停留在中文输入法的尴尬。

## 功能特点

- 一次安装，解决多个软件 Vim 中英文切换问题，只需非常简单的配置。这是相比其他方案最大的优势。
- 按 ESC 键时自动切换到 ABC 英文输入法，可以设置只在指定的多个应用中生效（如 Vscode、Terminal、Obsidian、Cursor、Xcode）
- 可选：启用 `Ctrl+[` 作为真实 Esc，适合 MacVim、VSCodeVim 等 Vim 环境
- 可选：启用 `jk` 连击触发 ESC 切换，更贴近常见 Vim 插入模式映射
- Shift 键切换 ABC 英文输入法 和 中文/日文/韩文/越南文输入法
  - 可以是任何中文输入法， 如搜狗、讯飞、微信输入法等
  - 使用前建议关闭输入法中的"使用 Shift 切换中英文"选项
- 温馨提示：如果你不想使用 Shift 键切换输入法，在 Mac 上，CapsLock 短按可以切换输入法，长按才是锁定大写
- 推荐：配合上 [inputsource.pro](https://inputsource.pro/)这类能设置每个应用默认输入法的程序使用体验更佳。举个例子，你进入到浏览器中默认是中文输入法，进入 Vim 中默认是英文输入法。就不需要自己频繁切换输入法了。
- 介绍视频：https://www.bilibili.com/video/BV1DRwTeKEcx/

<img width="383" alt="Image" src="https://github.com/user-attachments/assets/0eb4b7a0-c229-4334-b1ff-cd78dd477196" />

## 已知问题

### 1. 插入模式输入法切换
现在从正常模式切回插入模式，无法自动切换回之前的输入法，默认是英文。见 [issue](https://github.com/Jackiexiao/macvimswitch/issues/6)

我个人的解决方法是：按一下 shift 切换回中文，习惯了也还行，因为写代码的时候进入插入模式不切换为中文也挺常见。

### 2. 更新后需要重新授权辅助功能
**问题描述：** 下载新版本 MacVimSwitch 后，需要重新授予辅助功能权限

**原因：** 由于应用使用自签名（而非 Apple Developer 证书），每次构建的签名标识都不同，macOS 会将其识别为不同的应用，因此需要重新授权

**解决步骤：**
1. 打开 系统设置 → 隐私与安全性 → 辅助功能
2. 删除旧的 MacVimSwitch 条目（点击 `-` 按钮）
3. 添加新的 MacVimSwitch（点击 `+` 按钮，选择新版本的应用）
4. 确保开关已打开
5. 重启 MacVimSwitch 应用

**未来计划：** 如果有好心人愿意资助 Apple Developer 账号（$99/年），我会使用正式证书签名，这样更新时就不需要重新授权了 😄

## 安装方法

### 手动安装

从 [GitHub Releases](https://github.com/Jackiexiao/macvimswitch/releases) 下载并手动安装。

### Homebrew 安装

```shell
brew tap Jackiexiao/tap
brew install --cask macvimswitch
```

## 使用方法

1. 首次启动：
   - 解压后打开 MacVimSwitch
   - 根据提示授予辅助功能权限
   - 打开系统偏好设置 → 安全性与隐私 → 隐私 → 辅助功能
   - 添加并启用 MacVimSwitch
   - 重启应用程序，状态栏图标应该出现了。

2. 首次使用重要设置：
   - 关闭输入法中的"使用 Shift 切换中英文"选项，避免冲突
   - 在状态栏菜单中选择您偏好的中文输入法，此时就可以正常切换了。
   - 如果切换无法生效
     - 手动鼠标点击切换一次输入法
     - 确认您是否为“选择上一个输入源”启用 MacOS 键盘快捷键（默认是开启的），该快捷键可在“首选项 - > 键盘 - > 快捷键 - > InputSource”中找到。
     - 快捷方式可以是您想要的任何内容，macism 将从该条目中读取快捷方式并在需要时通过仿真触发它。只是为了确保您已经启用了快捷方式。

3. 菜单栏选项：
   - 点击状态栏的键盘图标可以：
     - 查看使用说明
     - 选择偏好的中文输入法
     - 开启/关闭 Shift 键切换功能
     - 开启/关闭 `Ctrl+[` ESC 模式
     - 开启/关闭 `jk` ESC 模式
     - 选择 Esc 生效的应用（可多选，也可以在批量管理窗口中搜索和勾选）
     - 开启/关闭开机自动启动
     - 退出应用程序

## MacVimSwitch 的优点

MacVimSwitch 相比其他输入法切换方案有以下优势：

1. 通用兼容性
   - 可在所有应用程序中使用（VSCode、终端、Obsidian、Cursor、Warp、Windsurf 等）
   - 无需针对不同应用进行配置
   - 不需要为不同编辑器安装插件

2. 方便设置
   - 可以设置只在某些应用中生效
   - 可以便捷的设置使用哪种中文输入法（搜狗、讯飞、微信输入法等）

3. 其他解决方案
- [这篇文章](https://jdhao.github.io/2021/02/25/nvim_ime_mode_auto_switch/) 总结了多种 Vim 中英文切换软件的用法。总的来说，最大的痛点是这些插件需要额外的配置，无法在所有应用中使用。
- [smartim](https://github.com/ybian/smartim) 适用于 mac 支持插件安装的 vim，无法在多个软件中使用。
- [imselect](https://github.com/daipeihust/im-select) 命令行切换输入法，为了在多个软件中使用，每个软件需要做额外的配置，有时候延迟高
- [vim-xkbswitch](https://github.com/lyokha/vim-xkbswitch) Vim 插件，为了在多个软件中使用，每个软件需要做额外的配置
- karabiner：自定义快捷键，可以多个软件生效，但延迟较高，配置麻烦

## 开发者指南

### 发布流程

1. 创建 GitHub 仓库
```bash
# 1. 在 github.com/jackiexiao/macvimswitch 创建新仓库
# 2. 克隆并初始化仓库
git clone https://github.com/jackiexiao/macvimswitch.git
cd macvimswitch
```

2. 准备发布文件
```bash
# 添加所有必要文件
git add macvimswitch.swift README.md README_CN.md LICENSE
git commit -m "Initial commit"
git push origin main
```

3. 创建发布版本
```bash
# 标记版本
git tag -a v1.0.0
git push origin v1.0.0
```
GitHub Actions 工作流会自动：
- 构建应用程序
- 创建包含应用程序包（.app）和源代码包（.tar.gz）的发布版本
- 计算并显示用于更新 Homebrew formula 的 SHA256 值
更新 Homebrew Formula


4. 创建 Homebrew Tap
```bash
# 1. 创建新仓库：github.com/jackiexiao/homebrew-tap（如果不存在）
# 2. 克隆仓库
git clone https://github.com/jackiexiao/homebrew-tap.git
cd homebrew-tap

# 3. 使用 GitHub Release 中提供的 SHA256 值更新 macvimswitch.rb
# 4. 提交并推送 formula
git add macvimswitch.rb
git commit -m "更新 MacVimSwitch formula 到 v1.0.0"
git push origin main
```

### 本地开发

本地构建和测试：
```bash
./build.sh
pkill -f MacVimSwitch
# 人工测试方法1：
./dist/MacVimSwitch.app/Contents/MacOS/MacVimSwitch

# 人工测试方法2：
# 如果你使用 双击打开 dist/MacVimSwitch.app，你可能需要这样做
# 打开第一次，辅助功能先把之前的 MacVimSwitch 删除，看起来好像必须得这么做
open dist/MacVimSwitch.app
# 打开第二次，启动辅助功能
open dist/MacVimSwitch.app
# 打开第三次，相当于重启应用，这个时候你才能正确获取授权
open dist/MacVimSwitch.app
```

构建发布版本：
```bash
./build.sh --create-dmg
tccutil reset All com.jackiexiao.macvimswitch # Reset permissions
# open MacVimSwitch.dmg
```

Github Actions 工作流会在 git push --tag v1.0.0 时自动构建

如果想要在本地调试 Github Actions 工作流，以 mac 为例，可以使用
```
brew install act
act -l
act push -e .github/workflows/push.event.json --container-architecture linux/amd64
```

### 贡献代码

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m '添加某个很棒的特性'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 提交 Pull Request

## 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件。

# 感谢

- [macism](https://github.com/laishulu/macism) 提供的输入法切换方案
