<p align="center">
  <img src="icon2_zoomed.png" width="128" alt="Plaid">
</p>

<h1 align="center">Plaid</h1>

<p align="center">
  <em>拓展你的大脑带宽。</em>
</p>

<p align="center">
  <a href="https://github.com/oif/plaid/releases"><img src="https://img.shields.io/github/v/release/oif/plaid?style=flat-square" alt="Release"></a>
  <a href="https://github.com/oif/plaid/blob/main/LICENSE"><img src="https://img.shields.io/github/license/oif/plaid?style=flat-square" alt="License"></a>
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue?style=flat-square" alt="Platform">
</p>

<p align="center">
  <a href="README.md">English</a> | 简体中文
</p>

---

Plaid 是一款 macOS 应用，让你的声音变成操作。现在，它是一个快速精准的语音转文字工具 — 按下快捷键、说话、文本就出现在你正在使用的应用中。目标是成为你与电脑之间的语音交互入口。

## 亮点

- **灵活的 STT** — 本地模型（SenseVoice、Whisper）、Apple Speech、第三方云服务，或 Plaid Cloud — 选择适合你的方式
- **LLM 后处理纠错** — 修正同音字、补全标点、清理口语填充词、纠正品牌名和技术术语
- **上下文感知** — 将当前应用名、窗口标题和应用类别发送给 LLM，帮助消解领域相关的歧义
- **自定义词表** — 定义你的专有术语，确保纠错器始终拼写正确
- **音频预处理** — VAD 跳过静音录制；可选降噪在转录前清理音频
- **自动文本注入** — 通过 Accessibility API 将转录文本直接输入到当前应用
- **全局快捷键** — 切换或按住录制，可自定义组合键
- **悬浮胶囊 UI** — 极简、置顶的录制状态指示器

## 快速开始

从 [Releases](https://github.com/oif/plaid/releases) 页面下载最新 `.dmg`，将 **Plaid.app** 拖入 `/Applications`，启动即可。macOS 会请求**麦克风**和**辅助功能**权限 — 两者都是必需的。

1. 打开 **Plaid** → 它会常驻在菜单栏
2. 进入 **设置 → Speech**，选择一个 STT 引擎
3. 按下快捷键（默认：`fn Space`）→ 说话 → 松开 → 文本出现在当前应用中

## 语音识别

Plaid 支持三类语音转文字引擎：

- **本地** — SenseVoice 和 Whisper 模型通过 sherpa-onnx 在本地运行，加上 Apple 内置语音识别。完全离线，数据不离开你的 Mac。模型可在 **设置 → Speech** 中下载。
- **云服务** — 接入第三方 API，如 OpenAI Whisper、ElevenLabs、Soniox、GLM，或任何 OpenAI 兼容接口。
- **Plaid Cloud** — STT 和 LLM 纠错在一次往返中完成，无需单独配置 LLM API Key。

## LLM 纠错

启用后，STT 的原始输出会发送给 LLM（OpenAI 或任何 OpenAI 兼容接口）进行后处理纠错：

- 修正中文语音识别中常见的同音字错误
- 纠正品牌名和技术术语（如 `cloudflare` → `Cloudflare`）
- 补全标点符号、清理填充词和口误重启
- 识别说话人的自我纠正（"不对，应该是..."）

系统 Prompt 和用户 Prompt 可在 **设置 → Speech** 中完全自定义。

## 隐私

- **本地引擎** 完全在设备端运行 — 音频和文本不会离开你的 Mac。
- **云端引擎** 会将音频发送到外部服务器。如果隐私是首要考虑，请选择本地模型。
- API Key 存储在 macOS 钥匙串中。

## 从源码构建

```bash
git clone https://github.com/oif/plaid.git
cd plaid
open Plaid.xcodeproj
```

使用 **Xcode 15+** 构建，目标 **macOS 14.0+**。本地模型在运行时下载，不包含在仓库中。

## 致谢

- [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) — 本地语音识别引擎
- [SenseVoice](https://github.com/FunAudioLLM/SenseVoice) — 阿里巴巴多语言语音模型
- [Silero VAD](https://github.com/snakers4/silero-vad) — 语音活动检测

## 许可证

[MIT](LICENSE)
