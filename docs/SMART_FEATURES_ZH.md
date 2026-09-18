# Flameshot 中文智能版（macOS）

本分支基于 Flameshot 12.1.0，增加以下能力：

- 界面默认跟随操作系统语言；修复 macOS `zh-Hans-CN` 无法匹配简体中文翻译的问题，并将 `.qm` 翻译文件复制到 App Resources。
- 在截图选区工具栏中增加“翻译”“二维码”“AI 总结”“录制 GIF”和“录制视频”入口。
- 使用 macOS Vision 在本机执行中英文 OCR 和二维码识别。
- 翻译和总结支持 OpenAI、DeepSeek 以及提供 OpenAI-compatible Chat Completions 接口的其他服务，只发送 OCR 识别出的文字，不上传截图。
- 使用辅助功能 API 与窗口列表实现控件、对话框、窗口和屏幕磁吸。
- 使用 ScreenCaptureKit、ImageIO 和 AVFoundation 原生录制 GIF 与 MP4，不依赖 FFmpeg。

## 使用

截取并选中区域后，点击工具栏对应按钮。二维码结果可直接复制。文字输入、翻译、二维码和 AI 总结分别使用独立图标，默认快捷键依次为 `T`、`L`、`Q`、`U`。

首次使用翻译或 AI 总结时，程序会让你选择 OpenAI、DeepSeek 或其他兼容服务，然后输入 API 密钥。密钥仅用于该次运行，不写入配置文件。

也可以在启动 Flameshot 前设置：

```sh
export OPENAI_API_KEY="你的密钥"
export OPENAI_MODEL="gpt-5.6-terra"
```

可选的 `OPENAI_BASE_URL` 默认为 `https://api.openai.com/v1`。

使用 DeepSeek：

```sh
export DEEPSEEK_API_KEY="你的 DeepSeek 密钥"
```

默认地址为 `https://api.deepseek.com/v1`，默认模型为 `deepseek-chat`。其他兼容服务可设置 `AI_API_KEY`、`AI_BASE_URL`、`AI_MODEL`，以及 `AI_API_STYLE=chat_completions`；兼容 OpenAI Responses API 时可将最后一项设为 `responses`。

## 智能磁吸与录制

鼠标悬停时优先选择最小有效控件；`Tab` 向外切换，`Shift+Tab` 反向切换，单击采用候选区域，拖动仍使用自由选区，按住 `Space` 暂停磁吸。辅助功能权限仅用于读取元素角色和边界；未授权时仍提供窗口和屏幕级磁吸。

GIF 支持 5/10/15/20 FPS、原始/1080/720/50%/自定义尺寸、循环次数、光标和最长 120 秒。MP4 支持 H.264/HEVC、15/24/30/60 FPS、分辨率、码率、系统声音、麦克风以及暂停/继续。设置会持久化，但不会保存录音或权限数据。

录制依赖 macOS 12.3+；系统声音依赖 macOS 13+；鼠标点击高亮依赖 macOS 15+。普通截图与智能功能保持 macOS 10.15+ 兼容。成片会排除 Flameshot AI 自身进程窗口。

## 构建

需要 macOS 10.15 或更高版本、Apple Command Line Tools、CMake、Qt 5（含 LinguistTools）以及 `macdeployqt`。执行：

```sh
./scripts/build-macos-intel.sh
```

生成的应用位于 `build-smart/src/flameshot.app`。构建脚本面向当前 Intel Mac，部署目标为 macOS 10.15。

## 隐私边界

- OCR：本机处理。
- 二维码：本机处理。
- 翻译/总结：截图不离开本机，但 OCR 得到的文字会发送给用户选择的 AI API 服务。
- GIF/视频：本机编码并保存；麦克风只在用户明确开启时采集。
- 智能选区：只读取界面元素边界和角色，不读取控件文字。
- API 密钥：程序不保存。若使用环境变量，则由用户自己的 shell 环境管理。
