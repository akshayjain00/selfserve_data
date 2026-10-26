"""Derive every date window from one report_date (always = yesterday, IST). Usage: python3 periods.py [YYYY-MM-DD]"""
import sys, json, datetime as dt, calendar
def periods(r):
    R = dt.date.fromisoformat(r)
    mtd_s = R.replace(day=1)
    lm = (mtd_s - dt.timedelta(days=1))                       # last day of previous month
    ml_s = lm.replace(day=1); ml_e = lm.replace(day=min(R.day, lm.day))
    wt_s = R - dt.timedelta(days=R.weekday())                 # Monday of R's week
    wl_s = wt_s - dt.timedelta(days=7); wl_e = R - dt.timedelta(days=7)
    # 3mo/6mo avg = simple mean of the previous 3/6 months' MTD-equivalent values (day 1..R.day of each month,
    # clipped to month length) - user decision 30 Sep (replaces the old 26-week median).
    months = []; m = mtd_s
    for k in range(6):
        m = (m - dt.timedelta(days=1)).replace(day=1)
        last = calendar.monthrange(m.year, m.month)[1]
        months.append((m, m.replace(day=min(R.day, last))))
    b_s = months[-1][0]; b_e = mtd_s - dt.timedelta(days=1)
    # Full calendar months (display values for 3m/6m avg columns - user decision 6 Oct). Colouring keeps the same-days months.
    fulls = []; m = mtd_s
    for k in range(6):
        e_ = m - dt.timedelta(days=1); m = e_.replace(day=1); fulls.append((m, e_))
    lw_e = wt_s - dt.timedelta(days=1); lw_s = lw_e - dt.timedelta(days=6)   # full previous Mon-Sun week (Key Metrics 'Last week')
    single = R.weekday() == 0
    f = lambda d: d.isoformat()
    return dict(R=f(R), MTD_S=f(mtd_s), ML_S=f(ml_s), ML_E=f(ml_e), WT_S=f(wt_s), WL_S=f(wl_s), WL_E=f(wl_e),
                B_S=f(b_s), B_E=f(b_e), MTD_DAYS=R.day, WTD_DAYS=R.weekday()+1, SINGLE_DAY=single,
                RAG_BASIS='MTD' if single else 'WTD', LW_S=f(lw_s), LW_E=f(lw_e), CW_S=f((wt_s if R.weekday()==6 else lw_s) - dt.timedelta(weeks=12)), CW_E=f(R if R.weekday()==6 else lw_e),  # last 13 FULL weeks; on a Sunday the current week is complete, so it is included
                **{f'M{k+1}_S': f(a) for k,(a,b) in enumerate(months)}, **{f'M{k+1}_E': f(b) for k,(a,b) in enumerate(months)},
                **{f'F{k+1}_S': f(a) for k,(a,b) in enumerate(fulls)}, **{f'F{k+1}_E': f(b) for k,(a,b) in enumerate(fulls)})
def render(sql, P):
    for k, v in P.items():
        sql = sql.replace(f'__{k}__', str(v))
    return sql
if __name__ == '__main__':
    r = sys.argv[1] if len(sys.argv) > 1 else (dt.datetime.utcnow() + dt.timedelta(hours=5, minutes=30) - dt.timedelta(days=1)).date().isoformat()
    print(json.dumps(periods(r), indent=1))
