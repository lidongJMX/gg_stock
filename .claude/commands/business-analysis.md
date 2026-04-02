Run a standalone Business Model & Moat Qualitative Analysis (商业模式与护城河定性分析) on stock: $ARGUMENTS

## Input Validation
- Stock code must be a valid A-share (e.g., 600887, 000858.SZ), HK stock (00700.HK), or US stock (AAPL)
- If $ARGUMENTS is empty or invalid, ask the user for a valid stock code before proceeding
- If only digits are given, the code will be normalized by scripts/config.py

## Execution Instructions

> **⚠️ Tool constraint**: When calling the `Read` tool on any `.md` / `.json` / `.py` file, **never pass the `pages` parameter**. The `pages` parameter is only valid for PDF files and will cause an error on non-PDF files.

Read shared/qualitative/coordinator.md for the full pipeline specification, then execute each step:

### Step 1: Tushare Data Collection (Python script)
```bash
mkdir -p output/{code}_{company}
python3 scripts/tushare_collector.py --code $ARGUMENTS --output output/{code}_{company}/data_pack_market.md
```

### Step 2: WebSearch Data Supplement (Agent)
- Read shared/qualitative/data_collection.md for WebSearch instructions
- Collect: management/governance (§7), industry/competition (§8), MD&A (§10)
- Append results to data_pack_market.md

### Step 3.0: Data Pre-split (Python script)
```bash
python3 scripts/split_data_pack.py --input output/{code}_{company}/data_pack_market.md --output-dir output/{code}_{company}/data_splits/
```

### Step 3.1: Agent Team Parallel Analysis
Launch Agent A and Agent B **in parallel** (use a single message with multiple Agent tool calls):
- **Agent A** (D1+D2): Read shared/qualitative/agents/agent_a_d1d2.md + judgment_examples.md + framework_guide.md
  - Input: data_splits/d1d2_business_moat.md → Output: data_splits/agent_a_output.md
- **Agent B** (D3+D4+D5): Read shared/qualitative/agents/agent_b_d3d4d5.md + judgment_examples.md
  - Input: data_splits/d3d4d5_env_mgmt_mda.md → Output: data_splits/agent_b_output.md
- **Agent C** (D6, conditional): Only if data_splits/d6_trigger.json shows triggered=true
  - Input: data_splits/d6_holding.md → Output: data_splits/agent_c_output.md

### Step 3.2: Summary Agent (Report Assembly)
- Read shared/qualitative/agents/agent_summary.md
- Input: agent_a_output.md + agent_b_output.md + [agent_c_output.md]
- Generates: Executive Summary + Deep Conclusion (2-3 pages) + assembles final report
- Output: output/{code}_{company}/qualitative_report.md

### Step 4: Generate HTML Dashboard Report (Python script)
```bash
python3 scripts/report_to_html.py --input output/{code}_{company}/qualitative_report.md --output output/{code}_{company}/qualitative_report.html
```

## 6 Dimensions Covered
1. Business model & capital characteristics (商业模式与资本特征)
2. Competitive advantage & moat (竞争优势与护城河)
3. External environment (外部环境)
4. Management & governance (管理层与治理)
5. MD&A interpretation (MD&A 解读)
6. Holding structure analysis (控股结构分析, conditional)

## Error Recovery
- If Tushare fails → use yfinance fallback
- If WebSearch returns no results → mark as "⚠️ 数据不可用" and degrade that dimension
- Always produce a final report even with partial data

## Output
- **MD report**: output/{code}_{company}/qualitative_report.md (for strategy consumption)
- **HTML dashboard**: output/{code}_{company}/qualitative_report.html (for human reading, printable to PDF)
- MD includes: Executive Summary + 6 Dimensions + Deep Conclusion + Structured Parameters
- HTML includes: Bloomberg-style dark dashboard + KPI cards + collapsible appendix

Usage: /business-analysis 600887 or /business-analysis 00700.HK or /business-analysis AAPL
