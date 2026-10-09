# Compositor 简体中文版（非官方分支）

这是 [Compositor](https://github.com/robbietilton/Compositor) 的简体中文汉化分支，
基于上游提交 `675d8a4`（*Compositor 1.4.7*）。本仓库的 `main` 保持与上游同步，
汉化只在 `zh-Hans` 分支上，便于日后跟上游合并。

Compositor 是 [robbietilton](https://github.com/robbietilton) 用 Swift / SwiftUI 写的
macOS 图像编辑器，MIT 许可。上游目前只提供英文界面，也不接受翻译 PR，所以这是一个
自用/自建的分支，不是提交给上游的补丁。

## 汉化了什么

界面、菜单、面板、对话框、悬浮提示与无障碍朗读都已中文，术语沿用 Photoshop 简体中文版的
习惯说法（正片叠底、滤色、线性减淡(添加)、蒙版、羽化、色阶、曲线…）。

代码改动分三类，共 58 个文件、约 1,600 行：

1. **直接写在 `Text("…")` 里的文案**：这类字符串本身就是 `LocalizedStringKey`，
   SwiftUI 会自己查表，所以只需要补上语言的 `Localizable.strings`，代码不动。
2. **以字符串变量显示的文案**（工具名、混合模式名、报错信息、状态栏提示等）：
   SwiftUI 对这类字符串原样输出、不查表，因此在渲染处统一套一层
   `localizedUI()`（见 `Compositor/UI/Localization.swift`）。
3. **在代码里拼出来的文案**（"新建 曲线 调整图层"、"图层 2"）：
   改成 `String(format:)` 加模板词条，让语序可以按语言调整。

混合模式、调整图层种类这些枚举值同时是 `.comp` 工程文件里存储的标识符，所以
**存储值保持英文**，只在显示时翻译——这样中文版存出来的工程和英文版完全互通。

## 翻译表

`Tools/zh-Hans.lproj/Localizable.strings`，英文原文为 key，共 1,094 条。改词条直接改这个
文件，重新构建即可生效。

key 不是猜的：编译器有 `-emit-localized-strings` 开关（Xcode 的
`SWIFT_EMIT_LOC_STRINGS`），会导出系统**实际**会去查的字符串，含 `%lld`、`%@` 这类
占位符。`Tools/check-strings.py` 用它做双向核对：

```sh
bash Tools/build.sh            # 编译，同时导出 .stringsdata
python3 Tools/check-strings.py # 对比翻译表，列出漏翻与多余的 key
```

## 构建

```sh
bash Tools/build.sh    # 用 Xcode 的 swiftc 编译出可执行文件
bash Tools/bundle.sh   # 组装成 “Compositor 中文版.app” 并做 ad-hoc 签名
```

几点说明：

- `xcodebuild` 需要先接受 Xcode 许可协议（`sudo xcodebuild -license accept`）。
  这两个脚本不走 `xcodebuild`，而是直接调用 Xcode 工具链里的 `swiftc`，
  并用 `-plugin-path` 指向 SwiftUI 的宏插件（`@State`、`@Observable` 依赖它，
  而命令行工具不带这个插件）。
- `actool` 同样需要接受协议后才能用，所以图标和资源目录直接取自上游客
  户端（放在 `Tools/upstream-resources/`，MIT 许可的同一份资源）。
- 自动更新（Sparkle）被替换为 `Tools/SparkleStub/`，否则它会把中文版
  更新回英文版。

## 已知限制

- 只覆盖 1.4.7。上游 `main` 之后新增的功能（例如 Scanlines 滤镜）尚未汉化。
- 单元测试没有跑过（需要 `xcodebuild`，卡在许可协议上）。
- 图层名、项目名等用户数据保持原样，不做翻译。

## 许可

与上游相同，MIT —— 见 [LICENSE](LICENSE)。
Copyright (c) 2026 Wonder Assembly LLC（原作者）。
