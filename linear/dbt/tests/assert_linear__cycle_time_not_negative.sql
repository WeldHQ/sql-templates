-- Completion can not precede creation or start. Returns zero rows when it holds.
-- A failure points at timestamps that were cast in the wrong zone, or at issues
-- imported from another tool with back-dated creation times.

SELECT issue_id, identifier, lead_time_days, cycle_time_days
FROM {{ ref('core_linear__issue_cycle_time') }}
WHERE lead_time_days < 0
   OR cycle_time_days < 0
