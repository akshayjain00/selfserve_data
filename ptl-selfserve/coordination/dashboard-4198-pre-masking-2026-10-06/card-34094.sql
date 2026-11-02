SELECT 
  CAST(DATE_TRUNC({{period}}, TO_DATE("PL_Ticket_Created_Date", 'YYYY-MM-DD')) AS DATE) AS dated,
  COUNT(DISTINCT "PL_Ticket_ID") AS total_tickets,
  COUNT(DISTINCT CASE WHEN "FCR" = 'TRUE' THEN "PL_Ticket_ID" END) AS fcr_tickets,
  ROUND(
    COUNT(DISTINCT CASE WHEN "FCR" = 'TRUE' THEN "PL_Ticket_ID" END)
    / NULLIF(COUNT(DISTINCT "PL_Ticket_ID"), 0),
    2
  ) AS fcr_percentage
FROM GSHEET_SYNC.PTL_TICKETS
LEFT JOIN prod_curated.partload_analytics.PTL_INTERNAL_USERS
  ON PTL_TICKETS."Mobile" = PTL_INTERNAL_USERS.mobile
WHERE 
  PTL_TICKETS."Mobile" NOT IN (SELECT MOBILE FROM PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS)
  AND (TO_DATE("PL_Ticket_Created_Date", 'YYYY-MM-DD')) >=  {{start_date}} 
and (TO_DATE("PL_Ticket_Created_Date", 'YYYY-MM-DD')) <= {{end_date}} 
AND COALESCE("Other_Issue", '') NOT ILIKE '%other%' 
AND COALESCE("Other_Issue", '') NOT ILIKE '%test%' 
AND COALESCE("Other_Issue", '') NOT ILIKE '%courier%' 
AND COALESCE("Other_Issue", '') NOT ILIKE '%packer%'
AND COALESCE("Other_Issue", '') NOT ILIKE '%depart%'
AND COALESCE("Other_Sub_Issue", '') NOT ILIKE '%courier%' 
AND COALESCE("Other_Sub_Issue", '') NOT ILIKE '%test%' 
AND COALESCE("Issue", '') NOT ILIKE '%Non PTL related%'
GROUP BY 1
ORDER BY 1 desc;