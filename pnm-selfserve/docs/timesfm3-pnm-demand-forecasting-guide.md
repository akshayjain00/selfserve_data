# TimesFM 3 for PnM support capacity planning — a zero-to-roster guide

**Audience:** an analyst who has never run a forecasting foundation model.
**Decision this serves:** how many PnM telecallers/support agents to roster per day, with the roster published **7–14 days ahead**.
**Goal:** a backtested daily forecast of support contact workload that provably beats a dumb baseline, converted into an agent-day number a workforce manager can staff to.

> **Sourcing note.** `research.google`, `arxiv.org` and `huggingface.co` are blocked by this environment's egress proxy, so I could not open the TimesFM 3 blog, the papers or the model card directly. Everything below is grounded in (a) the **official repository README**, fetched in full and authoritative for the API and licence, and (b) **web-search retrieval** of the blog, papers and leaderboards, labelled "via search of X". Where sources are silent I write **[not stated in sources]**. No benchmark number, parameter count or API signature is invented.
>
> **Scope note.** Daily granularity with a 7–14 day roster horizon means **intraday (hourly) shift shaping is out of scope**. Phase 4 bridges the gap with a static arrival curve and says where that costs you.

---

## 1. TL;DR

- **TimesFM 3 is a pretrained "foundation model" for time series** — one network trained on a huge corpus of other people's series, which forecasts *your* series with no training step. That is **zero-shot**. ([repo README](https://github.com/google-research/timesfm))
- It is **330M parameters**, decoder-only; the headline v3 change is **native multivariate forecasting plus covariate support** — past-only and past-*and*-future — with **no per-task tuning**. ([README](https://github.com/google-research/timesfm); 32-step patches, alternating temporal/variate attention, single-pass decoding — via search of the [blog](https://research.google/blog/timesfm-3-a-zero-shot-foundation-model-for-multivariate-forecasting/))
- **The licence is the headline risk, not the accuracy.** TimesFM **3.0 weights are `timesfm-non-commercial-license-v1.0`, non-commercial and non-production — "Commercial or production use of the default pretrained weights is not permitted."** Code is Apache-2.0; weights **up to 2.5 are Apache-2.0**. ([README](https://github.com/google-research/timesfm))
- **Recommended path for Porter:** **TimesFM 3.0 offline only**, as the yardstick showing the ceiling. **Ship on TimesFM 2.5** (Apache-2.0, XReg covariates), **Chronos-2** (Apache-2.0, native covariates), or **hosted TimesFM** via BigQuery ML / Vertex under Google's commercial terms. Legal sign-off before any production DAG.
- **What it is NOT good for:** sparse/intermittent series, hard structural breaks, causes the model cannot see, and latency-critical inference — hundreds of ms to seconds versus microseconds for boosted trees (via search of [arXiv 2605.24381](https://arxiv.org/abs/2605.24381)). Only the first two bite a daily batch roster forecast.
- **Forecasting leads is not the job — forecasting *contacts* is.** One lead generates several call attempts over several days, and a converted order generates a second, later stream of post-booking support. Roster to the **sum of both streams** (§4).
- **It will not read your festival calendar unless you feed it.** Moving-date Indian festivals shift both PnM demand *and* agent availability, and are invisible to a model that only sees counts. That is the reason to use a v3-class model here.
- **Baselines first, always.** On fev-bench, seasonal naive is *still competitive on point error* (MASE rank 5.39) while badly calibrated probabilistically (CRPS rank 9.50) — via search of [fev-bench](https://arxiv.org/abs/2509.26468). If TimesFM cannot beat lag-7 seasonal naive **and AutoETS**, ship the cheaper model.
- **Staff to a quantile, not a mean.** Understaffing costs abandoned calls and lost leads; overstaffing costs idle hours. The newsvendor rule sets the quantile from that cost ratio (§3) — typically q0.7–q0.8, not the median.
- **Success looks like** a rolling-origin backtest where TimesFM beats both baselines on MASE, 80% intervals contain ~80% of outcomes, and **agent-days mis-staffed** — not MASE — is what the workforce manager sees.

---

## 2. Model brief

**Architecture in plain language.** A language model reads text as tokens and predicts the next one. TimesFM does the same with numbers: it chops a series into **patches** — contiguous blocks of time steps treated as one token — and a **decoder-only transformer** (GPT-family: it only looks leftward) maps those patches to a forecast. **32-step patches** and v3's **alternating temporal and variate attention** — passes along time, then across the series in the batch — are reported via search of the [blog](https://research.google/blog/timesfm-3-a-zero-shot-foundation-model-for-multivariate-forecasting/) and [skaters issue #209](https://github.com/microprediction/skaters/issues/209). Founding design: the ICML 2024 paper *[A decoder-only foundation model for time-series forecasting](https://arxiv.org/abs/2310.10688)*. Size: **330M parameters, >1 trillion training time points** (via search of the blog; the README confirms "330M model" in its MLX benchmark table).

**Zero-shot vs fine-tuning.** Zero-shot = call `predict`, get a forecast; weights never change. Fine-tuning = continue training on *your* series so the model specialises. The repo ships a **LoRA example** (LoRA = low-rank adaptation: train a few extra parameters, freeze the rest) — but explicitly for **TimesFM 2.5** (`TimesFm2_5ModelForPrediction`, `r=4`, "adds only ~0.6% trainable parameters"). A 3.0 path is **[not stated in sources]**. Heed its warning, which applies to inference too: *"Do not normalise your data externally — feed raw values and let the model handle it."*

**How multivariate/covariates work in v3.** Three input roles, all numeric arrays ([README](https://github.com/google-research/timesfm)):
- `contexts` — `(num_variates, context_length)`. Several *targets* forecast jointly (new-lead and post-booking contacts together).
- `past_only_covariates` — `(n, context_length)`. Observed historically, unknowable ahead (yesterday's agent occupancy).
- `past_future_covariates` — `(n, context_length + horizon)`. Known in advance (a holiday flag, a planned campaign).

Output: `forecast` `(variates, horizon)` and `quantiles` `(variates, horizon, 9)` — **nine deciles, 0.1 to 0.9**. Encode categoricals yourself; **static covariate support in 3.0 is [not stated in sources]**, as is any cap on channels.

**Context, horizon, frequency.** The README's MLX section states **`global_context` = 15,360**; longer contexts "are truncated to their most recent points before decode, matching the PyTorch backend." Examples run `horizon=12/24/128`; long horizons "stitch multiple output patches". An explicit **maximum horizon for 3.0 is [not stated in sources]** (for 2.5, quantiles "up to 1k horizon" via an optional 30M quantile head). Frequency: **2.5 "gets rid of the `frequency` indicator"**; v3 handling is **[not stated in sources]** — pass an evenly-spaced series and the model infers periodicity. Your h=28 is far inside any plausible limit.

**How to run it.** `pip install timesfm[torch]`, or `timesfm[mlx]` for Apple silicon. Hosted: **BigQuery ML**, **Google Sheets**, **Vertex Model Garden**. The README benchmarks the 330M model on an **Apple M4 Max**, context 512 / horizon 64 — p50 **11.1 ms** at batch 1, **48.1 ms** at batch 32 (666 series/s), so a nightly job over a few queue series is trivially cheap. GPU/VRAM needs for 3.0 are **[not stated in sources]**; the repo's skill guide quotes ~800 MB disk and ~1 GB VRAM for the 200M v2.5 model. The README cautions: *"This open version is not an officially supported Google product."*

**Known failure modes.** Zero-shot quality is **tied to the pretraining domains**, and fine-tuned foundation models do "not consistently yield substantially better results" than smaller dedicated models given their size (via search of [arXiv 2510.00742](https://arxiv.org/abs/2510.00742)). Practitioner reports name **intermittent demand, structural breaks, unseen exogenous shocks**, plus a **bias toward over-estimating persistence** — it assumes the recent pattern continues, so it is late on regime switches. For you, a campaign launch, IVR change or new queue will fool it for roughly a context window. It is also **frozen at inference**: no gradient updates to correct drift (via search of [arXiv 2605.24381](https://arxiv.org/abs/2605.24381)).

---

## 3. Forecasting fundamentals for a first-timer

**1. Seasonality.** A pattern repeating on a fixed cycle. Contact volume has a strong **weekly** cycle and an **annual** one (the moving season). Weekly is learnable from values alone; annual needs 2+ years before any model sees it twice. Plot a day-of-week boxplot first.

**2. Moving-date events.** Indian festival dates follow lunar calendars, so Diwali, Akshaya Tritiya and Pitru Paksha land on different Gregorian dates each year; a model that learns "day-of-year 290 is busy" is wrong next year by design. Worse for staffing, those dates also move **agent availability** (leave clustering), hitting both sides of the equation. Verify the PnM-relevant dates with the business.

**3. Intermittency.** A series with many zero days. Your *queue-level* contact series will be dense — this problem largely disappears once you forecast at roster grain rather than per-city.

**4. Leakage.** Using information at training or backtest time you would not have had in real life — classically, a future value as a feature. A subtler one: scaling your error metric with test-period data (§7).

**5. Right-censoring (the PnM trap).** A lead created yesterday has not finished generating contacts, nor had time to convert. Count conversion-driven workload by **conversion/order date** and exclude the unmatured recent tail from training — otherwise the model learns "volume is collapsing" and forecasts a cliff you then under-staff for.

**6. Rolling-origin backtesting.** Pretend it is an earlier date, forecast forward, compare, roll forward, repeat. The only honest way to estimate error — a single split gives one lucky or unlucky number. Roll **weekly**, mirroring your roster cadence, over 6–12 months.

**7. Baselines.** A trivial model you must beat. **Seasonal naive, period 7** is "next Tuesday = last Tuesday": zero parameters, and the denominator MASE is defined against. **AutoETS** (Error/Trend/Seasonality smoothing, auto-selected by AICc) is the fair fight — what a competent analyst ships in an afternoon for no GPU cost. Beating seasonal naive but not AutoETS means you bought infrastructure to match `pip install statsforecast`.

**8. Error metrics.** **MASE** divides your error by the in-sample seasonal-naive error, so **MASE < 1 means you beat the baseline**, comparable across queues of different size. **MAPE is unusable** on counts with low or zero days. For intervals use **weighted quantile (pinball) loss**. For stakeholders, convert to **agent-days mis-staffed**.

**9. Quantiles and the newsvendor rule.** A point forecast is one number; quantiles describe the distribution. Staffing is **asymmetric**, so the cost-optimal level is the **q\*** quantile where `q* = Cu / (Cu + Co)` — `Cu` the cost of being one agent-day short, `Co` of being one over. If understaffing costs ~3×, `q* = 0.75`. That is where "q0.7–q0.8" comes from; derive your own ratio rather than inheriting mine.

**10. Workload decomposition.** Contacts today are not caused by today's leads; they are a sum over past cohorts: `contacts[d] = Σ_k leads[d−k] · r[k]`, where `r[k]` is the average contacts a lead generates `k` days after creation. That **contact-age kernel** is the bridge between business demand and support workload, and you must measure it (§5).

---

## 4. Problem framing for PnM support capacity

**The decision, precisely.** A workforce manager publishes a roster 7–14 days out and needs, per queue per day, *how many agent-shifts to schedule*. Three horizons map onto three real decisions:

| Horizon | Decision | Reversibility |
|---|---|---|
| **h = 14** | Roster commit — shifts published | Hard to change |
| **h = 7** | Roster lock — final headcount | Some swaps possible |
| **h = 1–3** | Flex — overtime, shift swaps, borrowed agents | Cheap to change |
| *h = 28 (free)* | *Hiring/attrition signal, not rostering* | *Informational* |

So: **request h=28 in one call** (extra horizon is free), **report h=7 and h=14 as the headline**, keep h=1–3 as the flex check. This supersedes your original "1 week and 3 days" default — 3 days is too late to change a published roster.

**Two workload streams. Forecast both, sum them, and never conflate them.**

1. **New-lead workload** — contacts against fresh leads. Driver: `COUNT(DISTINCT opp_id)` from `prod_eldoria.core.dim_pnm_opportunity` where `user_flag = 'normal'`, by `DATE(opp_created_ts)` in **Asia/Kolkata** (source may be UTC; a timezone slip shifts volume into the neighbouring day and wrecks the weekly pattern). High-volume, smooth, marketing-driven. Converted to contacts via kernel `r_lead[k]`.
2. **Post-booking workload** — rescheduling, escalations, day-of-move support on `status = 4` orders. Driver: converted orders **by conversion/order date** (from `fact_pnm_orders` / `dim_pnm_orders` if the opportunity dim exposes only current `status`). Sparser, lagged, right-censored. Its kernel `r_conv[k]` peaks *later* and spreads wider, because support clusters around the move date, not the booking.

**Expect the conversion-driven stream to forecast worse** — sparser, more exogenously driven. Say so before showing results. It is usually the *smaller* stream, so its error dilutes in the sum; quantify that share early, because if post-booking exceeds ~40% of contacts your accuracy ceiling is set by the harder stream.

**Two modelling routes — run both, let the backtest pick.** **(A) Direct:** forecast total contacts per queue per day from telephony/CRM logs. Simplest, captures everything, my default **given ≥18 months of clean logs**. **(B) Decomposed:** forecast leads and conversions, convolve each with its kernel, sum. More moving parts, but robust when logging changed mid-history, and it *explains* movements — which is the first thing a manager asks when a number surprises them.

**Granularity: forecast at the grain your roster is built at, which is probably not city.** This is the biggest change from the original brief. National pool → forecast **India × day** and stop. Split by language or region → that grain. **`pickup_city_name` × day only if agents are genuinely city-dedicated** — otherwise you produce sixty noisy series nobody rosters against, and summing noisy forecasts is worse than forecasting the sum. Confirm the queue structure before building anything; keep city output for *reporting*, not rostering.

**Other default changes.** **Metrics:** MASE + weighted quantile loss for model selection, agent-days for stakeholders — never MAPE. **Channel splits** are a reporting cut, not a forecast: forecast queue totals, apply a trailing-28-day share. **`shifting_type`** matters only if intra-city and inter-city route to different queues or carry different handle times. **Marketing spend pacing** is now a secondary consumer of the lead forecast, not a design driver.

---

## 5. Data enablement in Snowflake / dbt

Five marts. Keep them boring and dense.

**`mart_pnm_leads_daily`** — grain: one row per **`(queue_key, shifting_type, date_day)`**, no gaps. (If you do not need the `shifting_type` cut, drop the column *and* the grain key together — do not leave a column that breaks the declared grain.)
`date_day` (DATE, Asia/Kolkata) · `queue_key` · `shifting_type` · `leads` (INT, **0 where no activity**) · `leads_app`, `leads_web_desktop`, `leads_web_mobile`, `leads_generic` · `is_backfilled_zero` (BOOLEAN).

**`mart_pnm_conversions_daily`** — grain: `(queue_key, date_day)` on **conversion date**.
`converted_orders` (INT, 0-filled) · `move_date` rollup if available (post-booking contacts track the move, not the booking) · `cohort_maturity_days` — used to **exclude** the unmatured tail from training.

**`mart_pnm_contacts_daily`** — grain: `(queue_key, date_day)`. The direct target for route (A).
`contacts_offered`, `contacts_handled`, `handle_seconds_total`, `aht_seconds` · `contacts_new_lead`, `contacts_post_booking` (split by linkage to `opp_id`) · `is_logging_change` — flag the day a telephony or process change broke comparability; an invisible structural break is the failure mode most likely to bite you.

**`mart_pnm_contact_kernel`** — grain: `(queue_key, stream, age_days)`. The bridge.
`stream` ∈ {`new_lead`, `post_booking`} · `age_days` (0…30) · `contacts_per_source_unit` · `estimated_over_window`. Rebuild monthly **from matured cohorts only** — a kernel fitted on unmatured cohorts under-counts the tail and systematically under-staffs you.

**`mart_pnm_calendar`** — grain: `date_day`, covering **history + ≥60 future days**, or `past_future_covariates` is impossible.
`dow` · `is_weekend` · `is_month_start`/`is_month_end` (rent cycles drive shifting) · `is_public_holiday` · `is_major_festival` · `festival_name` · `is_inauspicious_period` · `is_school_transition_window` · `marketing_spend_planned` (only if forward-planned spend genuinely exists) · `is_promo_active`.

**Staffing parameters** belong in a small governed table, not notebook constants: `aht_seconds`, `shrinkage_pct`, `occupancy_target`, `shift_hours`, `cost_understaff_per_agent_day`, `cost_overstaff_per_agent_day`, versioned by effective week.

**Practical rules.**
- **Zero-fill is mandatory.** `LEFT JOIN` a date spine to every queue; a missing row is not read as a zero and silently destroys the weekly cycle.
- **Test users:** filter `user_flag = 'normal'` in the mart, not the notebook, and dbt-test that the excluded share stays in band — a jump means a tracking change upstream.
- **History:** **≥24 months, ideally 36**, so annual seasonality appears twice. With 12–18 months, treat annual effects as unlearnable from values, lean on calendar covariates, and say so in your write-up.
- **Outliers:** flag one-offs (outage, campaign spike) in `is_anomaly` rather than overwriting history.

**Which covariates TimesFM 3 can actually consume.** Only **numeric, evenly-spaced, dynamic** channels, in the two roles above. Binary flags ✅; ordinal day-of-week ❌ (one-hot or omit); string `festival_name` ❌; **static** per-queue attributes **[not stated in sources]** for 3.0, so forecast queues separately instead. Past-future covariates need values across `context_length + horizon` — hence the forward-extending calendar.

---

## 6. Step-by-step execution plan

Python 3.11, `pandas`, `snowflake-connector-python`, plus `timesfm[torch]` and `statsforecast`. Phase 4 is inserted into the standard sequence because a forecast that never becomes an agent count does not serve the decision.

### Phase 0 — Licence decision, queue definition, data pull
**Goal:** know what you may ship, and at what grain.
**Actions:** take the [licence notice](https://github.com/google-research/timesfm) to legal; agree **3.0 offline, 2.5 / Chronos-2 / hosted for production**. Confirm roster grain with the workforce manager, then pull.

```python
import pandas as pd, snowflake.connector
con = snowflake.connector.connect(...)
q = """
select date_day, contacts_offered as y
from analytics.pnm.mart_pnm_contacts_daily
where queue_key = 'PNM_NATIONAL' and date_day < current_date()
order by date_day
"""
df = pd.read_sql(q, con)
df["date_day"] = pd.to_datetime(df["date_day"])
df = df.set_index("date_day").asfreq("D")        # asserts an unbroken daily index
assert df["y"].isna().sum() == 0, "gaps in date spine — fix the mart, not here"
print(df.describe(), df.tail())
```
**Expected output:** a gap-free daily contact series.
**Pass/fail:** written licence position, confirmed queue grain, zero NaNs, and a day-of-week boxplot you have looked at.

### Phase 1 — Baselines
**Goal:** the numbers TimesFM must beat, and the MASE denominator.

```python
import numpy as np
from statsforecast import StatsForecast
from statsforecast.models import SeasonalNaive, AutoETS

H, M = 28, 7
sf_df = df.reset_index().rename(columns={"date_day": "ds"}).assign(unique_id="Q")
sf = StatsForecast(models=[SeasonalNaive(season_length=M), AutoETS(season_length=M)],
                   freq="D", n_jobs=-1)
cv = sf.cross_validation(df=sf_df, h=H, step_size=7, n_windows=26)

def mase(g, train_hist):                       # scale from PRE-ORIGIN data only
    scale = np.mean(np.abs(train_hist[M:] - train_hist[:-M]))
    return np.mean(np.abs(g["y"] - g["yhat"])) / scale

y = sf_df.set_index("ds")["y"]
for m in ["SeasonalNaive", "AutoETS"]:
    scores = [mase(w.rename(columns={m: "yhat"}), y.loc[:cutoff].values)
              for cutoff, w in cv.groupby("cutoff")]
    print(m, round(float(np.mean(scores)), 3))
```
**Expected output:** two MASE numbers; SeasonalNaive near 1.0 by construction, AutoETS below it.
**Pass/fail:** both run, numbers stable as you vary `n_windows`. Note the denominator uses **only data up to each cutoff** — computing it from the full series leaks the test period into your metric.

### Phase 2 — Zero-shot TimesFM
**Goal:** first foundation-model forecast, univariate, no covariates.

```python
import numpy as np
from timesfm3 import TimesFM3Evaluator, ModelConfig

config = ModelConfig(checkpoint_path="google/timesfm-3.0-pytorch",
                     per_core_batch_size=32, device="cuda")   # "cpu" works, slower
forecaster = TimesFM3Evaluator(config)

CONTEXT, HORIZON = 512, 28
ctx = df["y"].values[-CONTEXT:].astype(np.float32)   # raw counts, NOT scaled

out = list(forecaster.predict_batch([ctx], horizon=HORIZON,
                                    return_quantiles=True,
                                    use_symmetric_averaging=False))[0]
print(out.forecast.shape)    # (28,)
print(out.quantiles.shape)   # (28, 9)   deciles 0.1 .. 0.9
median, q80 = out.forecast, out.quantiles[:, 7]
```
**Expected output:** a 28-length point forecast and a `(28, 9)` quantile array.
**Pass/fail:** the forecast reproduces the weekly shape (plot against the last 8 weeks) and the median stays non-negative. A flat line means the context is too short or the series too sparse.

### Phase 3 — Add covariates
**Goal:** give the model the festival calendar it cannot infer.

```python
cal = pd.read_sql("select * from analytics.pnm.mart_pnm_calendar order by date_day", con)
cal["date_day"] = pd.to_datetime(cal["date_day"]); cal = cal.set_index("date_day").asfreq("D")

window = df.index[-CONTEXT:].union(
    pd.date_range(df.index[-1] + pd.Timedelta(days=1), periods=HORIZON, freq="D"))
future_known = cal.loc[window, ["is_public_holiday", "is_major_festival",
                                "is_inauspicious_period", "is_month_end"]]
assert len(future_known) == CONTEXT + HORIZON, "calendar does not extend far enough"

out_cov = list(forecaster.predict_batch(
    contexts=[ctx[None, :]],                                  # (1, CONTEXT)
    horizon=HORIZON,
    past_future_covariates=[future_known.to_numpy(np.float32).T],  # (4, CONTEXT+HORIZON)
    return_quantiles=True, use_symmetric_averaging=False))[0]
print(out_cov.forecast.shape)   # (1, 28)
```
**Expected output:** shapes `(1, 28)` and `(1, 28, 9)`.
**Pass/fail:** covariate MASE beats no-covariate MASE **on the backtest, not one origin**. If not, your flags are probably mis-dated — check against observed spikes before blaming the model.

### Phase 4 — Convert the forecast into a roster (the step that makes it useful)
**Goal:** agent-days, at the cost-optimal quantile.

```python
P = staffing_params          # from the governed table, effective for the forecast week
q_star = P["cost_understaff"] / (P["cost_understaff"] + P["cost_overstaff"])
idx = min(range(9), key=lambda i: abs((i + 1) / 10 - q_star))   # nearest available decile
contacts_planning = out_cov.quantiles[0, :, idx]

productive_s = P["shift_hours"] * 3600 * (1 - P["shrinkage_pct"])
agent_days = (contacts_planning * P["aht_seconds"]) / (productive_s * P["occupancy_target"])
roster = pd.DataFrame({"target_date": future_dates,
                       "contacts_p50": out_cov.forecast[0],
                       "contacts_planning": contacts_planning,
                       "agents_required": np.ceil(agent_days)})
```
**Expected output:** a dated table of `agents_required` a workforce manager can act on.
**Pass/fail:** the agent count for a recent known day, recomputed with actuals, lands within a few percent of the agents actually rostered. If it is wildly off, your AHT, shrinkage or occupancy assumptions are wrong — fix those before touching the model, because **a 20% shrinkage error dwarfs a 5% forecast error**.
**Caveat to state out loud:** daily FTE maths assumes work spreads evenly across the shift. It does not, so it *under*-states peak-hour need. Until you add intraday forecasting, apply a static historical hourly arrival curve to the daily total and keep `occupancy_target` conservative (0.80–0.85, not 0.95).

### Phase 5 — Optional fine-tuning (defer it)
The repo's LoRA example targets **TimesFM 2.5**; a 3.0 path is **[not stated in sources]**. Independent work finds fine-tuned foundation models do not consistently beat smaller dedicated models for their cost (via search of [arXiv 2510.00742](https://arxiv.org/abs/2510.00742)).
**Pass/fail:** skip on a first build. Revisit only when zero-shot + covariates is live and someone can name the rupee value of the residual error.

### Phase 6 — Full rolling-origin backtest
**Goal:** the defensible comparison, scored in agent-days as well as MASE.

```python
panel = pd.read_sql("select queue_key, date_day, contacts_offered as y "
                    "from analytics.pnm.mart_pnm_contacts_daily", con)
panel["date_day"] = pd.to_datetime(panel["date_day"])
panel_wide = panel.pivot(index="date_day", columns="queue_key", values="y").asfreq("D")

origins = pd.date_range(panel_wide.index[-1] - pd.Timedelta(days=182),
                        panel_wide.index[-1] - pd.Timedelta(days=HORIZON), freq="7D")
rows = []
for t in origins:
    hist = panel_wide.loc[:t]                       # strictly pre-origin
    keys = [c for c in hist.columns if hist[c].notna().sum() >= CONTEXT]
    ctxs = [hist[c].values[-CONTEXT:].astype(np.float32) for c in keys]
    preds = list(forecaster.predict_batch(ctxs, horizon=HORIZON, return_quantiles=True))
    future = panel_wide.loc[t + pd.Timedelta(days=1): t + pd.Timedelta(days=HORIZON)]
    for c, p in zip(keys, preds):
        rows.append(pd.DataFrame({"origin": t, "queue": c,
                                  "h": np.arange(1, HORIZON + 1),
                                  "y": future[c].values,
                                  "yhat": p.forecast, "q80": p.quantiles[:, 7]}))
bt = pd.concat(rows, ignore_index=True)
```
**Expected output:** a tidy frame keyed by `(origin, queue, h)` with actual, median and q80.
**Pass/fail:** ≥20 origins per queue, every origin using data up to `t` only. `hist` is sliced before prediction, `future` only after — keep that separation; it is exactly where leakage hides.

### Phase 7 — Weekly deployment
**Goal:** a roster input the business gets without you in the loop.
**Actions:** a daily job reading the marts, calling the **production-licensed** forecaster, writing `mart_pnm_staffing_forecast_daily` (`run_date, queue_key, target_date, horizon_days, stream, contacts_p50, contacts_planning, agents_required, params_version, model_version`). Archive every run — you cannot measure drift without it. Deliver h=14 on roster-build day, refresh daily so the h=7 lock and h=1–3 flex use fresh numbers. Alert when trailing-28-day MASE degrades >20% versus backtest, actuals breach the 10–90 band three days running, or realised AHT moves >10% from the governed parameter.
**Pass/fail:** two consecutive weeks of automated runs with no manual intervention, and a workforce manager who pulls the number without asking you.

---

## 7. Evaluation

**Metrics, and why.** **MASE** as the model-selection headline: scale-free, so different-sized queues sit in one table, and 1.0 means *worse than copy-last-week*. **Weighted quantile loss** second, because you staff off q\* and a point metric cannot say whether that quantile is trustworthy. **Empirical coverage** third: what share of actuals fell inside q10–q90? Near 80% is right; 55% means your intervals are lying and the roster built on them is a guess.

**The metric that actually matters: agent-days mis-staffed.** Push every backtest row through the Phase 4 maths and report `agents_required − agents actually needed`, split into **under** and **over**. Weight by `Cu` and `Co` and you have the rupee cost of the forecast — the only number that wins budget. Report at **h=7 and h=14 specifically**; a blended average across h=1…28 flatters you with easy short horizons.

**Building the backtest.** Fix `h=28`, step origins **weekly** to mirror the roster cadence, ≥26 origins. Build context from data `≤ t` only; score against `t+1 … t+28`; compute the MASE denominator from pre-origin history only. Report by horizon bucket (h1–3, h4–7, h8–14, h15–28). Run the identical loop for all three models: same origins, same queues, same denominator.

**What "good enough" means.** In order: (1) **TimesFM MASE < AutoETS < SeasonalNaive** at h=7 and h=14 — if TimesFM cannot clear AutoETS, ship AutoETS and say so plainly; (2) a visible **skill score** (error reduction versus seasonal naive). Published leaderboard skill scores for the strongest models sit around **32–40%** (via search of [fev-bench](https://arxiv.org/abs/2509.26468): Chronos-2 35.50, TiRex-2 33.74, Toto-2.0 32.54 MASE skill; TimesFM-2.5 32.3% skill / 73.0% win rate) — averages over 100 diverse public tasks, **not a prediction about PnM**. Treat 15–25% on a dense queue series as genuinely useful; (3) coverage within a few points of nominal; (4) staffing error skewed the way your cost ratio wants — more small over-staffs than large under-staffs.

**Presenting to stakeholders.** Lead with the decision. One chart: actual versus forecast contacts over six months, 80% band shaded. One table: **agent-days over/under by horizon bucket** with a "% better than last-week-copy" column — that column is the whole argument. One slide naming where it fails (campaign launches, year-one festival weeks, the post-booking stream, peak-hour concentration). Never show MASE to a workforce manager without translating it into agents.

---

## 8. Best practices and pitfalls checklist

1. **Resolve the TimesFM 3.0 non-commercial licence before writing production code.** ([README](https://github.com/google-research/timesfm))
2. Forecast at the **roster grain**, not the city grain, unless agents are genuinely city-dedicated.
3. Forecast **contacts**, not leads — and keep the new-lead and post-booking streams separate until you sum them.
4. Measure the **contact-age kernel** from matured cohorts only; an immature kernel under-staffs you.
5. Never externally normalise inputs — the repo says feed raw values; the model normalises internally.
6. Zero-fill the date spine. A missing row is a silent calendar corruption.
7. Count post-booking workload by **conversion/move date**, and drop the unmatured tail.
8. Convert to Asia/Kolkata before bucketing to a day.
9. Never use MAPE on count data with low or zero days.
10. Build seasonal naive **and AutoETS** before TimesFM, and keep both in every comparison forever.
11. Compute the MASE denominator from **pre-origin data only**.
12. Score at **h=7 and h=14**, not a blended average across all horizons.
13. Staff to **q\*** from your own cost ratio, not to the median and not to a quantile someone guessed.
14. Sanity-check **AHT, shrinkage and occupancy** before tuning the model — parameter error dwarfs forecast error.
15. Expect the model to lag structural breaks (campaign launch, IVR change, new queue) for roughly a context window; keep a human in front of the roster during those weeks.

---

## 9. Further reading

1. **[TimesFM repository README](https://github.com/google-research/timesfm)** — authoritative for the API, checkpoints and licence. Read the licence section twice before anything else.
2. **[TimesFM 3 announcement blog](https://research.google/blog/timesfm-3-a-zero-shot-foundation-model-for-multivariate-forecasting/)** — Google's framing of multivariate and covariate support; your 2-minute manager explanation comes from here.
3. **[A decoder-only foundation model for time-series forecasting (arXiv 2310.10688)](https://arxiv.org/abs/2310.10688)** — the founding paper; the patching section shows why context length matters.
4. **[fev-bench (arXiv 2509.26468)](https://arxiv.org/abs/2509.26468)** — 100 real tasks, 46 with covariates; source of the skill-score framing and the evidence that covariates help.
5. **[How Foundational are Foundation Models for Time Series Forecasting? (arXiv 2510.00742)](https://arxiv.org/abs/2510.00742)** — the sceptical counterweight; read before promising anyone a fine-tuning roadmap.
6. **[Operational Viability of Foundation Models (arXiv 2605.24381)](https://arxiv.org/abs/2605.24381)** — inference cost, frozen-model drift, and the head/tail routing pattern that should shape production design.
7. **[Chronos-2 (arXiv 2510.15821)](https://arxiv.org/abs/2510.15821)** and its **[Apache-2.0 weights](https://huggingface.co/amazon/chronos-2)** — the most likely production-legal alternative, with native covariate support.
8. **[skaters issue #209](https://github.com/microprediction/skaters/issues/209)** — a short independent note reaching the same conclusion: v3 leads the leaderboards, but v2.5 is "the production-relevant comparison".
