# Flameshot 中文智能版（macOS）

本分支基于 Flameshot 12.1.0，增加以下能力：

- 修复 macOS 应用包无法找到中文翻译的问题，并将 `.qm` 翻译文件复制到 App Resources。
- 在截图选区工具栏中增加“翻译”“二维码”“AI 总结”三个入口。
- 使用 macOS Vision 在本机执行中英文 OCR 和二维码识别。
- 翻译和总结通过 OpenAI Responses API 完成，只发送 OCR 识别出的文字，不上传截图。

## 使用

截取并选中区域后，点击工具栏对应按钮。二维码结果可直接复制。首次使用翻译或 AI 总结时会询问 OpenAI API 密钥，密钥仅用于该次运行，不写入配置文件。

也可以在启动 Flameshot 前设置：

```sh
export OPENAI_API_KEY="你的密钥"
export OPENAI_MODEL="gpt-5.6-terra"
```

可选的 `OPENAI_BASE_URL` 默认为 `https://api.openai.com/v1`。

## 构建

需要 macOS 10.15 或更高版本、Apple Command Line Tools、CMake、Qt 5（含 LinguistTools）以及 `macdeployqt`。执行：

```sh
./scripts/build-macos-intel.sh
```

生成的应用位于 `build-smart/src/flameshot.app`。构建脚本面向当前 Intel Mac，部署目标为 macOS 10.15。

## 隐私边界

- OCR：本机处理。
- 二维码：本机处理。
- 翻译/总结：截图不离开本机，但 OCR 得到的文字会发送给所配置的 OpenAI API 服务。
- API 密钥：程序不保存。若使用环境变量，则由用户自己的 shell 环境管理。

