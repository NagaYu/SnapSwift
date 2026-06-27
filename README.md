<div align="center">

# 🪄 SnapSwift

**Turn UI screenshots into clean SwiftUI code — 100% on your Mac.**
**UIのスクリーンショットから、綺麗なSwiftUIコードを生成。すべてオンデバイスで。**

[![Platform](https://img.shields.io/badge/platform-macOS%2026%2B-black?logo=apple)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6-orange?logo=swift)](https://swift.org)
[![Apple Intelligence](https://img.shields.io/badge/Powered%20by-FoundationModels-blue)](https://developer.apple.com/documentation/foundationmodels)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

CLI **and** native desktop app · No API keys · No cloud · No data leaves your machine

</div>

---

## English

### ✨ What is SnapSwift?

SnapSwift looks at a screenshot of a UI — a login screen, a card, a settings page — and writes the **SwiftUI code** to rebuild it. Everything runs locally on Apple Silicon using:

- 🧠 **FoundationModels** — Apple's on-device language model (the same one behind Apple Intelligence) generates the SwiftUI, guided by a "senior SwiftUI engineer" persona and structured output.
- 👁️ **Vision** — Apple's on-device image framework reads the screenshot's text, layout, font sizes, and colors first, then hands that structured description to the model.

It ships as two interfaces from **one shared core** (`SnapSwiftKit`):

| | |
|---|---|
| 🖥️ **`snapswift` CLI** | Pipe a screenshot in, get streamed, syntax-highlighted SwiftUI out — or save straight to a `.swift` file. |
| 🪟 **SnapSwift.app** | Drag-and-drop a screenshot, watch the code generate live, copy with one click. |

### 🔒 Privacy first

There is **no network code in SnapSwift at all.** The screenshot, the analysis, and the generated code never leave your Mac. No accounts, no API keys, no telemetry. That makes it safe for confidential designs, NDA work, and offline use.

### 🧩 How it works

```
 screenshot.png
      │
      ▼
┌──────────────┐   recognized text + boxes        ┌──────────────────┐
│   Vision     │   font sizes + color palette      │  FoundationModels │
│  (on-device) │ ───────────────────────────────▶ │   (on-device LLM) │
└──────────────┘        UIDescription              └──────────────────┘
                                                            │
                                                            ▼
                                                  clean SwiftUI + #Preview
```

> **A note on "multimodal":** As of macOS 26, the public `FoundationModels` on-device model is **text-only** — it cannot take an image directly. SnapSwift bridges that gap with **Vision**: it extracts a precise, structured description of the screenshot and feeds *that* to the model. The `CodeGenerator` and `UIAnalyzer` are protocols, so if Apple ships a multimodal endpoint later, it drops straight in — no changes to the app or CLI.

### 📦 Requirements

- macOS **26 (Tahoe)** or later, Apple Silicon
- **Apple Intelligence enabled**: System Settings → *Apple Intelligence & Siri* → turn on
- To **build from source**: Xcode 26+ (the `FoundationModels` Swift macros require the full Xcode toolchain, not just Command Line Tools)

### 🚀 Install & Use — CLI

```bash
git clone https://github.com/<you>/SnapSwift.git
cd SnapSwift
swift build -c release

# stream syntax-highlighted SwiftUI to the terminal
.build/release/snapswift Examples/login.png

# save directly to a file
.build/release/snapswift Examples/login.png -o LoginView.swift

# add a hint
.build/release/snapswift dashboard.png --hint "use a dark theme" -o Dashboard.swift
```

| Flag | Description |
|------|-------------|
| `<image>` | Path to the screenshot (`.png`, `.jpg`, `.heic`, `.tiff`) |
| `-o, --output <file>` | Write SwiftUI to a file instead of the terminal |
| `--hint <text>` | Extra guidance for the model |
| `--analyze-only` | Run only the Vision stage and print detected layout as JSON (no model needed) |
| `-v, --verbose` | Print what Vision detected (to stderr) |
| `--no-color` | Disable ANSI colors |

### 🖱️ Install & Use — Desktop app

```bash
./build.sh --dmg      # produces dist/SnapSwift.app and dist/SnapSwift-x.y.z.dmg
open dist/SnapSwift.app
```

1. **Drag** a screenshot onto the left panel (or click *Choose Image…*).
2. Press **Generate SwiftUI**.
3. Watch the code stream in on the right, then hit **Copy**.

> The app is **ad-hoc signed**. On first launch right-click → **Open** to bypass Gatekeeper. For public distribution, sign with a Developer ID and notarize (see below).

### 🛠️ Project layout

```
SnapSwift/
├── Sources/
│   ├── SnapSwiftKit/      # shared core — analyzer, generator, engine, prompts
│   ├── snapswift/         # CLI (swift-argument-parser)
│   └── SnapSwiftApp/      # macOS SwiftUI app
├── Tests/SnapSwiftKitTests/
├── Examples/              # sample screenshots
├── build.sh              # build .app / .dmg
└── Package.swift
```

The pipeline lives entirely in `SnapSwiftKit` so the CLI and the app behave identically. To experiment, swap the `UIAnalyzer` or `CodeGenerator` passed to `SnapSwiftEngine`.

### 🧪 Develop

```bash
swift test          # run the unit tests
swift run snapswift Examples/login.png
swift run SnapSwiftApp
```

### 📜 Notarization (optional, for public release)

```bash
codesign --force --options runtime --deep \
  --sign "Developer ID Application: Your Name (TEAMID)" dist/SnapSwift.app
xcrun notarytool submit dist/SnapSwift-0.1.0.dmg \
  --apple-id you@example.com --team-id TEAMID --password <app-specific-pw> --wait
xcrun stapler staple dist/SnapSwift.app
```

### 📄 License

[MIT](LICENSE) — free for personal and commercial use.

---

## 日本語

### ✨ SnapSwift とは

SnapSwift は、UIのスクリーンショット（ログイン画面・カード・設定画面など）を読み取り、それを再現する **SwiftUIコード** を自動生成するツールです。すべて Apple Silicon 上でローカルに動作します。

- 🧠 **FoundationModels** — Appleのオンデバイス大規模言語モデル（Apple Intelligence の中核）が、「シニアSwiftUIエンジニア」としての役割と構造化出力に従ってコードを生成します。
- 👁️ **Vision** — Appleのオンデバイス画像解析フレームワークが、まずスクショ内のテキスト・レイアウト・文字サイズ・カラーを抽出し、その構造化記述をモデルへ渡します。

**1つの共通コア（`SnapSwiftKit`）** から、2つのインターフェースを提供します。

| | |
|---|---|
| 🖥️ **`snapswift` CLI** | スクショを渡すと、シンタックスハイライト付きでSwiftUIをストリーミング表示。`.swift` ファイルへの直接保存も可能。 |
| 🪟 **SnapSwift.app** | スクショをドラッグ&ドロップ → コードがライブ生成 → ワンクリックでコピー。 |

### 🔒 プライバシー最優先

SnapSwift には **ネットワーク通信のコードが一切ありません。** スクリーンショットも解析結果も生成コードも、Macの外に出ることはありません。アカウント不要・APIキー不要・テレメトリなし。機密デザインやNDA案件、オフライン環境でも安心して使えます。

### 🧩 仕組み

```
 screenshot.png
      │
      ▼
┌──────────────┐   認識テキスト+座標               ┌──────────────────┐
│   Vision     │   文字サイズ+カラーパレット        │  FoundationModels │
│ (オンデバイス) │ ───────────────────────────────▶ │ (オンデバイスLLM) │
└──────────────┘        UIDescription              └──────────────────┘
                                                            │
                                                            ▼
                                            クリーンなSwiftUI + #Preview
```

> **「マルチモーダル」についての注記：** macOS 26 時点では、公開されている `FoundationModels` のオンデバイスモデルは **テキスト専用** で、画像を直接入力することはできません。SnapSwift はこのギャップを **Vision** で橋渡しします。スクショから正確で構造化された記述を抽出し、それをモデルに渡します。`CodeGenerator` と `UIAnalyzer` はプロトコルとして設計されているため、将来 Apple がマルチモーダル対応のAPIを提供すれば、アプリやCLIを変更せずそのまま差し替え可能です。

### 📦 動作要件

- macOS **26 (Tahoe)** 以降 / Apple Silicon
- **Apple Intelligence が有効** であること：システム設定 →「Apple Intelligence と Siri」→ オン
- **ソースからビルドする場合**：Xcode 26 以降（`FoundationModels` の Swift マクロは Command Line Tools 単体では動かず、完全な Xcode ツールチェーンが必要です）

### 🚀 インストール & 使い方 — CLI

```bash
git clone https://github.com/<you>/SnapSwift.git
cd SnapSwift
swift build -c release

# ターミナルにシンタックスハイライト付きで出力
.build/release/snapswift Examples/login.png

# ファイルに直接保存
.build/release/snapswift Examples/login.png -o LoginView.swift

# ヒントを追加
.build/release/snapswift dashboard.png --hint "ダークテーマで" -o Dashboard.swift
```

| オプション | 説明 |
|------|-------------|
| `<image>` | スクショのパス（`.png` / `.jpg` / `.heic` / `.tiff`） |
| `-o, --output <file>` | ターミナルではなくファイルに出力 |
| `--hint <text>` | モデルへの追加指示 |
| `--analyze-only` | Vision解析のみ実行し検出レイアウトをJSON出力（モデル不要） |
| `-v, --verbose` | Vision が検出した内容を表示（stderr） |
| `--no-color` | ANSIカラーを無効化 |

### 🖱️ インストール & 使い方 — デスクトップアプリ

```bash
./build.sh --dmg      # dist/SnapSwift.app と dist/SnapSwift-x.y.z.dmg を生成
open dist/SnapSwift.app
```

1. 左パネルにスクショを **ドラッグ&ドロップ**（または「Choose Image…」から選択）。
2. **Generate SwiftUI** を押す。
3. 右側にコードがストリーミング表示されたら **Copy** でコピー。

> アプリは **アドホック署名** です。初回起動時は右クリック →「開く」で Gatekeeper を回避してください。一般配布する場合は Developer ID 署名とノータライズを行ってください（下記参照）。

### 🛠️ ディレクトリ構成

```
SnapSwift/
├── Sources/
│   ├── SnapSwiftKit/      # 共通コア（解析・生成・エンジン・プロンプト）
│   ├── snapswift/         # CLI（swift-argument-parser）
│   └── SnapSwiftApp/      # macOS SwiftUI アプリ
├── Tests/SnapSwiftKitTests/
├── Examples/              # サンプル画像
├── build.sh              # .app / .dmg ビルド
└── Package.swift
```

パイプライン全体が `SnapSwiftKit` に集約されているため、CLIとアプリは完全に同じ挙動になります。`SnapSwiftEngine` に渡す `UIAnalyzer` / `CodeGenerator` を差し替えれば挙動を変更できます。

### 🧪 開発

```bash
swift test          # ユニットテスト実行
swift run snapswift Examples/login.png
swift run SnapSwiftApp
```

### 📜 ノータライズ（一般配布する場合・任意）

```bash
codesign --force --options runtime --deep \
  --sign "Developer ID Application: Your Name (TEAMID)" dist/SnapSwift.app
xcrun notarytool submit dist/SnapSwift-0.1.0.dmg \
  --apple-id you@example.com --team-id TEAMID --password <app固有パスワード> --wait
xcrun stapler staple dist/SnapSwift.app
```

### 📄 ライセンス

[MIT](LICENSE) — 個人・商用問わず無料で利用できます。

---

<div align="center">
<sub>Built with Swift, Vision, and Apple's on-device FoundationModels. No cloud required.</sub>
</div>
