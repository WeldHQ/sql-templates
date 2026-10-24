-- Tickets created per month must agree between the daily volume model and the
-- monthly first-response model, once outbound tickets (which the monthly model
-- leaves out by design) are added back.

WITH daily AS (
    SELECT freshdesk_account, DATE_TRUNC(day, MONTH) AS month, SUM(tickets_created) AS created
    FROM {{ ref('core_freshdesk__ticket_volume_by_day') }}
    GROUP BY 1, 2
),

monthly AS (
    SELECT freshdesk_account, month, SUM(tickets_created) AS created
    FROM {{ ref('core_freshdesk__first_response_by_month') }}
    GROUP BY 1, 2
),

outbound AS (
    SELECT freshdesk_account, DATE_TRUNC(created_date, MONTH) AS month, COUNT(*) AS created
    FROM {{ ref('core_freshdesk__ticket_lifecycle') }}
    WHERE is_outbound AND created_date IS NOT NULL
    GROUP BY 1, 2
)

SELECT d.freshdesk_account, d.month, d.created, m.created AS inbound, o.created AS outbound
FROM daily d
LEFT JOIN monthly m USING (freshdesk_account, month)
LEFT JOIN outbound o USING (freshdesk_account, month)
WHERE d.created != COALESCE(m.created, 0) + COALESCE(o.created, 0)
