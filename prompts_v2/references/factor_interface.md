# 因子间参数传递接口（Factor Interface Schema）

> 定义 Agent 间显式传递的参数名、类型和来源。消除"传递了什么"的歧义。
> Agent A/B 输出时按 schema 列出参数值，Agent C 输入时按 schema 校验。

---

## Pre-flight → Agent A / Agent B

| 参数 | 类型 | 来源 | 说明 |
|------|------|------|------|
| stock_code | string | §1 | 如 600887.SH |
| listing_structure | string | §1 | H股/红筹/开曼/A股/美股 |
| holding_channel | string | 用户输入 | 港股通/直接/美股券商 |
| report_currency | string | §1 头部 | CNY/HKD/USD |
| fx_rate | float | §1 | 跨币种时使用 |
| profit_anchor | string | preflight | GAAP归母 / 扣非归母 / 主营经营利润 |
| profit_anchor_line | string | preflight | §3 对应行项名 |
| cash_scope | string | preflight | 狭义 / 广义 |
| has_interim | bool | preflight | 是否有中期数据 |
| interim_column | string | preflight | 如 2025Q3 |
| annual_factor | float | preflight | 年化系数 (4/3 或 2) |
| seasonal_risk | string | preflight | 正常 / 高季节性行业 |
| warnings | list | preflight | §13 Warnings 摘要 |
| has_section17 | bool | preflight | §17 衍生指标是否存在 |

---

## Agent A（定性）→ Agent C

| 参数 | 类型 | 来源维度 | 说明 |
|------|------|---------|------|
| capital_intensity | enum | 维度一 | capital-light / capital-hungry |
| collection_mode | enum | 维度一 | 先款后货/订阅预收/先货后款/垫资回收 |
| moat_type | string | 维度二 | "[非技术] xxx + [技术] xxx" |
| moat_flywheel | bool | 维度二 | 是否构成复合护城河飞轮 |
| moat_rating | enum | 维度二 | 优质/中性/负面 |
| cyclicality | enum | 维度三 | 强周期/弱周期/非周期 |
| cycle_position | enum | 维度三 | 底部/中段/顶部（仅强周期） |
| management_rating | enum | 维度四 | 优秀/合格/损害价值/观察期 |
| mda_credibility | enum | 维度五 | 高/中/低 |
| mda_impact | enum | 维度五 | 正面/中性/负面 |
| holding_structure | bool | 维度六 | 是否适用控股分析 |
| sotp_discount_pct | float | 维度六 | 控股折价率（适用时） |
| competitors | list | 维度三 | 主要竞争对手列表 [{name, ticker}] |
| industry_keywords | list | 维度三 | 行业监控关键词 |

---

## Agent B（定量）→ Agent C

| 参数 | 类型 | 来源步骤 | 说明 |
|------|------|---------|------|
| market_cap_mm | float | §1 | 当前市值（百万元） |
| total_shares_mm | float | §1 | 总股本（百万股） |
| current_price | float | §1 | 最新股价 |
| net_profit_mm | float (C) | 步骤1 | 归母净利润（锚定口径） |
| da_mm | float (D) | 步骤1 | 折旧摊销 |
| capex_mm | float (E) | 步骤1 | 资本开支总额 |
| G_coefficient | float | 步骤1 | 维持性Capex系数 |
| owner_earnings_mm | float (I) | 步骤1 | OE 粗算值 |
| R_pct | float | 步骤2 | 粗算穿透回报率 |
| rf_pct | float | §14 | 无风险利率 |
| II_pct | float | 步骤2 | 门槛值 |
| Q_pct | float | shared_tables | 综合股息税率 |
| M_pct | float | 步骤5 | 支付率锚定值 |
| O_mm | float | 步骤5 | 年均注销型回购 |
| AA_mm | float | 步骤8 | 真实可支配现金结余基准 |
| AA_type | string | 步骤8 | AA_2y / AA_all / AA_excl |
| GG_pct | float | 步骤10 | 精算穿透回报率 |
| HH_pct | float | 步骤10 | 粗算偏差 R − GG |
| lambda_coeff | float | 步骤10 | 经营杠杆系数 |
| lambda_reliability | enum | 步骤10 | 正常/有一项警告/异常 |
| credibility | enum | 步骤11 | 外推可信度（高/中/低） |
| payout_willingness | enum | 步骤5 | 分配意愿（强/中/弱） |
| FF_mm | float | 步骤9 | 可自由支配现金 |
| net_cash_mm | float | 步骤9 | 广义净现金 |
| fcf_sequence | list[float] | 步骤2 | 近5年FCF序列 |
| residual_sequence | list[float] | 步骤8 | 近5年可支配现金结余序列 |

---

## 校验格式

Agent 输出末尾附参数校验块：

```
## 传递参数校验

| 参数 | 值 | 来源 |
|------|-----|------|
| market_cap_mm | 45,678.00 | §1 市值 |
| net_profit_mm | 3,456.00 | §3 归母净利润 2024列 (GAAP) |
| GG_pct | 7.85 | 步骤10 精算 |
| credibility | 高 | 步骤11 (4/5维度为高) |
| ⚠️ O_mm | 0 | §15 无回购记录 |
```

---

*龟龟投资策略 v2.0 | 因子间参数传递接口*
