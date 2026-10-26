-- Test users excluded on every metric; Nano per segment toggle ({{NANO:...}} = all / nn / nano), user decision 12 Oct
-- -> data/alloc.txt
WITH {{PERIODS}}, b AS (
 SELECT TO_DATE(shifting_ts_ist) d, order_id, is_allocated, is_deallocated_post_accept, order_status, order_bucket, is_nano_order, is_test_user,
   dry_run_distance_kms, cancellation_type, allocation_tat_minutes, no_vendor_before_slot, last_rescheduled_shift_ts, deallocation_count, is_supervisor_changed, package_name, pickup_km_deviation, drop_km_deviation,
   IFF({{NANO:is_nano_order=1}} AND is_test_user=0,1,0) nn
 FROM PROD_ELDORIA.MART.PNM_ALLOCATION WHERE shifting_type='intra_city' AND TO_DATE(shifting_ts_ist) BETWEEN '__B_S__' AND '__R__'
), t AS (
SELECT p.p,
 100.0*COUNT(DISTINCT CASE WHEN is_allocated=1 AND nn=1 THEN order_id END)/NULLIF(COUNT(DISTINCT CASE WHEN nn=1 THEN order_id END),0) alloc_all,
 100.0*COUNT(DISTINCT CASE WHEN order_bucket='SPOT' AND is_allocated=1 AND nn=1 THEN order_id END)/NULLIF(COUNT(DISTINCT CASE WHEN order_bucket='SPOT' AND nn=1 THEN order_id END),0) alloc_spot,
 100.0*COUNT(DISTINCT CASE WHEN order_bucket='SCHEDULED' AND is_allocated=1 AND nn=1 THEN order_id END)/NULLIF(COUNT(DISTINCT CASE WHEN order_bucket='SCHEDULED' AND nn=1 THEN order_id END),0) alloc_sched,
 100.0*COUNT(DISTINCT CASE WHEN is_deallocated_post_accept=1 AND nn=1 THEN order_id END)/NULLIF(COUNT(DISTINCT CASE WHEN nn=1 THEN order_id END),0) dealloc,
 100.0*COUNT(DISTINCT CASE WHEN order_bucket='SPOT' AND is_deallocated_post_accept=1 AND nn=1 THEN order_id END)/NULLIF(COUNT(DISTINCT CASE WHEN order_bucket='SPOT' AND nn=1 THEN order_id END),0) dealloc_spot,
 100.0*COUNT(DISTINCT CASE WHEN order_bucket='SCHEDULED' AND is_deallocated_post_accept=1 AND nn=1 THEN order_id END)/NULLIF(COUNT(DISTINCT CASE WHEN order_bucket='SCHEDULED' AND nn=1 THEN order_id END),0) dealloc_sched,
 100.0*COUNT(DISTINCT CASE WHEN order_status='completed' AND nn=1 THEN order_id END)/NULLIF(COUNT(DISTINCT CASE WHEN nn=1 THEN order_id END),0) comp,
 100.0*COUNT(DISTINCT CASE WHEN order_bucket='SPOT' AND order_status='completed' AND nn=1 THEN order_id END)/NULLIF(COUNT(DISTINCT CASE WHEN order_bucket='SPOT' AND nn=1 THEN order_id END),0) comp_spot,
 100.0*COUNT(DISTINCT CASE WHEN order_bucket='SCHEDULED' AND order_status='completed' AND nn=1 THEN order_id END)/NULLIF(COUNT(DISTINCT CASE WHEN order_bucket='SCHEDULED' AND nn=1 THEN order_id END),0) comp_sched,
 PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY CASE WHEN order_bucket='SPOT' AND nn=1 THEN dry_run_distance_kms END) dry_p75,
 100.0*COUNT(DISTINCT CASE WHEN cancellation_type='CAC' AND order_bucket='SPOT' AND nn=1 THEN order_id END)/NULLIF(COUNT(DISTINCT CASE WHEN order_bucket='SPOT' AND nn=1 THEN order_id END),0) cac_spot,
 100.0*COUNT(DISTINCT CASE WHEN cancellation_type='PAC' AND order_bucket='SPOT' AND nn=1 THEN order_id END)/NULLIF(COUNT(DISTINCT CASE WHEN order_bucket='SPOT' AND nn=1 THEN order_id END),0) pac_spot,
 100.0*COUNT(DISTINCT CASE WHEN cancellation_type='PoAC' AND order_bucket='SPOT' AND nn=1 THEN order_id END)/NULLIF(COUNT(DISTINCT CASE WHEN order_bucket='SPOT' AND nn=1 THEN order_id END),0) poac_spot,
 100.0*COUNT(DISTINCT CASE WHEN cancellation_type='CAC' AND order_bucket='SCHEDULED' AND nn=1 THEN order_id END)/NULLIF(COUNT(DISTINCT CASE WHEN order_bucket='SCHEDULED' AND nn=1 THEN order_id END),0) cac_sched,
 100.0*COUNT(DISTINCT CASE WHEN cancellation_type='PAC' AND order_bucket='SCHEDULED' AND nn=1 THEN order_id END)/NULLIF(COUNT(DISTINCT CASE WHEN order_bucket='SCHEDULED' AND nn=1 THEN order_id END),0) pac_sched,
 100.0*COUNT(DISTINCT CASE WHEN cancellation_type='PoAC' AND order_bucket='SCHEDULED' AND nn=1 THEN order_id END)/NULLIF(COUNT(DISTINCT CASE WHEN order_bucket='SCHEDULED' AND nn=1 THEN order_id END),0) poac_sched,
 PERCENTILE_CONT(0.80) WITHIN GROUP (ORDER BY CASE WHEN is_allocated=1 AND nn=1 THEN allocation_tat_minutes END) alloc_p80,
 100.0*COUNT(DISTINCT CASE WHEN no_vendor_before_slot=1 AND nn=1 THEN order_id END)/NULLIF(COUNT(DISTINCT CASE WHEN nn=1 THEN order_id END),0) no_vendor,
 100.0*COUNT(DISTINCT CASE WHEN last_rescheduled_shift_ts IS NOT NULL AND nn=1 THEN order_id END)/NULLIF(COUNT(DISTINCT CASE WHEN nn=1 THEN order_id END),0) resched,
 100.0*COUNT(DISTINCT CASE WHEN deallocation_count>2 AND nn=1 THEN order_id END)/NULLIF(COUNT(DISTINCT CASE WHEN nn=1 THEN order_id END),0) dealloc2,
 100.0*COUNT(DISTINCT CASE WHEN is_supervisor_changed=1 AND order_status='completed' AND nn=1 THEN order_id END)/NULLIF(COUNT(DISTINCT CASE WHEN order_status='completed' AND nn=1 THEN order_id END),0) sup_chg,
 PERCENTILE_CONT(0.80) WITHIN GROUP (ORDER BY CASE WHEN order_status='completed' AND nn=1 THEN pickup_km_deviation END) pick_p80,
 PERCENTILE_CONT(0.80) WITHIN GROUP (ORDER BY CASE WHEN order_status='completed' AND nn=1 THEN drop_km_deviation END) drop_p80,
 100.0*COUNT(DISTINCT CASE WHEN nn=1 AND cancellation_type IN ('CAC','PAC','PoAC') THEN order_id END)/NULLIF(COUNT(DISTINCT CASE WHEN nn=1 THEN order_id END),0) k_cancel,
 100.0*COUNT(DISTINCT CASE WHEN nn=1 AND is_deallocated_post_accept=1 THEN order_id END)/NULLIF(COUNT(DISTINCT CASE WHEN nn=1 THEN order_id END),0) k_dealloc
FROM b JOIN periods p ON b.d BETWEEN p.s AND p.e GROUP BY p.p
), u AS (
 SELECT p, metric, val FROM (SELECT p, alloc_all::FLOAT alloc_all, alloc_spot::FLOAT alloc_spot, alloc_sched::FLOAT alloc_sched, dealloc::FLOAT dealloc, dealloc_spot::FLOAT dealloc_spot, dealloc_sched::FLOAT dealloc_sched, comp::FLOAT comp, comp_spot::FLOAT comp_spot, comp_sched::FLOAT comp_sched, dry_p75::FLOAT dry_p75, cac_spot::FLOAT cac_spot, pac_spot::FLOAT pac_spot, poac_spot::FLOAT poac_spot, cac_sched::FLOAT cac_sched, pac_sched::FLOAT pac_sched, poac_sched::FLOAT poac_sched, alloc_p80::FLOAT alloc_p80, no_vendor::FLOAT no_vendor, resched::FLOAT resched, dealloc2::FLOAT dealloc2, sup_chg::FLOAT sup_chg, pick_p80::FLOAT pick_p80, drop_p80::FLOAT drop_p80, k_cancel::FLOAT k_cancel, k_dealloc::FLOAT k_dealloc FROM t)
 UNPIVOT (val FOR metric IN (alloc_all, alloc_spot, alloc_sched, dealloc, dealloc_spot, dealloc_sched, comp, comp_spot, comp_sched, dry_p75, cac_spot, pac_spot, poac_spot, cac_sched, pac_sched, poac_sched, alloc_p80, no_vendor, resched, dealloc2, sup_chg, pick_p80, drop_p80, k_cancel, k_dealloc))
)
{{FINAL}}
