# 决策记录（ADR 精简版）

> 本文件记录**已拍板**的工程决策。设计层面的决策见设计文档 §15。
> 新增决策请追加，不要覆盖历史。

---

## 阶段 0 决策

### D1 · GitHub 仓库可见性 —— 私有
- **日期**：2026-09-30
- **决策**：`wosongshatang/ssl_wb_kh` 使用**私有**仓库。
- **理由**：开发期代码未定型，避免公开暴露设计细节。

### D2 · 代码推送方式 —— GitHub 连接器
- **日期**：2026-09-30
- **背景**：实测 `github.com:443` 在本机**不可达**（沙箱内外均失败：`CONNECT tunnel failed, response 502` / `Could not connect to server`），而 `api.github.com` 与 `codeload.github.com` 可达。
- **决策**：本地 git 做版本管理；**推送通过 GitHub 连接器**（基于 api.github.com）完成。
- **影响**：
  - `git push` / `git clone` / `git fetch` 走 HTTPS 会失败，不要依赖。
  - 拉取第三方仓库改用 `codeload.github.com` 下载压缩包。
- **复审条件**：若本机配置了可用代理或 SSH 隧道，可恢复标准 `git push` 流程。

### D3 · 测试框架 —— GUT 9.7.1
- **日期**：2026-09-30
- **决策**：通过 `codeload.github.com` 下载 GUT 发布包，解压至 `addons/gut/`（版本 9.7.1）。
- **备选（未启用）**：自研轻量测试运行器（离线零依赖）。若 GUT 后续出现兼容问题可切换。
- **验证**：`godot --headless -s addons/gut/gut_cmdln.gd -gexit` 可跑，11 个测试 / 24 断言全绿。
- **配置**：`.gutconfig.json` 指向 `res://tests/`，测试文件命名规则 `test_*.gd`。

### D4 · 渲染后端 —— GL Compatibility
- **日期**：2026-09-30
- **决策**：保持 `renderer/rendering_method="gl_compatibility"`。
- **理由**：2D 卡牌游戏无需 Forward+ 特性；GL Compatibility 兼容性最好、启动最快、导出体积最小。

---

## 阶段 0 附带决策

### D5 · 移除 `[dotnet]` 配置段
- **日期**：2026-09-30
- **决策**：从 `project.godot` 移除 `[dotnet] project/assembly_name` 段。
- **理由**：本项目纯 GDScript，不创建 C# 解决方案。移除后避免编辑器产生 C# 工程提示噪音。
- **影响**：引擎仍使用 mono 版（不影响 GDScript 运行）；若将来需要 C#，重新创建解决方案即可。

### D6 · 项目名使用 ASCII
- **日期**：2026-09-30
- **决策**：`config/name="Godslayer"`（英文），中文名《弑神律》写入 `config/description`。
- **理由**：避免导出产物文件名与跨平台路径的编码问题。窗口标题如需中文可在阶段 8 单独设置。

### D7 · 新增 `assets/` 目录
- **日期**：2026-09-30
- **决策**：在工程书 §2.1 的目录结构基础上**增加 `assets/`**（字体、图标、美术资源）。
- **理由**：原结构未包含纯资源目录。当前已放入 `assets/fonts/cjk_system_font.tres`。

### D8 · CJK 字体方案 —— SystemFont
- **日期**：2026-09-30
- **决策**：用 `SystemFont` 资源（`assets/fonts/cjk_system_font.tres`）作为项目级默认字体，注册在 `gui/theme/custom_font`。
- **理由**：Godot 内置默认字体不含 CJK 字形，中文会显示为方框。SystemFont 直接引用系统字体，**无需随包分发字体文件**。
- **字体优先级**：Microsoft YaHei UI → Microsoft YaHei → SimHei → Noto Sans CJK SC → PingFang SC → sans-serif。
- **待办**：若将来需要跨平台一致的排版效果，改为内嵌开源字体（如思源黑体）并做字体子集化。

### D9 · 严格警告模式
- **日期**：2026-09-30
- **决策**：开启 `gdscript/warnings/enable_all_warnings=true`（设计文档 §11 阶段 0 要求）。
- **影响**：生成 GDScript 时必须遵守 `gdscript-codegen` 规范的避坑清单（内置函数重名、shadow 基类属性、未用参数等）。

---

## 待决事项

| # | 事项 | 计划解决时机 |
|---|---|---|
| 1 | 远端私有仓库对 GitHub 连接器不可见（API 404） | 阶段 0 收尾前，需用户授予仓库访问权限 |
| 2 | 项目级主题（Theme）尚未建立，UI 样式散落在各场景 | 阶段 1（战斗 UI 出现后） |
