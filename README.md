# Plaid

A modern macOS voice-to-text application with local model support, LLM correction, and a sleek floating pill interface.

<p align="center">
  <img src="icon2_zoomed.png" width="128" alt="Plaid Icon">
</p>

## Features

- **Multiple STT Providers**
  - **Local Models** - SenseVoice (INT8/FP32), Whisper (Tiny/Base/Small) via sherpa-onnx
  - **Apple Speech** - Built-in macOS speech recognition
  - **Cloud APIs** - Whisper API, ElevenLabs, Soniox, GLM ASR, or custom OpenAI-compatible endpoints

- **LLM Post-Processing** - Optional grammar and punctuation correction using any OpenAI-compatible API

- **Floating Pill Interface** - Minimal, always-on-top recording indicator with waveform visualization

- **Global Hotkey** - Trigger recording from anywhere with a customizable keyboard shortcut

- **Text Injection** - Automatically paste transcribed text into the active application

- **Privacy First** - Local models run entirely on-device, no data leaves your Mac

## Installation

### Download

Download the latest release from the [Releases](https://github.com/oif/plaid/releases) page.

### Important: Temporary Trust Requirement

> **Note:** Apple Developer Program renewal is currently in progress. Until the new certificate is issued, you'll need to manually trust the app on first launch:
>
> 1. Open the downloaded `.dmg` and drag Plaid to Applications
> 2. Right-click (or Control-click) on Plaid.app and select "Open"
> 3. Click "Open" in the security dialog
>
> This will only be necessary for a few more days. Once the Developer Program renewal completes, future releases will be properly signed and notarized.

### Permissions

Plaid requires the following permissions:
- **Microphone** - For voice recording
- **Accessibility** - For global hotkey and text injection

## Usage

1. **Set up STT Provider** - Choose your preferred speech-to-text provider in Settings → Speech
2. **Configure Hotkey** - Set your preferred trigger key in Settings → General
3. **Start Recording** - Press the hotkey or click the menu bar icon
4. **Speak** - Your voice will be transcribed in real-time
5. **Release** - The transcribed text will be automatically typed into the active app

### Local Models

For offline usage, download a local model in Settings → Speech → Local Model:
- **SenseVoice INT8** (228 MB) - Recommended for Chinese, English, Japanese, Korean
- **SenseVoice FP32** (900 MB) - Higher accuracy, more resource intensive
- **Whisper Tiny/Base/Small** - Multilingual support (99 languages)

## Roadmap

### In Progress
- [ ] Apple Developer Program renewal & proper code signing

### Short-term Focus

**Performance**
- [ ] Reduce memory footprint for local models
- [ ] Improve cold start time
- [ ] Optimize audio pipeline latency

**Recognition Accuracy**
- [ ] Hot words / custom vocabulary support
- [ ] Better accent and noise handling
- [ ] Context-aware recognition hints

**Computer Use Integration**
- [ ] Tighter integration with Claude computer use
- [ ] App-aware context injection
- [ ] Streamlined voice-to-action workflows

## Building from Source

```bash
git clone https://github.com/oif/plaid.git
cd plaid
open Plaid.xcodeproj
```

Build with Xcode 15+ targeting macOS 14.0+.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) - Local speech recognition engine (runs SenseVoice & Whisper ONNX models)
- [SenseVoice](https://github.com/FunAudioLLM/SenseVoice) - Alibaba's multilingual speech model
