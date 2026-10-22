-- One row per payment in the lifecycle model.
--
-- Downstream joins (to orders, to the authorisation rate) assume it. A duplicate
-- means psp_reference is no longer unique within a merchant account, which would
-- double every amount joined through it.

SELECT
    merchant_account,
    psp_reference,
    COUNT(*) AS row_count
FROM {{ ref('core_adyen__payment_lifecycle') }}
GROUP BY 1, 2
HAVING COUNT(*) > 1
