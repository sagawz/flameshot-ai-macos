# Flameshot AI 中文智能版

> 本项目是在开源截图工具 [Flameshot](https://github.com/flameshot-org/flameshot) 基础上的二次开发，当前代码基于 Flameshot 12.1.0。原项目的功能、文档和贡献者信息请访问 [flameshot-org/flameshot](https://github.com/flameshot-org/flameshot)。本仓库不是 Flameshot 官方发行版。

## 新增功能

| 功能 | 说明 | 数据处理 |
| --- | --- | --- |
| 简体中文界面 | 默认启用 `zh_CN`，补齐 macOS 应用包内翻译资源与工具提示 | 本机 |
| 截图翻译 | 先使用 macOS Vision 识别选区文字，再调用兼容 OpenAI Responses API 的服务翻译为中文 | 图片本机处理；识别出的文字会发给 API |
| 二维码识别 | 使用 macOS Vision 识别截图选区内的二维码，并支持复制结果 | 本机 |
| AI 总结 | OCR 后调用兼容 OpenAI Responses API 的服务生成中文摘要 | 图片本机处理；识别出的文字会发给 API |
| macOS 体验修复 | 避免截图时切换到其他桌面，修正屏幕录制权限重复提示，并让识别错误以非阻塞方式显示 | 本机 |

详细使用和隐私说明见 [智能功能说明](docs/SMART_FEATURES_ZH.md)。

## macOS 安装说明

当前仓库提供的是**源码，不是可直接双击安装的 DMG/PKG**。克隆后需要先在 Mac 上编译。构建脚本会按本机架构生成应用，支持 Intel (`x86_64`) 和 Apple 芯片 (`arm64`)；目前实际验证环境为 Intel Mac、macOS 10.15+、Qt 5.15.2。

### 方法一：让 Codex 执行安装

仓库内提供了 [`install-flameshot-ai`](skills/install-flameshot-ai/SKILL.md) skill。让 Codex 使用该 skill，它会检查依赖、构建、安装到 `/Applications/Flameshot AI.app` 并进行验证。

### 方法二：手动安装

需要：

- macOS 10.15 或更高版本（Apple 芯片建议 macOS 11+）
- Apple Command Line Tools：`xcode-select --install`
- CMake 3.13+
- Qt 5.15.x（须包含 `macdeployqt` 与 LinguistTools）

Qt 可通过环境变量指定；脚本也会尝试查找 Homebrew 的 `qt@5`/`qt5`，以及 `~/Qt/5.15.2/clang_64`：

```sh
git clone git@github.com:sagawz/flameshot-ai-macos.git
cd flameshot-ai-macos
QT_ROOT="/你的/Qt/5.15.2/clang_64" ./scripts/install-macos.sh
```

仅构建、不安装：

```sh
QT_ROOT="/你的/Qt/5.15.2/clang_64" ./scripts/build-macos-intel.sh
```

生成结果位于 `build-smart/src/flameshot.app`。安装脚本会将其复制为 `/Applications/Flameshot AI.app`。应用采用本机临时签名，未经过 Apple 公证；首次启动若被 Gatekeeper 拦截，请在“系统设置 → 隐私与安全性”中确认打开。截图前还需授予“屏幕录制”权限。

## AI 配置

翻译或 AI 总结首次使用时会提示输入 API 密钥，密钥仅用于当前进程，不写入配置文件。也可以在启动前设置：

```sh
export OPENAI_API_KEY="你的密钥"
export OPENAI_MODEL="gpt-5.6-terra"
# 可选，默认为 https://api.openai.com/v1
export OPENAI_BASE_URL="https://api.openai.com/v1"
```

## 二次开发

仓库内提供 [`extend-flameshot-ai`](skills/extend-flameshot-ai/SKILL.md) skill，用于指导 Codex 在保持上游结构、macOS 权限行为和隐私边界的前提下继续添加或修复功能。

## 开源许可与致谢

本项目保留 Flameshot 的 [GPL-3.0 License](LICENSE)。感谢 Flameshot 项目及所有上游贡献者；二次开发时请继续遵守 GPL-3.0 的源码开放与分发要求。
