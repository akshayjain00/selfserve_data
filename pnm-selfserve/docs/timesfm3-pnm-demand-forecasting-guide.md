# TimesFM 3 for PnM Demand Forecasting — a zero-to-backtest guide

**Audience:** an analyst who has never run a forecasting foundation model.
**Goal:** a backtested daily forecast of PnM leads and converted orders, at India and pickup-city level, that provably beats a dumb baseline.

> **Sourcing note (read this first).** `research.google`, `arxiv.org` and `huggingface.co` are blocked by this environment's egress proxy, so I could not open the TimesFM 3 blog, the arXiv papers or the model card directly. Everything below is grounded in (a) the **official repository README**, which I fetched in full and which is authoritative for the API and licence, and (b) **web-search retrieval** of the blog, papers and independent leaderboards, labelled "via search of X". Where sources are silent I write **[not stated in sources]**. No benchmark number, parameter count or API signature below is invented.

---

## 1. TL;DR

- **TimesFM 3 is a pretrained "foundation model" for time series** — one network trained on a huge corpus of other people's series, which forecasts *your* series with no training step. That is **zero-shot**: hand it history, get a future. ([repo README](https://github.com/google-research/timesfm))
- It is **330M parameters**, decoder-only, and the headline v3 change is **native multivariate forecasting plus covariate support** — past-only covariates and past-*and*-future covariates — with **no per-task tuning**. ([README](https://github.com/google-research/timesfm); architecture detail — 32-step patches, alternating temporal and variate attention, single-pass decoding via "contiguous patch masking" — reported via search of the [Google Research blog](https://research.google/blog/timesfm-3-a-zero-shot-foundation-model-for-multivariate-forecasting/))
- **The licence is the headline risk, not the accuracy.** The repo states plainly that TimesFM **3.0 weights are `timesfm-non-commercial-license-v1.0`, restricted to non-commercial, non-production use — "Commercial or production use of the default pretrained weights is not permitted."** Source code is Apache-2.0; weights **up to 2.5 are Apache-2.0**. ([README](https://github.com/google-research/timesfm))
- **Recommended path for Porter:** use **TimesFM 3.0 offline only**, as the yardstick that shows the ceiling. **Ship on TimesFM 2.5** (Apache-2.0, covariates via XReg), **Chronos-2** (Apache-2.0, native covariates), or **Google's hosted TimesFM** in BigQuery ML / Vertex Model Garden under Google's commercial terms. Confirm with legal before a single production DAG.
- **What it is NOT good for:** sparse/intermittent series (most small cities), hard structural breaks, anything driven mainly by causes the model cannot see (pricing changes, a marketing switch-off), and latency-critical inference — foundation-model inference runs in hundreds of milliseconds to seconds versus microseconds for gradient-boosted trees (via search of [arXiv 2605.24381](https://arxiv.org/abs/2605.24381)).
- **It will not read your festival calendar unless you feed it.** Indian moving-date festivals are a dominant PnM signal and are invisible to a model that only sees counts. Covariates are the reason to use v3-class models at all.
- **Baselines first, always.** On fev-bench, seasonal naive is *still competitive on point error* (MASE rank 5.39) while badly calibrated probabilistically (CRPS rank 9.50) — via search of [fev-bench](https://arxiv.org/abs/2509.26468). If TimesFM cannot beat lag-7 seasonal naive on your data, ship seasonal naive.
- **Leads and converted orders are two different problems.** Leads are high-volume, smooth, marketing-driven, with a clean event timestamp. Converted orders are sparser, lag behind leads, and are **right-censored** — the single biggest leakage trap here (Section 3).
- **Two of your working defaults I would change:** forecast to **h=28 days** in one call and *report* the 3-day and 7-day slices (extra horizon is free and partner onboarding takes weeks), and use **MASE + weighted quantile loss**, never MAPE, because your sparse cities have zero-days and MAPE divides by zero.
- **Success looks like** a rolling-origin backtest where TimesFM's MASE is clearly below seasonal naive's on the cities carrying your volume, with 80% intervals that actually contain ~80% of outcomes.

---

## 2. Model brief

**Architecture in plain language.** A language model reads text as tokens and predicts the next one. TimesFM does the same with numbers: it chops a series into **patches** — contiguous blocks of time steps treated as one token — and a **decoder-only transformer** (the same family as GPT-style models: it only looks leftward, at the past) maps those patches to a forecast. Patches of **32 time steps**, and v3's **alternating temporal and variate attention** — attention passes that look along time, then across the different series in the batch — are reported via search of the [blog](https://research.google/blog/timesfm-3-a-zero-shot-foundation-model-for-multivariate-forecasting/) and of the independent [skaters issue #209](https://github.com/microprediction/skaters/issues/209). The founding design is the ICML 2024 paper *[A decoder-only foundation model for time-series forecasting](https://arxiv.org/abs/2310.10688)*, linked from the README. Size: **330M parameters, >1 trillion real and synthetic training time points** (via search of the blog; the README independently confirms "330M model" in its MLX benchmark table).

**Zero-shot vs fine-tuning.** Zero-shot = you call `predict` and get a forecast; the weights never change. Fine-tuning = you continue training on *your* series so the model specialises. The repo ships a **LoRA fine-tuning example** (LoRA = low-rank adaptation, a cheap method that trains a small number of extra parameters and freezes the rest) — but that example is explicitly for **TimesFM 2.5** (`TimesFm2_5ModelForPrediction`, `r=4`, "adds only ~0.6% trainable parameters", deps `transformers accelerate peft pandas pyarrow scikit-learn`). A supported fine-tuning path for **3.0 is [not stated in sources]**. Note the example's warning, which applies to inference too: *"Do not normalise your data externally — feed raw values and let the model handle it."*

**How multivariate/covariates work in v3.** Three input roles, all numeric arrays ([README](https://github.com/google-research/timesfm)):
- `contexts` — shape `(num_variates, context_length)`. Several *targets* forecast jointly.
- `past_only_covariates` — shape `(n, context_length)`. Things you observe historically but cannot know for the future (yesterday's app sessions).
- `past_future_covariates` — shape `(n, context_length + horizon)`. Things you *do* know in advance (a holiday flag, a planned campaign).

Output: `forecast` `(variates, horizon)` and `quantiles` `(variates, horizon, 9)` — **nine deciles, 0.1 to 0.9**. Categorical covariates must be numerically encoded by you; **static (non-time-varying) covariate support in 3.0 is [not stated in sources]**, as is any cap on the number of covariate channels.

**Context, horizon, frequency.** The README's MLX section states **`global_context` = 15,360**; longer contexts "are truncated to their most recent points before decode, matching the PyTorch backend." Examples run `horizon=12/24/128`, and long horizons "stitch multiple output patches"; an explicit **maximum horizon for 3.0 is [not stated in sources]** (for 2.5 the README states quantiles "up to 1k horizon" via an optional 30M quantile head). Frequency: **2.5 "gets rid of the `frequency` indicator"**; v3 handling is **[not stated in sources]** — in practice you pass an evenly-spaced series and the model infers periodicity from values.

**How to run it.** `pip install timesfm[torch]`, or `timesfm[mlx]` for Apple silicon. Hosted: **BigQuery ML**, **Google Sheets (Connected Sheets)**, **Vertex Model Garden**. Hardware: the README benchmarks the 330M model on an **Apple M4 Max**, context 512 / horizon 64 — p50 **11.1 ms** at batch 1, **48.1 ms** at batch 32 (666 series/s). GPU/VRAM needs for 3.0 are **[not stated in sources]**; the repo's skill guide quotes ~800 MB disk and ~1 GB VRAM for the 200M v2.5 model. The README cautions: *"This open version is not an officially supported Google product."*

**Known failure modes.** Zero-shot quality is **tied to the domains the model was pretrained on**, and fine-tuned foundation models do "not consistently yield substantially better results" than smaller dedicated models given their size (via search of [arXiv 2510.00742](https://arxiv.org/abs/2510.00742)). Practitioner reports name **intermittent/sparse demand, structural breaks, and exogenous shocks the model cannot see**, plus a **bias toward over-estimating persistence** — it assumes the recent pattern continues, so it is late on regime switches. The model is also **frozen at inference**: no gradient updates to correct local drift (via search of [arXiv 2605.24381](https://arxiv.org/abs/2605.24381)).

---

## 3. Forecasting fundamentals for a first-timer

**1. Seasonality.** A pattern repeating on a fixed cycle. Leads will have a strong **weekly** cycle and an **annual** one (the moving season). Weekly seasonality is learnable from values alone; annual seasonality needs 2+ years of history before any model sees it twice. Plot a day-of-week boxplot first — cheapest sanity check there is.

**2. Moving-date events.** Indian festival dates follow lunar calendars, so Diwali, Akshaya Tritiya and Pitru Paksha land on different Gregorian dates each year. A model that learns "day-of-year 290 is busy" is wrong next year by design. **This is why PnM needs future-known covariates** — and verify the PnM-relevant dates with your business team rather than taking my list as given.

**3. Intermittency.** A series with many zero days — which many smaller pickup cities will be at daily grain. Foundation models are trained mostly on dense series and degrade here; the fix is to **aggregate up** (weekly, or city-group) until the series is dense.

**4. Leakage.** Using information at training or backtest time that you would not have had in real life — classically, a future value as a feature. Your version is subtler and worse; see the next concept.

**5. Right-censoring (the PnM trap).** A lead created yesterday has not had time to convert, so conversions counted by `opp_created_ts` look artificially low for recent dates — and that low tail fills in as the cohort matures. Train on it and the model learns "conversions are collapsing" and forecasts a cliff. **Count converted orders by conversion/order date, not lead creation date**; if no conversion timestamp is exposed, that is a data-enablement blocker to resolve first.

**6. Rolling-origin backtesting.** Pretend it is an earlier date, forecast forward, compare to what happened, roll forward, repeat. It is the only honest way to estimate forecast error — a single split gives you one lucky or unlucky number. For daily PnM at h=28, roll weekly over 6–12 months for 26–52 evaluations.

**7. Baselines.** A trivial model you must beat to justify anything complex. For daily data with weekly seasonality, the right one is **seasonal naive with period 7**: "next Tuesday equals last Tuesday." Add **AutoETS/AutoARIMA** from `statsforecast` as the statistical step up. Skipping baselines is how teams ship a foundation model that is worse than copy-paste.

**8. Error metrics.** **MASE** (mean absolute scaled error) divides your error by the in-sample seasonal-naive error, so **MASE < 1 means you beat the baseline**, and it is comparable across cities of very different size. **MAPE is unusable here** — it divides by the actual, and sparse cities have zero-days. For intervals use **weighted quantile (pinball) loss**, which rewards honesty about uncertainty.

**9. Point forecasts vs quantiles.** A point forecast is one number; quantiles describe the distribution. Capacity planning is **asymmetric** — under-supplying partners on a peak day costs more than over-supplying — so plan capacity off roughly **q0.7–q0.8** and pace spend off the **median**. TimesFM returns nine deciles for free.

**10. Hierarchy and aggregation.** City forecasts should sum to roughly the India forecast; naively they will not. Forecast both levels, compare, and either reconcile formally or — the pragmatic first-build choice — **use India for budget totals and cities for relative allocation**.

---

## 4. Problem framing for PnM

**The decisions this drives.** Two, with different needs. *Partner/capacity planning* is city-level, needs a 2–4 week view (onboarding and repositioning partners takes weeks), and cares about the **upper quantile**. *Marketing spend pacing* is India- and channel-level, needs 3–7 days, and cares about the **median** and direction of travel.

**Target definitions — be precise, and note they differ.**
- **Leads:** `COUNT(DISTINCT opp_id)` from `prod_eldoria.core.dim_pnm_opportunity` where `user_flag = 'normal'`, bucketed by `DATE(opp_created_ts)` in **Asia/Kolkata**. Note your source data may be UTC; a timezone slip shifts a chunk of every day's volume into the neighbouring day and quietly wrecks the weekly pattern.
- **Converted orders:** leads at `status = 4`, bucketed by **conversion date**, not creation date (Section 3, concept 5). If a conversion timestamp is not exposed on the opportunity dim, source it from the order-level PnM facts (`fact_pnm_orders` / `dim_pnm_orders`) — this is a prerequisite, not an optimisation.

**Defaults I would keep.** India-total first, then `pickup_city_name × day` — the India series is dense enough to debug the pipeline on before sparsity bites. Daily refresh — cheap and correct. Leads and converted orders as separate targets — correct, though v3 also lets you forecast them *jointly* as two variates, worth testing.

**Your defaults I would change, and why.**
1. **Horizon: ask for h=28, report h=3 and h=7.** One forward pass returns the whole horizon at no extra cost, and the longer view is what capacity planning needs. Keep the 3- and 7-day slices as headline numbers; error grows with horizon and that curve is itself a useful artefact.
2. **Metrics: MASE + weighted quantile loss.** You did not specify one; if a stakeholder asks for MAPE, give them absolute error in leads/day alongside MASE and explain the zero-day problem.
3. **Granularity: top-N cities individually, the rest as one "rest of India" series.** Sixty sparse city forecasts are sixty noisy forecasts nobody trusts. Pick N by cumulative volume (~80–90% of leads) and re-pick quarterly.
4. **Channel: forecast the total, split by share.** Channel splits help pacing, but four separate forecasts drift apart and won't sum. Forecast city totals, then apply a trailing-28-day channel share.
5. **Don't skip `shifting_type`.** Intra-city and inter-city PnM have different seasonality and capacity implications; at minimum check whether one series or two fits the planning decision.

**Where leads and converted orders diverge.** Leads are a **leading indicator** of conversions, so lagged leads make an excellent **past-only covariate** for the conversion model — exactly what v3's covariate support exists to exploit. Conversions are sparser (intermittency bites at city level much sooner), right-censored (above), and driven by operational levers the model cannot see. Expect conversion forecasts to be materially worse, and say so *before* you show results.

---

## 5. Data enablement in Snowflake / dbt

Build three marts. Keep them boring and dense — every downstream bug you avoid here is a week saved.

**`mart_pnm_leads_daily`** — grain: one row per `(city_key, date_day)`, no gaps.
`date_day` (DATE, Asia/Kolkata) · `city_key` (`pickup_city_name`, or `'INDIA'` for the rollup, or `'REST_OF_INDIA'`) · `shifting_type` · `leads` (INT, **0 where no activity**) · `leads_app`, `leads_web_desktop`, `leads_web_mobile`, `leads_generic` · `is_backfilled_zero` (BOOLEAN).

**`mart_pnm_conversions_daily`** — grain: one row per `(city_key, date_day)` on **conversion date**.
`date_day` · `city_key` · `converted_orders` (INT, 0-filled) · `leads_lag7`, `leads_lag14` (past-only covariate feed) · `cohort_maturity_days` (how mature the most recent cohort is — used to **exclude** the unmatured tail from training).

**`mart_pnm_calendar`** — grain: one row per `date_day`, covering **history + at least 60 future days**. This is your future-known covariate table and it must extend past today or `past_future_covariates` is impossible.
`date_day` · `dow` (0–6) · `is_weekend` · `is_month_start`/`is_month_end` (rent cycles drive shifting) · `is_public_holiday` · `is_major_festival` · `festival_name` · `is_inauspicious_period` (e.g. Pitru Paksha — verify dates with the business) · `is_school_transition_window` · `marketing_spend_planned` (numeric, if planned spend exists forward; otherwise omit rather than fake it) · `is_promo_active`.

**Practical rules.**
- **Zero-fill is mandatory.** `LEFT JOIN` a date spine to every city. A missing row is not read as a zero — it silently compresses the calendar and destroys the weekly cycle.
- **Test users:** filter `user_flag = 'normal'` in the mart, not in the notebook, so every consumer gets the same number. Add a dbt test asserting the excluded share stays within an expected band — a sudden jump means a tracking change upstream.
- **History length:** target **≥ 24 months, ideally 36**, so annual seasonality appears at least twice. With 12–18 months, treat annual effects as unlearnable from values, lean entirely on calendar covariates, and say so in your write-up.
- **Sparse cities:** encode a rule in the mart — e.g. median <3 leads/day over the trailing 90 days means forecast **weekly** or fold into `REST_OF_INDIA`. Keep it data-driven and re-evaluated, not a hand-pick.
- **Outliers:** flag known one-offs (outage, campaign spike) in `is_anomaly` rather than overwriting history; decide per experiment whether to mask.

**Which covariates TimesFM 3 can actually consume.** Only **numeric, evenly-spaced, dynamic** channels, in the two roles above. Binary flags (`is_major_festival` → 1.0/0.0) ✅; ordinal day-of-week ❌ (one-hot it, or omit — weekly structure is already learned from values); string `festival_name` ❌; static per-city attributes — **[not stated in sources]** for 3.0, so handle them by forecasting cities separately. Past-future covariates need values across `context_length + horizon`, which is why `mart_pnm_calendar` must extend into the future.

---

## 6. Step-by-step execution plan

Assume Python 3.11, `pandas`, `snowflake-connector-python`, plus `timesfm[torch]` and `statsforecast` for baselines.

### Phase 0 — Licence decision and data pull
**Goal:** know what you are allowed to ship, and have a clean frame.
**Actions:** Take the [licence notice](https://github.com/google-research/timesfm) to legal; agree the split — **3.0 for offline evaluation, 2.5 / Chronos-2 / hosted TimesFM for production**. Then pull the marts.

```python
import pandas as pd, snowflake.connector
con = snowflake.connector.connect(...)  # use your standard auth
q = """
select date_day, city_key, leads
from analytics.pnm.mart_pnm_leads_daily
where city_key = 'INDIA' and date_day < current_date()
order by date_day
"""
df = pd.read_sql(q, con)
df["date_day"] = pd.to_datetime(df["date_day"])
df = df.set_index("date_day").asfreq("D")           # asserts an unbroken daily index
assert df["leads"].isna().sum() == 0, "gaps in date spine — fix the mart, not here"
print(df.describe(), df.tail())
```
**Expected output:** a gap-free daily series, and a printed date range.
**Pass/fail:** a written licence position, zero NaNs, and a day-of-week boxplot you have actually looked at.

### Phase 1 — Baselines
**Goal:** the number TimesFM must beat.
**Actions:** seasonal naive (lag-7) and AutoETS, scored on a rolling origin.

```python
import numpy as np
from statsforecast import StatsForecast
from statsforecast.models import SeasonalNaive, AutoETS

sf_df = df.reset_index().rename(
    columns={"date_day": "ds", "leads": "y"}).assign(unique_id="INDIA")

sf = StatsForecast(
    models=[SeasonalNaive(season_length=7), AutoETS(season_length=7)],
    freq="D", n_jobs=-1,
)
# rolling-origin: 26 windows, stepping 7 days, horizon 28
cv = sf.cross_validation(df=sf_df, h=28, step_size=7, n_windows=26)

def mase(y, yhat, y_insample, m=7):
    scale = np.mean(np.abs(y_insample[m:] - y_insample[:-m]))
    return np.mean(np.abs(y - yhat)) / scale

ins = sf_df["y"].values
for m in ["SeasonalNaive", "AutoETS"]:
    print(m, round(mase(cv["y"].values, cv[m].values, ins), 3))
```
**Expected output:** two MASE numbers. SeasonalNaive should land near 1.0 by construction; AutoETS somewhat below.
**Pass/fail:** both run end-to-end and the numbers are stable when you change `n_windows`. Save this table — it is your comparator forever.

### Phase 2 — Zero-shot TimesFM
**Goal:** first foundation-model forecast, univariate, no covariates.
**Actions:** feed raw values (no external normalisation) for one origin.

```python
import numpy as np
from timesfm3 import TimesFM3Evaluator, ModelConfig

config = ModelConfig(
    checkpoint_path="google/timesfm-3.0-pytorch",
    per_core_batch_size=32,
    device="cuda",              # "cpu" works, just slower
)
forecaster = TimesFM3Evaluator(config)

CONTEXT, HORIZON = 512, 28
ctx = df["leads"].values[-CONTEXT:].astype(np.float32)   # raw counts, NOT scaled

out = list(forecaster.predict_batch(
    [ctx], horizon=HORIZON, return_quantiles=True, use_symmetric_averaging=False,
))[0]

print(out.forecast.shape)    # (28,)
print(out.quantiles.shape)   # (28, 9)  deciles 0.1 .. 0.9
median, q80 = out.forecast, out.quantiles[:, 7]
```
**Expected output:** a 28-length point forecast and a `(28, 9)` quantile array.
**Pass/fail:** the forecast reproduces the weekly shape (plot against the last 8 weeks) and the median stays non-negative. A flat line means the context is too short or the series too sparse — aggregate up.

### Phase 3 — Add covariates
**Goal:** give the model the festival calendar it cannot infer.
**Actions:** align the calendar over `context + horizon`; pass lagged leads as past-only for the conversion model.

```python
cal = pd.read_sql("select * from analytics.pnm.mart_pnm_calendar order by date_day", con)
cal["date_day"] = pd.to_datetime(cal["date_day"])
cal = cal.set_index("date_day").asfreq("D")

window = df.index[-CONTEXT:].union(
    pd.date_range(df.index[-1] + pd.Timedelta(days=1), periods=HORIZON, freq="D"))
future_known = cal.loc[window, ["is_public_holiday", "is_major_festival",
                                "is_inauspicious_period", "is_month_end"]]
assert len(future_known) == CONTEXT + HORIZON, "calendar does not extend far enough"

pf_cov = future_known.to_numpy(dtype=np.float32).T        # (4, CONTEXT + HORIZON)
target = ctx[None, :]                                     # (1, CONTEXT)

out_cov = list(forecaster.predict_batch(
    contexts=[target], horizon=HORIZON,
    past_future_covariates=[pf_cov],
    return_quantiles=True, use_symmetric_averaging=False,
))[0]
print(out_cov.forecast.shape)   # (1, 28)
```
**Expected output:** shapes `(1, 28)` and `(1, 28, 9)`.
**Pass/fail:** covariate MASE beats no-covariate MASE **on the backtest, not on one origin**. If it does not, your calendar flags are probably wrong or mis-dated — check them against actual observed spikes before blaming the model.

### Phase 4 — Fine-tuning (optional, defer it)
**Goal:** squeeze out remaining error — only if Phases 2–3 already beat baselines.
**Actions:** the repo's LoRA example targets **TimesFM 2.5** (`TimesFm2_5ModelForPrediction`, PEFT, `r=4`); a 3.0 path is **[not stated in sources]**. Independent work finds fine-tuned foundation models do not consistently beat smaller dedicated models for their cost (via search of [arXiv 2510.00742](https://arxiv.org/abs/2510.00742)).
**Pass/fail:** skip this on a first build. Revisit only once zero-shot + covariates is in production and someone can name the rupee value of the remaining error.

### Phase 5 — Full rolling-origin backtest
**Goal:** the defensible comparison table.
**Actions:** loop origins, batch all cities into one `predict_batch` call per origin.

```python
origins = pd.date_range(df.index[-1] - pd.Timedelta(days=182),
                        df.index[-1] - pd.Timedelta(days=HORIZON), freq="7D")
rows = []
for t in origins:
    ctxs, keys = [], []
    for city, g in panel.groupby("city_key"):          # panel = all cities, long format
        hist = g.set_index("date_day").loc[:t, "leads"]
        if len(hist) < CONTEXT:                        # not enough history yet
            continue
        ctxs.append(hist.values[-CONTEXT:].astype(np.float32)); keys.append(city)
    preds = list(forecaster.predict_batch(ctxs, horizon=HORIZON, return_quantiles=True))
    for city, p in zip(keys, preds):
        actual = panel_wide.loc[t + pd.Timedelta(days=1):t + pd.Timedelta(days=HORIZON), city]
        rows.append({"origin": t, "city": city, "h": np.arange(1, HORIZON + 1),
                     "yhat": p.forecast, "q80": p.quantiles[:, 7], "y": actual.values})
bt = pd.DataFrame(rows).explode(["h", "yhat", "q80", "y"])
```
**Expected output:** a tidy frame keyed by `(origin, city, h)` with actual, median and q80.
**Pass/fail:** ≥20 origins per city, every origin using data up to `t` only. Grep your own code for `panel_wide` used before the prediction call — that is where leakage hides.

### Phase 6 — Weekly deployment
**Goal:** a forecast the business sees without you in the loop.
**Actions:** a daily job reading the marts, calling the **production-licensed** forecaster, and writing `mart_pnm_forecast_daily` (`run_date, city_key, target_date, horizon_days, target_type, p50, p80, model_version`). Archive every run — you cannot measure drift without it. Alert when trailing-28-day MASE degrades >20% versus backtest, or actuals fall outside the 10–90 band on 3 consecutive days.
**Pass/fail:** two consecutive weeks of automated runs with no manual intervention, and a stakeholder who can find the numbers without asking you.

---

## 7. Evaluation

**Metrics, and why.** **MASE** as the headline: scale-free, so Mumbai and Coimbatore sit in one table, and 1.0 has built-in meaning — *worse than copy-last-week*. **Weighted quantile loss** second, because capacity decisions come off the upper quantile and a point metric cannot tell you whether that quantile is trustworthy. **Empirical coverage** third: what share of actuals fell inside q10–q90? Near 80% is right; 55% means your intervals are lying. Also report **MAE in leads/day** — not for model selection, but because it is the only number stakeholders can feel.

**Building the backtest.** Fix `h=28`, step origins weekly, use ≥26 origins. At each origin build context from data `≤ t` only and score against `t+1 … t+28`. Report MASE **by horizon bucket** (h1–3, h4–7, h8–14, h15–28) — a single average hides that your 3-day number is excellent and your 28-day number is not. Run the identical loop for seasonal naive, AutoETS and TimesFM: same origins, same cities, same scaling denominator.

**What "good enough" means.** The honest bar, in order: (1) **TimesFM MASE < AutoETS MASE < SeasonalNaive MASE** on the top cities by volume — if TimesFM cannot clear the statistical baseline, ship the statistical baseline and say so; (2) a **skill score** — the percentage error reduction versus seasonal naive — that is *visible*, not noise. For calibration, published leaderboard skill scores for the strongest models sit around the **32–40%** range versus seasonal naive (reported via search of [fev-bench](https://arxiv.org/abs/2509.26468): Chronos-2 35.50, TiRex-2 33.74, Toto-2.0 32.54 MASE skill score; and TimesFM-2.5 at 32.3% skill / 73.0% win rate). Those are averages across 100 diverse public tasks, **not a prediction about PnM** — your city-level numbers will be worse and your India-level numbers may be better. Treat ~15–25% skill at India level as a genuinely useful first result. (3) Coverage within a few points of nominal.

**Presenting to stakeholders.** Lead with the decision, not the model. One chart: actual versus forecast over six months at India level, 80% band shaded. One table: MAE in leads/day by horizon bucket with a "% better than last-week-copy" column — that column is the whole argument. One slide naming where it fails (sparse cities, festival weeks, conversion forecasts), so nobody discovers it later and distrusts the rest. Translate MASE into rupees or partner-days before showing it to a business audience.

---

## 8. Best practices and pitfalls checklist

1. **Resolve the TimesFM 3.0 non-commercial licence before writing production code.** ([README](https://github.com/google-research/timesfm))
2. Never externally normalise inputs — the repo says feed raw values; the model normalises internally.
3. Zero-fill the date spine in the mart. A missing row is a silent calendar corruption.
4. Bucket by **conversion date** for converted orders, and drop the unmatured recent tail.
5. Filter `user_flag = 'normal'` once, in dbt, and test that the excluded share is stable.
6. Convert to Asia/Kolkata before bucketing to a day.
7. Never use MAPE on count data with zero-days.
8. Build seasonal naive and AutoETS *before* TimesFM, and keep them in every comparison forever.
9. Score on a rolling origin with ≥20 origins; one holdout split proves nothing.
10. Report error by horizon bucket, not one average.
11. Ensure `mart_pnm_calendar` extends ≥60 days into the future or `past_future_covariates` is impossible.
12. Verify festival and inauspicious-period dates with the business team; do not hand-code them from memory.
13. Aggregate sparse cities up (weekly or into `REST_OF_INDIA`) rather than producing noisy per-city daily forecasts.
14. Archive every forecast run so you can measure drift and re-backtest against production behaviour.
15. Expect the model to lag structural breaks — a pricing change, a new city launch, a campaign switch-off — and put a human check in front of any decision during those weeks.

---

## 9. Further reading

1. **[TimesFM repository README](https://github.com/google-research/timesfm)** — the authoritative source for the API, checkpoints and the licence notice. Read the licence section twice before anything else.
2. **[TimesFM 3 announcement blog](https://research.google/blog/timesfm-3-a-zero-shot-foundation-model-for-multivariate-forecasting/)** — Google's framing of multivariate and covariate support; your 2-minute manager explanation comes from here.
3. **[A decoder-only foundation model for time-series forecasting (arXiv 2310.10688)](https://arxiv.org/abs/2310.10688)** — the founding paper; read the patching section to see why context length matters.
4. **[fev-bench (arXiv 2509.26468)](https://arxiv.org/abs/2509.26468)** — 100 real tasks, 46 with covariates; source of the skill-score framing and the evidence that covariates help.
5. **[How Foundational are Foundation Models for Time Series Forecasting? (arXiv 2510.00742)](https://arxiv.org/abs/2510.00742)** — the sceptical counterweight; read before you promise anyone a fine-tuning roadmap.
6. **[Operational Viability of Foundation Models (arXiv 2605.24381)](https://arxiv.org/abs/2605.24381)** — inference cost, frozen-model drift, and the head/tail routing pattern that should shape your production design.
7. **[Chronos-2 (arXiv 2510.15821)](https://arxiv.org/abs/2510.15821)** and its **[Apache-2.0 weights](https://huggingface.co/amazon/chronos-2)** — your most likely production-legal alternative, with native covariate support.
8. **[skaters issue #209](https://github.com/microprediction/skaters/issues/209)** — a short independent note reaching the same conclusion I do: v3 leads the leaderboards, but v2.5 is "the production-relevant comparison".
