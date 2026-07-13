# MacVimSwitch

> このプロジェクトのコードは [macism](https://github.com/laishulu/macism) の部分を除き、すべて AI が生成しています。作者本人は Swift が書けません。

[中文](README.md) | [English](README_EN.md) | [日本語](README_JA.md) | [한국어](README_KO.md)

MacVimSwitch は Vim ユーザーや中国語・日本語・韓国語などの入力ソースを頻繁に切り替えるユーザーのために設計された macOS 向け入力ソース自動切り替えツールです。Esc キーでノーマルモードに戻ったときに入力ソースが依然として CJK のまま残ってしまう気まずさを防ぎます。

## 特長

- 一度インストールするだけで、複数の Vim 対応アプリにおける中英切り替え問題をまとめて解決できます。設定がとても簡単なのが他のソリューションとの大きな差です。
- Esc キーを押すと自動的に ABC 英語入力ソースへ切り替えます。対象のアプリを複数指定することもできます（例：VSCode、Terminal、Obsidian、Cursor、Xcode）。
- Shift キーで ABC 英語入力ソースと中国語・日本語・韓国語・ベトナム語などの入力ソースを切り替えます。
  - 任意の CJKV 入力ソースに対応しています（例：搜狗、訊飛、WeChat、Google 日本語入力、韓国語の 2-Set など）。
  - 事前に入力ソース側の「Shift で中英を切り替える」などの設定を無効にしておくと衝突を避けられます。
- Shift キーを使いたくない場合は、macOS 標準の機能として CapsLock の短押しで入力ソース切り替え、長押しで大文字固定ができます。
- 推奨：アプリごとに既定の入力ソースを設定できる [inputsource.pro](https://inputsource.pro/) のようなツールと併用するとさらに快適です。たとえばブラウザではデフォルトを中国語、Vim では英語に設定できます。
- 紹介動画：https://www.bilibili.com/video/BV1DRwTeKEcx/

<img width="383" alt="Image" src="https://github.com/user-attachments/assets/0eb4b7a0-c229-4334-b1ff-cd78dd477196" />

## v0.7.7 の重要な変更

- Shift で CJKV 入力ソースへ戻した直後、最初の一文字だけ ABC で入力されることがある問題を修正しました。
- 切り替え中のキーイベントを一時保存し、入力ソースが安定してから元の順序で再生するため、Shift の直後から待たずに入力できます。
- 約 0.1～0.2 秒の切り替え中は、メニューバーに短い状態表示が出ます。
- v0.7.6 は起動時または「アップデートを確認」からこのバージョンを検出し、ダウンロードボタンから最新版 DMG を開けます。

## v0.7.6 の重要な変更

- Shift は macOS 標準の「前の入力ソースを選択」を使い、以前の CJKV 入力ソースとテキスト入力セッションを復元します。メニューバーだけ切り替わり、実際の入力が英語のままになる問題を修正しました。
- 更新確認は GitHub の匿名 API 制限に依存せず、最新版 DMG を直接ダウンロードできるようになりました。
- リリースは Developer ID Application で署名し、Apple の公証を受けます。Bundle ID は `com.jackiexiao.macvimswitch` のままです。
- v0.7.6 以降の正式署名版同士の更新では、アクセシビリティ権限を毎回付与し直す必要はありません。古い ad-hoc 署名版からの初回移行時のみ、再認可が一度必要になる場合があります。

## インストール方法

### 手動インストール
[GitHub Releases](https://github.com/Jackiexiao/macvimswitch/releases) からダウンロードして手動でインストールします。

### Homebrew
```shell
brew tap Jackiexiao/tap
brew install --cask macvimswitch
```

## 使い方

1. 初回起動:
   - アプリを解凍して MacVimSwitch を開く
   - 表示に従ってアクセシビリティ権限を付与する
   - システム設定 → セキュリティとプライバシー → プライバシー → アクセシビリティ を開く
   - MacVimSwitch を追加して有効にする
   - アプリを再起動する（メニューバーにアイコンが表示されます）

2. 初期設定のポイント:
   - 入力ソース側の「Shift で英語と中国語を切り替える」等のオプションを無効にして衝突を避ける
   - ステータスメニューから好みの CJK 入力ソースを選択する
   - macOS の「前の入力ソースを選択」キーボードショートカットを有効にする（初期状態では有効）。「設定 → キーボード → ショートカット → 入力ソース」にあります。
   - ショートカットの内容は任意で構いません。macism がその内容を読み取り、必要に応じてエミュレーションでトリガーします。とにかくショートカットが有効化されていることが重要です。

3. メニューバー項目:
   - メニューバーのキーボードアイコンをクリックすると以下が可能です。
     - 使い方の確認
     - 好みの CJK 入力ソースを選択
     - Shift キー切り替え機能のオン/オフ
     - Esc キーによる切り替えを有効にするアプリを選択（複数選択可。デフォルトでは Terminal、VSCode、MacVim、Windsurf、Obsidian、Warp で有効）
     - ログイン時に自動起動するかどうかの切り替え
     - アプリの終了

## MacVimSwitch の利点

MacVimSwitch は他の入力ソース切り替えソリューションと比較して以下の強みがあります。

1. 高い互換性
   - VSCode、Terminal、Obsidian、Cursor、Windsurf、Warp など、あらゆるアプリで動作します。
   - アプリごとに個別の設定は不要です。
   - エディタごとに追加のプラグインを入れる必要もありません。

2. かんたんな設定
   - 対象アプリを限定することができます。
   - 好みの CJK 入力ソース（搜狗、訊飛、WeChat、Google 日本語入力など）を簡単に指定できます。

3. その他のソリューションとの比較
- [この記事](https://jdhao.github.io/2021/02/25/nvim_ime_mode_auto_switch/) では多くの Vim 用 CJK 入力切り替えツールがまとめられていますが、多くは追加設定が必要で、すべてのアプリで使えないのが課題です。
- [smartim](https://github.com/ybian/smartim) は Mac の Vim（プラグイン対応版）で動作しますが、複数のアプリでは使えません。
- [imselect](https://github.com/daipeihust/im-select) はコマンドラインで入力ソースを切り替えます。複数アプリで使うにはそれぞれに追加設定が必要で、遅延が大きい場合があります。
- [vim-xkbswitch](https://github.com/lyokha/vim-xkbswitch) は Vim プラグインで、複数アプリで使うにはやはり追加設定が必要です。
- Karabiner：ショートカットをカスタマイズできますが、遅延や設定の難しさがあります。

## 開発者向けガイド

### リリース手順

1. GitHub リポジトリを作成
```bash
# 1. github.com/jackiexiao/macvimswitch に新しいリポジトリを作成
# 2. リポジトリをクローンして初期化
git clone https://github.com/jackiexiao/macvimswitch.git
cd macvimswitch
```

2. リリースファイルを準備
```bash
# 必要なファイルを追加
git add macvimswitch.swift README.md README_CN.md LICENSE
git commit -m "Initial commit"
git push origin main
```

3. リリースを作成
```bash
# バージョンにタグを付ける
git tag -a v1.0.0
git push origin v1.0.0
```
GitHub Actions ワークフローが自動で以下を実行します:
- アプリをビルド
- アプリケーションパッケージ（.app）とソースコード（.tar.gz）を含むリリースを作成
- Homebrew Formula 更新用の SHA256 を計算して表示

4. Homebrew Tap を作成
```bash
# 1. （未作成の場合）github.com/jackiexiao/homebrew-tap を作成
# 2. リポジトリをクローン
git clone https://github.com/jackiexiao/homebrew-tap.git
cd homebrew-tap

# 3. GitHub Release で公開された SHA256 を使用して macvimswitch.rb を更新
# 4. Formula をコミットしてプッシュ
git add macvimswitch.rb
git commit -m "MacVimSwitch formula を v1.0.0 に更新"
git push origin main
```

### ローカル開発

ローカルでビルドとテストを行うには:
```bash
./build.sh
pkill -f MacVimSwitch
# 手動テスト方法1:
./dist/MacVimSwitch.app/Contents/MacOS/MacVimSwitch

# 手動テスト方法2:
# dist/MacVimSwitch.app をダブルクリックで開く場合は以下を実行
# 1回目の起動で以前の権限を削除
open dist/MacVimSwitch.app
# 2回目の起動で権限を付与
open dist/MacVimSwitch.app
# 3回目の起動で通常通り動作
open dist/MacVimSwitch.app
```

リリース用ビルド:
```bash
./build.sh --create-dmg
tccutil reset All com.jackiexiao.macvimswitch # 権限をリセット
# open MacVimSwitch.dmg
```

`git push --tag v1.0.0` を実行すると GitHub Actions ワークフローが自動的にビルドを行います。

macOS で GitHub Actions ワークフローをローカルでデバッグしたい場合は次を利用できます:
```
brew install act
act -l
act push -e .github/workflows/push.event.json --container-architecture linux/amd64
```

### コントリビュート

1. このリポジトリを Fork する
2. フィーチャーブランチを作成する (`git checkout -b feature/amazing-feature`)
3. 変更をコミットする (`git commit -m '素晴らしい機能を追加'`)
4. ブランチをプッシュする (`git push origin feature/amazing-feature`)
5. Pull Request を作成する

## ライセンス

本プロジェクトは MIT ライセンスで提供されています。詳しくは [LICENSE](LICENSE) をご覧ください。

## 謝辞

- 入力ソース切り替えソリューションを提供してくれた [macism](https://github.com/laishulu/macism)
