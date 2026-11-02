-- PROD_CURATED.PARTLOAD_ANALYTICS.COMPATIBLE_ROUTES
-- Source: "Compatible Routes" sheet (Sheet2)
-- https://docs.google.com/spreadsheets/d/1ko-1keM12o5suJ8SnMSQkCGY8gmPcx79zeqY6PuIuT4/edit?gid=1053669910
-- Prepared 2026-10-15. PTL_ROUTES is NOT modified.
--
-- Grain: one row per (route_id, compatible_route_id). Each route also pairs with itself,
-- matching how PTL_ROUTES.COMPATIBLE_ROUTES stores it, so
--   array_agg(compatible_route_id) within group (order by compatible_route_id)
-- grouped by route_id gives back the same array format.
--
-- Sheet names mapped to PTL_ROUTES ids. Typos resolved: Davangere->Davanagere,
-- Dharmapuri->Dharmpuri, Chikmagalur->Chikkamagalur, Vijaywada->Vijayawada.
-- Compatibility is two-way (confirmed 2026-10-15): if A lists B, B also gets A. This adds
-- rows for 44, 59, 80, which have no row of their own in the sheet.
-- 59 routes, 111 rows.

create or replace table prod_curated.partload_analytics.compatible_routes as
with pairs as (
  select column1 as route_id, column2 as compatible_route_id from values
    (1, 1),
    (1, 9),
    (1, 11),
    (1, 52),
    (2, 2),
    (3, 3),
    (3, 7),
    (4, 4),
    (5, 5),
    (5, 6),
    (5, 60),
    (6, 5),
    (6, 6),
    (6, 60),
    (7, 3),
    (7, 7),
    (8, 8),
    (8, 10),
    (9, 1),
    (9, 9),
    (9, 11),
    (10, 8),
    (10, 10),
    (11, 1),
    (11, 9),
    (11, 11),
    (12, 12),
    (12, 13),
    (13, 12),
    (13, 13),
    (14, 14),
    (15, 15),
    (15, 55),
    (16, 16),
    (16, 59),
    (17, 17),
    (18, 18),
    (19, 19),
    (20, 20),
    (21, 21),
    (22, 22),
    (22, 55),
    (23, 23),
    (24, 24),
    (25, 25),
    (25, 32),
    (26, 26),
    (26, 39),
    (27, 27),
    (28, 28),
    (29, 29),
    (29, 75),
    (32, 25),
    (32, 32),
    (35, 35),
    (35, 36),
    (36, 35),
    (36, 36),
    (39, 26),
    (39, 39),
    (40, 40),
    (40, 53),
    (41, 41),
    (41, 42),
    (41, 44),
    (42, 41),
    (42, 42),
    (42, 44),
    (44, 41),
    (44, 42),
    (44, 44),
    (45, 45),
    (45, 47),
    (46, 46),
    (46, 58),
    (46, 80),
    (47, 45),
    (47, 47),
    (52, 1),
    (52, 52),
    (53, 40),
    (53, 53),
    (55, 15),
    (55, 22),
    (55, 55),
    (56, 56),
    (56, 57),
    (57, 56),
    (57, 57),
    (58, 46),
    (58, 58),
    (59, 16),
    (59, 59),
    (60, 5),
    (60, 6),
    (60, 60),
    (65, 65),
    (66, 66),
    (71, 71),
    (72, 72),
    (73, 73),
    (74, 74),
    (75, 29),
    (75, 75),
    (76, 76),
    (80, 46),
    (80, 80),
    (83, 83),
    (83, 84),
    (84, 83),
    (84, 84)
),
names as (
  select route_id, trim(route_name) as route_name
  from prod_curated.partload_analytics.ptl_routes
  where is_active = 'True'
)
select
  p.route_id,
  r.route_name,
  p.compatible_route_id,
  c.route_name as compatible_route_name,
  current_date() as created_at
from pairs p
left join names r on r.route_id = p.route_id
left join names c on c.route_id = p.compatible_route_id
order by p.route_id, p.compatible_route_id;

-- Checks: expect 111 rows, 59 routes, 0 missing names, 0 one-way pairs
select count(*) as n_rows,
       count(distinct route_id) as n_routes,
       count_if(route_name is null or compatible_route_name is null) as missing_names
from prod_curated.partload_analytics.compatible_routes;

select a.route_id, a.compatible_route_id
from prod_curated.partload_analytics.compatible_routes a
left join prod_curated.partload_analytics.compatible_routes b
  on b.route_id = a.compatible_route_id and b.compatible_route_id = a.route_id
where b.route_id is null;
