# Flameshot AI 中文智能版

> 本项目是在开源截图工具 [Flameshot](https://github.com/flameshot-org/flameshot) 基础上的二次开发，当前代码基于 Flameshot 12.1.0。原项目的功能、文档和贡献者信息请访问 [flameshot-org/flameshot](https://github.com/flameshot-org/flameshot)。本仓库不是 Flameshot 官方发行版。

## 新增功能

| 功能 | 说明 | 数据处理 |
| --- | --- | --- |
| 多语言界面 | 默认跟随操作系统语言，并修复 macOS `zh-Hans-CN` 无法匹配简体中文资源的问题 | 本机 |
| 截图翻译 | 先使用 macOS Vision 识别选区文字，再调用 OpenAI、DeepSeek 或其他兼容服务翻译为中文 | 图片本机处理；识别出的文字会发给 API |
| 二维码识别 | 使用 macOS Vision 识别截图选区内的二维码，并支持复制结果 | 本机 |
| AI 总结 | OCR 后调用兼容 OpenAI Responses API 的服务生成中文摘要 | 图片本机处理；识别出的文字会发给 API |
| 智能磁吸选区 | 自动识别控件、对话框、App 窗口和屏幕；无辅助功能权限时回退到窗口 | 本机 |
| GIF 录制 | 将选区录制为 GIF，可设置帧率、尺寸、循环、光标和时长 | 本机 |
| MP4 视频录制 | H.264/HEVC、帧率、尺寸、码率、系统声音、麦克风和暂停继续 | 本机 |
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

生成结果位于 `build-smart/src/flameshot.app`。安装脚本会将其复制为 `/Applications/Flameshot AI.app`。应用采用本机临时签名，未经过 Apple 公证；首次启动若被 Gatekeeper 拦截，请在“系统设置 → 隐私与安全性”中确认打开。截图前还需授予“屏幕录制”权限。智能控件磁吸会按需申请“辅助功能”权限；视频启用麦克风时才申请麦克风权限。

普通截图、OCR、翻译、二维码和 AI 总结支持 macOS 10.15+。GIF 与 MP4 录制需要 macOS 12.3+；系统声音需要 macOS 13+；鼠标点击高亮需要 macOS 15+。旧系统仍可正常使用其他功能。

## 智能选区与录制

鼠标悬停时会显示候选区域。`Tab` 向外切换，`Shift+Tab` 反向切换，单击确认；直接拖动仍是自由选区，按住 `Space` 可暂时关闭磁吸。

选区确认后，工具栏中的“录制 GIF”和“录制视频”会打开设置。录制开始前有 3 秒倒计时，录制中可暂停、继续、停止或取消；成功后可在 Finder 中查看文件。应用自身覆盖层、倒计时和控制条会从成片中排除。

## AI 配置

翻译或 AI 总结首次使用时会让你选择 OpenAI、DeepSeek 或其他 OpenAI-compatible 服务，然后输入 API 密钥。密钥仅用于当前进程，不写入配置文件。文字输入、翻译、二维码识别、AI 总结分别使用 `T`、`L`、`Q`、`U`，并有不同图标。

OpenAI 环境变量：

```sh
export OPENAI_API_KEY="你的密钥"
export OPENAI_MODEL="gpt-5.6-terra"
# 可选，默认为 https://api.openai.com/v1
export OPENAI_BASE_URL="https://api.openai.com/v1"
```

DeepSeek 只需设置：

```sh
export DEEPSEEK_API_KEY="你的 DeepSeek 密钥"
```

默认使用 `https://api.deepseek.com/v1` 和 `deepseek-chat`。其他兼容服务可使用：

```sh
export AI_API_KEY="你的密钥"
export AI_BASE_URL="https://服务地址/v1"
export AI_MODEL="模型名称"
export AI_API_STYLE="chat_completions" # 或 responses
```

## 二次开发

仓库内提供 [`extend-flameshot-ai`](skills/extend-flameshot-ai/SKILL.md) skill，用于指导 Codex 在保持上游结构、macOS 权限行为和隐私边界的前提下继续添加或修复功能。

## 开源许可与致谢

本项目保留 Flameshot 的 [GPL-3.0 License](LICENSE)。感谢 Flameshot 项目及所有上游贡献者；二次开发时请继续遵守 GPL-3.0 的源码开放与分发要求。
