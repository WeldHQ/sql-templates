-- core_fourth__staffing_accuracy
-- Fourth's productivity view: of the hours worked each day, how many were at the
-- right staffing level, and how many under or over the requirement.
-- Grain: date x location.
--
-- Shares are computed per row over correctly + under + over staffed hours.
-- Re-aggregate by summing the hour columns and dividing, not by averaging shares.

SELECT
    date,
    location_id,
    location_name,
    correctly_staffed_hours,
    understaffed_hours,
    overstaffed_hours,
    passive_hours,
    SAFE_DIVIDE(correctly_staffed_hours, correctly_staffed_hours + understaffed_hours + overstaffed_hours) AS correctly_staffed_share,
    SAFE_DIVIDE(understaffed_hours,      correctly_staffed_hours + understaffed_hours + overstaffed_hours) AS understaffed_share,
    SAFE_DIVIDE(overstaffed_hours,       correctly_staffed_hours + understaffed_hours + overstaffed_hours) AS overstaffed_share
FROM {{ ref('stg_fourth__labour_daily_summary') }}
