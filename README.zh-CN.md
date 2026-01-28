# Plaid

**拓宽人机交互带宽**

一款现代化的 macOS 语音转文字应用，支持本地模型、LLM 纠错，以及简洁的悬浮胶囊界面。让语音成为比打字更快的输入方式。

<p align="center">
  <img src="icon2_zoomed.png" width="128" alt="Plaid Icon">
</p>

[English](README.md) | 简体中文

## 功能特性

- **多种语音识别引擎**
  - **本地模型** - 通过 sherpa-onnx 运行 SenseVoice (INT8/FP32)、Whisper (Tiny/Base/Small)
  - **Apple Speech** - 系统内置语音识别
  - **云端 API** - Whisper API、ElevenLabs、Soniox、GLM ASR，或自定义 OpenAI 兼容接口

- **LLM 后处理** - 可选的语法和标点纠错，支持任意 OpenAI 兼容 API

- **悬浮胶囊界面** - 极简的置顶录音指示器，带波形可视化

- **全局快捷键** - 可自定义的键盘快捷键，随时随地触发录音

- **文本注入** - 自动将转录文本输入到当前活动应用

- **隐私优先** - 本地模型完全在设备上运行，数据不离开你的 Mac

## 安装

### 下载

从 [Releases](https://github.com/oif/plaid/releases) 页面下载最新版本。

### 重要：临时信任设置

> **注意：** Apple Developer Program 续费正在进行中。在新证书签发之前，首次启动需要手动信任应用：
>
> 1. 打开下载的 `.dmg`，将 Plaid 拖入应用程序文件夹
> 2. 右键点击 Plaid.app，选择「打开」
> 3. 在安全提示中点击「打开」
>
> 这只是临时措施，再等几天。Developer Program 续费完成后，后续版本将正常签名和公证。

### 权限要求

Plaid 需要以下权限：
- **麦克风** - 用于语音录制
- **辅助功能** - 用于全局快捷键和文本注入

## 使用方法

1. **设置语音引擎** - 在 设置 → Speech 中选择你偏好的语音转文字引擎
2. **配置快捷键** - 在 设置 → General 中设置触发按键
3. **开始录音** - 按下快捷键或点击菜单栏图标
4. **说话** - 你的语音会被实时转录
5. **松开** - 转录的文本会自动输入到当前应用

### 本地模型

如需离线使用，在 设置 → Speech → Local Model 中下载本地模型：
- **SenseVoice INT8** (228 MB) - 推荐，支持中文、英文、日语、韩语
- **SenseVoice FP32** (900 MB) - 更高精度，资源占用更大
- **Whisper Tiny/Base/Small** - 多语言支持 (99 种语言)

## 路线图

### 进行中
- [ ] Apple Developer Program 续费 & 正式代码签名

### 短期重点

**性能优化**
- [ ] 降低本地模型内存占用
- [ ] 优化冷启动时间
- [ ] 减少音频处理延迟

**识别准确度**
- [ ] 热词 / 自定义词汇表
- [ ] 更好的口音和噪音处理
- [ ] 上下文感知识别提示

**Computer Use 集成**
- [ ] 与 Claude computer use 深度集成
- [ ] 应用感知的上下文注入
- [ ] 语音到操作的流畅工作流

## 从源码构建

```bash
git clone https://github.com/oif/plaid.git
cd plaid
open Plaid.xcodeproj
```

使用 Xcode 15+ 构建，目标 macOS 14.0+。

## 许可证

MIT License - 详见 [LICENSE](LICENSE)。

## 致谢

- [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) - 本地语音识别引擎（运行 SenseVoice 和 Whisper ONNX 模型）
- [SenseVoice](https://github.com/FunAudioLLM/SenseVoice) - 阿里巴巴多语言语音模型
