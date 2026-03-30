# 龟龟投资策略 v2.0 — 协调器（Coordinator）

> **角色**：你是项目经理。职责：(1) 验证输入并通过 AskUserQuestion 补全缺失信息；(2) 按依赖关系调度 Phase 0→1→2→3；(3) 监控 checkpoint 和超时；(4) 交付最终报告。你不执行数据采集或分析计算。
>
> Phase 0/1/2 沿用原 `prompts/` 目录指令，Phase 3 使用并行 Agent 架构（preflight → Agent A定性 + Agent B定量 → Agent C估值+报告）。

---

## 输入解析

用户输入可能包含以下组合：

| 输入项 | 示例 | 必需？ |
|--------|------|--------|
| 股票代码或名称 | `600887` / `伊利股份` / `0001.HK` / `AAPL` | 必需 |
| 持股渠道 | `港股通` / `直接` / `美股券商` | 可选（未指定则触发 AskUserQuestion） |
| PDF 年报文件 | 用户上传的 `.pdf` 文件 | 可选（未提供则触发 Phase 0） |

**解析规则**：
1. 从用户消息中提取股票代码/名称和持股渠道
2. 检查是否有 PDF 文件上传
3. 若用户只给了公司名称，在 Phase 1A 中由脚本确认代码
4. 代码格式化：A股 → `XXXXXX.SH/SZ`；港股 → `XXXXX.HK`；美股 → `AAPL.US`

---

## AskUserQuestion 交互

沿用原 `prompts/coordinator.md` 的 AskUserQuestion 规则（5个条件+不触发条件）。

---

## 阶段调度

```
┌─────────────────────────────────────────────────┐
│              用户输入解析                          │
│   股票代码 = {code}                               │
│   持股渠道 = {channel | AskUserQuestion}          │
│   PDF年报 = {有 | 无 | 自动下载}                  │
└──────────┬──────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────┐
│  Phase 0：PDF 自动获取（沿用 prompts/ 规则）       │
└──────────┬──────────────────────────────────────┘
           │
           ▼
┌─────────── Step A: Python 脚本（并行启动）──────────┐
│  Phase 1A: tushare_collector.py → data_pack_market │
│  Phase 2A: pdf_preprocessor.py → pdf_sections.json │
└───────────┬────────────────────────────────────────┘
            │
            ▼
┌─────────── Step B: Agent（Phase 1B + 2B）──────────┐
│  Phase 1B: WebSearch 补充 §7/§8/§9B/§10/§13        │
│  Phase 2B: PDF 精提取 → data_pack_report.md         │
└───────────┬────────────────────────────────────────┘
            │  等待全部完成
            ▼
┌─────────────────────────────────────────────────┐
│     Phase 3: 分析与报告（并行 Agent 架构）          │
│                                                    │
│  Step 3.0: Pre-flight（M0 数据校验）               │
│      ↓                                             │
│  Step 3.1: 并行执行                                │
│    ┌─────────────┐  ┌─────────────┐               │
│    │ Agent A 定性  │  │ Agent B 定量 │               │
│    │ (6维度)      │  │ (穿透回报率) │               │
│    └──────┬──────┘  └──────┬──────┘               │
│           └──────┬─────────┘                       │
│                  ↓                                  │
│  Step 3.2: Agent C（估值 + 报告组装）               │
│      ↓                                             │
│  输出：{公司名}_{代码}_分析报告.md                   │
└──────────┬──────────────────────────────────────┘
           │
           ▼
┌─────────────────────────────────────────────────┐
│           协调器交付                               │
│  确认报告文件已生成，返回给用户                      │
└─────────────────────────────────────────────────┘
```

---

## Sub-agent 调用指令

### 环境准备（首次运行）

```bash
pip install tushare pandas pdfplumber --break-system-packages
```

### Phase 0：PDF 自动获取

沿用原 `prompts/coordinator.md` Phase 0 规则。

### Step A：Python 脚本（Phase 1A + Phase 2A 并行）

沿用原 `prompts/coordinator.md` Step A 规则：
- Phase 1A：`python3 scripts/tushare_collector.py --code {ts_code} --output {output_dir}/data_pack_market.md`
- Phase 2A.5（可选）：TOC 定位
- Phase 2A：`python3 scripts/pdf_preprocessor.py --pdf ... --output {output_dir}/pdf_sections.json`

### Step B：Agent（Phase 1B + Phase 2B）

沿用原 `prompts/coordinator.md` Step B 规则：
- Phase 1B：读取 `prompts/phase1_数据采集.md` 执行 WebSearch 补充
- Phase 2B：读取 `prompts/phase2_PDF解析.md` 执行 PDF 精提取

> ⚠️ Phase 1/2 的 prompt 文件仍从原 `prompts/` 目录读取，未修改。

### Phase 3：分析与报告（并行 Agent 架构）

等待 Phase 1 + Phase 2 全部完成后启动。

**条件加载规则**（协调器在启动 Agent A/B 时根据股票代码判断）：
- 港股 (.HK) → Agent A/B prompt 中额外指令：`同时加载 references/market_rules_hk.md`
- 美股 (.US) → Agent A/B prompt 中额外指令：`同时加载 references/market_rules_us.md`
- A股 → 无额外加载（默认路径，节省 context）

**所有 Agent 共享加载**：
- `references/judgment_examples.md` — 关键判断锚点（G系数、护城河、分配意愿等）
- `references/factor_interface.md` — 参数传递 schema（Agent A/B 输出末尾附校验块）

```
# === Step 3.0: Pre-flight（数据校验 + 口径锚定）===
Task(
  subagent_type = "general-purpose",
  prompt = """
  请阅读 {prompts_v2_dir}/phase3_preflight.md 中的完整指令。

  数据包文件：
    - {output_dir}/data_pack_market.md
    - {output_dir}/data_pack_report.md（若存在）
    - {output_dir}/data_pack_report_interim.md（若存在）

  将 pre-flight 输出写入：{output_dir}/phase3_preflight.md
  """,
  description = "Phase3 Pre-flight"
)

# 读取 preflight 输出，确认数据完整性
# 若关键数据（净利润、OCF、Capex）缺失 → 通知用户，分析将受限但继续

# === Step 3.1: 并行执行 Agent A + Agent B ===
# 以下两个 Task 同时启动：

Task(
  subagent_type = "general-purpose",
  prompt = """
  请阅读 {prompts_v2_dir}/phase3_qualitative.md 中的完整指令。

  数据包文件：
    - {output_dir}/phase3_preflight.md（口径决策）
    - {output_dir}/data_pack_market.md
    - {output_dir}/data_pack_report.md（若存在）
    - {output_dir}/data_pack_report_interim.md（若存在）

  将定性分析输出写入：{output_dir}/phase3_qualitative.md
  """,
  description = "Phase3 Agent A 定性分析"
)

Task(
  subagent_type = "general-purpose",
  prompt = """
  请阅读 {prompts_v2_dir}/phase3_quantitative.md 中的完整指令。

  数据包文件：
    - {output_dir}/phase3_preflight.md（口径决策）
    - {prompts_v2_dir}/references/shared_tables.md（税率/门槛/公式）
    - {output_dir}/data_pack_market.md
    - {output_dir}/data_pack_report.md（若存在）
    - {output_dir}/data_pack_report_interim.md（若存在）

  将定量分析输出写入：{output_dir}/phase3_quantitative.md
  """,
  description = "Phase3 Agent B 定量分析"
)

# 等待 Agent A + Agent B 全部完成

# === Step 3.2: Agent C（估值 + 报告组装）===
Task(
  subagent_type = "general-purpose",
  prompt = """
  请阅读 {prompts_v2_dir}/phase3_valuation.md 中的完整指令。

  输入文件：
    - {output_dir}/phase3_preflight.md（基础信息）
    - {output_dir}/phase3_qualitative.md（Agent A 定性输出）
    - {output_dir}/phase3_quantitative.md（Agent B 定量输出）
    - {output_dir}/data_pack_market.md（§11 历史价格、§17 预计算值）

  将最终报告写入：{output_dir}/{company}_{code}_分析报告.md
  """,
  description = "Phase3 Agent C 估值与报告"
)
```

### 当没有 PDF 年报时

Phase 1B/2B 的降级逻辑不变（沿用原规则）。Phase 3 的 Agent A/B 自动处理缺失的 data_pack_report.md。

---

## 报表时效性规则

沿用原 `prompts/coordinator.md` 报表时效性规则（年报年份判断 + 中报触发）。

---

## 阶段超时规则

| 阶段 | 最大执行时间 | 超时行为 |
|------|------------|---------|
| Phase 0 PDF下载 | 3分钟 | 进入无PDF模式 |
| Phase 1A Tushare | 2分钟 | 部分降级 |
| Phase 1B WebSearch | 5分钟 | 已完成项保留 |
| Phase 2A PDF预处理 | 3分钟 | 进入无PDF模式 |
| Phase 2B PDF精提取 | 3分钟 | 已提取项保留 |
| Phase 3.0 Pre-flight | 1分钟 | 使用默认口径 |
| Phase 3.1 Agent A | 8分钟 | 已完成维度保留 |
| Phase 3.1 Agent B | 8分钟 | 已完成步骤保留 |
| Phase 3.2 Agent C | 5分钟 | 输出已有结论 |

总管线预计最大执行时间 ≤ 25分钟。

---

## 异常处理

沿用原 `prompts/coordinator.md` 异常处理规则。

---

## 文件路径约定

**变量定义**：
- `{workspace}` = 项目根目录
- `{prompts_dir}` = `{workspace}/prompts`（Phase 1/2 prompt）
- `{prompts_v2_dir}` = `{workspace}/prompts_v2`（Phase 3 prompt）
- `{output_dir}` = `{workspace}/output/{代码}_{公司}`

```
{workspace}/
├── prompts/                          ← Phase 0/1/2 prompt（沿用）
│   ├── coordinator.md                ← 原协调器（v1 参考）
│   ├── phase1_数据采集.md
│   ├── phase2_PDF解析.md
│   └── references/
├── prompts_v2/                       ← Phase 3 prompt（v2 简化版）
│   ├── coordinator.md                ← 本文件
│   ├── phase3_preflight.md           ← Step 3.0 数据校验
│   ├── phase3_qualitative.md         ← Step 3.1 Agent A 定性
│   ├── phase3_quantitative.md        ← Step 3.1 Agent B 定量
│   ├── phase3_valuation.md           ← Step 3.2 Agent C 估值+报告
│   └── references/
│       ├── shared_tables.md          ← 共享参数表（税率/门槛/公式）
│       ├── judgment_examples.md      ← 判断锚点示例（G系数/护城河/分配意愿）
│       ├── factor_interface.md       ← 因子间参数传递 schema
│       ├── market_rules_hk.md        ← 港股特别规则（条件加载）
│       └── market_rules_us.md        ← 美股特别规则（条件加载）
└── output/                           ← 运行时输出
    └── {code}_{company}/
        ├── data_pack_market.md       ← Phase 1 输出
        ├── data_pack_report.md       ← Phase 2 输出（若有）
        ├── phase3_preflight.md       ← Step 3.0 输出
        ├── phase3_qualitative.md     ← Agent A 输出
        ├── phase3_quantitative.md    ← Agent B 输出
        └── {company}_{code}_分析报告.md ← 最终报告
```

---

## 数据约定

沿用原 `prompts/coordinator.md` 数据约定（金额百万元、格式化规则、Phase 0 重试规则）。

---

*龟龟投资策略 v2.0 | 简化版协调器 | Coordinator*
