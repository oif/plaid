<p align="center">
  <img src="icon2_zoomed.png" width="128" alt="Plaid">
</p>

<h1 align="center">Plaid</h1>

<p align="center">
  <em>Expand your brain bandwidth.</em>
</p>

<p align="center">
  <a href="https://github.com/oif/plaid/releases"><img src="https://img.shields.io/github/v/release/oif/plaid?style=flat-square" alt="Release"></a>
  <a href="https://github.com/oif/plaid/blob/main/LICENSE"><img src="https://img.shields.io/github/license/oif/plaid?style=flat-square" alt="License"></a>
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue?style=flat-square" alt="Platform">
</p>

<p align="center">
  English | <a href="README.zh-CN.md">简体中文</a>
</p>

---

Plaid is a macOS app that turns your voice into actions. Right now it's a fast, accurate voice-to-text tool — press a hotkey, speak, and text appears in whatever app you're using. The goal is to become the voice interface between you and your computer.

## Highlights

- **Flexible STT** — on-device models (SenseVoice, Whisper), Apple Speech, third-party cloud services, or Plaid Cloud — pick what fits your workflow
- **LLM post-correction** — fixes homophones, adds punctuation, cleans filler words, corrects brand names and technical terms
- **Context-aware** — sends the active app name, window title, and app category to the LLM so it can disambiguate domain-specific vocabulary
- **Custom vocabulary** — define your own terms so the corrector always gets them right
- **Audio preprocessing** — VAD skips silent recordings; optional noise suppression cleans up before transcription
- **Auto text injection** — transcribed text is typed directly into the active app via Accessibility API
- **Global hotkey** — toggle or hold-to-record, configurable key combo
- **Floating pill UI** — minimal, always-on-top recording indicator

## Quick Start

Download the latest `.dmg` from the [Releases](https://github.com/oif/plaid/releases) page, drag **Plaid.app** into `/Applications`, and launch. macOS will ask for **Microphone** and **Accessibility** permissions — both are required.

1. Open **Plaid** → it sits in the menu bar
2. Go to **Settings → Speech** and pick an STT provider
3. Press the hotkey (default: `fn Space`) → speak → release → text appears in the active app

## Speech Recognition

Plaid supports three categories of speech-to-text engines:

- **On-device** — SenseVoice and Whisper models run locally via sherpa-onnx, plus Apple's built-in speech recognition. Fully offline, no data leaves your Mac. Models can be downloaded in **Settings → Speech**.
- **Cloud services** — connect to third-party APIs like OpenAI Whisper, ElevenLabs, Soniox, GLM, or any OpenAI-compatible endpoint.
- **Plaid Cloud** — STT and LLM correction in a single round-trip, no separate LLM API key needed.

## Privacy

- **On-device engines** run entirely locally — no audio or text leaves your Mac.
- **Cloud engines** send audio to external servers. Choose local models if privacy is a priority.
- API keys are stored in macOS Keychain.

## Building from Source

```bash
git clone https://github.com/oif/plaid.git
cd plaid
open Plaid.xcodeproj
```

Build with **Xcode 15+** targeting **macOS 14.0+**. Local models are downloaded at runtime, not bundled in the repo.

## Acknowledgments

- [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) — on-device speech recognition engine
- [SenseVoice](https://github.com/FunAudioLLM/SenseVoice) — multilingual speech model by Alibaba
- [Silero VAD](https://github.com/snakers4/silero-vad) — voice activity detection

## License

[MIT](LICENSE)
