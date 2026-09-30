# 决策记录（ADR 精简版）

> 本文件记录**已拍板**的工程决策。设计层面的决策见设计文档 §15。
> 新增决策请追加，不要覆盖历史。

---

## 阶段 0 决策

### D1 · GitHub 仓库可见性 —— 私有
- **日期**：2026-09-30
- **决策**：`wosongshatang/ssl_wb_kh` 使用**私有**仓库。
- **理由**：开发期代码未定型，避免公开暴露设计细节。

### D2 · 代码推送方式 —— **SSH（修订）**
- **日期**：2026-09-30（初版） / 2026-09-30（修订）
- **初版决策**：因 `github.com:443` 不可达，改用 GitHub 连接器推送。
- **修订原因**：实测发现 **SSH 通道完全可用**——
  - `github.com:22` TCP 可达，`ssh -T git@github.com` 认证成功（身份 `wosongshatang`）
  - 本机 `~/.ssh/id_rsa` 已存在且**已绑定到 GitHub 账号**
  - 而连接器走的是 GitHub App（`Resource not accessible by integration`），
    对私有仓库无访问权、无建仓权，且无法自行授予
- **最终决策**：**使用 SSH 走标准 git 流程**，remote 为
  `git@github.com:wosongshatang/ssl_wb_kh.git`。
- **实测结果**：`git push -u origin main` 成功，远端 `refs/heads/main = 0270e82`。
- **网络现状备忘**：

| 通道 | 状态 | 用途 |
|---|---|---|
| `github.com:443` (HTTPS) | ❌ 不可达 | 不能用 `git push` over HTTPS |
| `github.com:22` (SSH) | ✅ 可达 | **主力通道** |
| `ssh.github.com:443` (SSH) | ✅ TCP 可达 | SSH 22 被封时的备用 |
| `api.github.com` | ✅ 可达 | REST API / 元数据查询 |
| `codeload.github.com` | ✅ 可达（慢） | 下载第三方仓库压缩包 |

- **GitHub 连接器定位（修订）**：仅用于**只读查询**（查仓库/分支/文件/搜索）。
  写操作一律走本地 git + SSH。


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
| ~~1~~ | ~~远端私有仓库对 GitHub 连接器不可见~~ | ✅ 已解决：改用 SSH 通道 |
| 2 | 项目级主题（Theme）尚未建立，UI 样式散落在各场景 | 阶段 1（战斗 UI 出现后） |
| ~~**Q1**~~ | ~~格挡清除时序~~ | ✅ **已定案 → 见 D10** |
| Q2 | Phase 1 的 `BattleManager` 与 `Creature.take_damage` 是**一次性代码**，阶段 2 会被 `DamagePipeline` 替换。不要在其上叠加功能 | 阶段 2 |

---

## 阶段 2 决策

### D10 · 格挡清除时序 —— **自身回合开始时清零**（Q1 定案）
- **日期**：2026-09-30
- **用户定案原话**：「玩家回合开始时清零，壁垒只是将本该清零的值保留一半，如果没有就是保留 0。」
- **决策**：`Creature.on_turn_start()` 第一步执行格挡清零，清零量**可被钩子改写**：
  - 钩子 `AbstractPower.at_block_clear(clearing, owner) -> int`，返回**实际清零的量**；
  - 默认返回 `clearing`（全清）；
  - **壁垒**返回 `clearing - floor(clearing / 2)`（保留一半，向下取整）。
  - 例：clearing = 5 → 保留 2、清 3；clearing = 0 → 保留 0。
- **为什么这样设计**：设计文档 §3.1 原文把改写点写在 `on_turn_end`，但若格挡在自身回合**末**清除，
  敌人回合来打时格挡已经没了，**格挡机制直接失效**。用户口径（回合开始清零 + 保留本该清零值的一半）
  在机制上与 STS 一致，且表述更精确——它明确了「保留的对象是**本该被清掉的那部分**」。
- **影响**：
  - 阶段 1 的实现方向正确；`clear_block()` 保留并升级为**可被钩子改写**。
  - 阶段 4 做壁垒时只需实现 `at_block_clear` 返回一半，**不需要动 `on_turn_end`**。
  - 设计文档 §3.1 与工程书 §3.1 中关于 `on_turn_end` 的表述**以本条为准**。

### D11 · DamageType 分流**集中在 DamagePipeline**
- **日期**：2026-09-30
- **决策**：`NORMAL / THORNS / HP_LOSS / POISON` 的修正环节分流，由 `DamagePipeline` **集中控制**，
  不在各个 Power 钩子里重复判断类型。
- **理由**：分流规则可测试、且只应存在一份。分散到每个钩子里必然漏掉某一个
  （`card-game-numerical-framework` 技能明确警告过这个陷阱）。
- **代价**：钩子无法自行决定「我要不要参与 THORNS 的修正」。
  将来若确有需要，再给 `AbstractPower` 加 `damage_types: Array[int]` 白名单字段。

### D12 · 钩子集扩展为 10 个（设计文档 §3.3 的 6 个视为下限）
- **日期**：2026-09-30
- **决策**：在 `on_turn_start / on_turn_end / at_damage_give / at_damage_receive / on_card_played / on_kill`
  之外，增加 `at_damage_final`、`modify_block`、`at_block_clear`、`prevent_hp_loss`。
- **理由**：设计文档 §10.3 的修正链本身就含 `at_damage_final_*` 环节；
  `prevent_hp_loss` 必须放在**格挡吸收之后**——缓冲要挡的是「真正会掉的血」，
  被格挡完全吃掉的攻击不该消耗缓冲层数；`at_block_clear` 是 D10 的落点。
- **原则**：钩子默认返回原值，子类只 override 关心的那个。

### D13 · 基础 Power 的文件组织
- **日期**：2026-09-30
- **决策**：`AbstractPower` 基类放 `scripts/identity/abstract_power.gd`（沿用设计文档 §10.4）；
  基础 Power（力量/敏捷/虚弱/易伤/中毒/荆棘/缓冲）集中在
  `scripts/identity/powers/base_powers.gd`，以**内部类**形式定义。
- **理由**：每个 Power 仅 15~25 行，阶段 2 就拆成 7 个文件是过度拆分。
  阶段 4~6 内容变多后若确实需要，再拆成独立文件。


