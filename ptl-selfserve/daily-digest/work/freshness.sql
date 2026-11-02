select to_char(max(created_at + interval '330 minutes'),'YYYY-MM-DD HH24:MI') as s
from prod_curated.partload_application.orders