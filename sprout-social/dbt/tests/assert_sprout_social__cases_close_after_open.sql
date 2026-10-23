-- A closed case cannot close before it was created.

SELECT case_id, created_at, last_closed_at, hours_to_close
FROM {{ ref('core_sprout_social__case_resolution') }}
WHERE hours_to_close < 0
