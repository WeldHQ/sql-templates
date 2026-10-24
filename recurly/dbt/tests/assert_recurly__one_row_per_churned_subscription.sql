-- One row per expired subscription in the churn model.
--
-- A duplicate would count one lost subscription, and its MRR, twice. The likely
-- causes are the staging model losing its de-duplication or the account join no
-- longer being unique.

SELECT
    subscription_id,
    COUNT(*) AS row_count
FROM {{ ref('core_recurly__subscription_churn') }}
GROUP BY 1
HAVING COUNT(*) > 1
