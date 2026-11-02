import re, sys
def render(sql, exp="ptl_service_comprhension", start="2026-10-01", end="2026-10-21", gran="day", extra=None):
    vals = {"experiment_id": f"'{exp}'", "start_date": f"'{start}'", "end_date": f"'{end}'",
            "granularity": f"'{gran}'", "cancellation_source": "'Customer_App'"}
    vals.update(extra or {})
    def opt(m):
        body = m.group(1); tags = re.findall(r"\{\{(\w+)\}\}", body)
        return body if all(t in vals for t in tags) else ""
    sql = re.sub(r"\[\[(.*?)\]\]", opt, sql, flags=re.S)
    return re.sub(r"\{\{(\w+)\}\}", lambda m: vals[m.group(1)], sql)
