-- Costs are positive after staging flips Twilio's sign.
--
-- Twilio reports every charge as a negative price. Staging multiplies by -1 so that cost
-- adds up the way finance expects. A negative cost here means Twilio changed the sign
-- convention for a product, or a refund line appeared, and spend totals are understated.

SELECT 'messaging_daily' AS model, CAST(date AS STRING) AS date, cost
FROM {{ ref('core_twilio__messaging_daily') }}
WHERE cost < 0

UNION ALL

SELECT 'calls_daily', CAST(date AS STRING), cost
FROM {{ ref('core_twilio__calls_daily') }}
WHERE cost < 0
