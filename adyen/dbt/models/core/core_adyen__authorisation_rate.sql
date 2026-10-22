-- core_adyen__authorisation_rate
-- Authorisation rate by day and payment method: of the payments that reached an
-- authorisation decision, the share that were authorised.
--
-- Grain: day (first decision, report time zone) x merchant account x payment
-- method x payment currency.
-- Depends on: core.adyen.payment_lifecycle
--
-- DEFINITION. A payment counts once, on the day of its first Authorised or Refused
-- record. authorisation_rate = authorised / (authorised + refused), a ratio of
-- counts. Re-aggregate the counts before dividing for weekly or monthly rates.
--
-- Each payment attempt has its own PSP reference, so a shopper who is refused and
-- then succeeds counts as one refusal and one authorisation. Adyen's Customer Area
-- can show a rate that de-duplicates retries or excludes some refusal reasons, so
-- expect a small gap against it. Refused records only appear if your Payment
-- accounting report includes them; if refused_count is always zero, check the
-- report's configuration before reading the rate.

SELECT
    DATE(LEAST(
        COALESCE(l.authorised_at_local, l.refused_at_local),
        COALESCE(l.refused_at_local, l.authorised_at_local)
    ))                                                                            AS date,
    l.merchant_account,
    l.payment_method,
    l.payment_currency,

    COUNT(*)                                                                      AS decided_count,
    COUNTIF(l.is_authorised)                                                      AS authorised_count,
    COUNTIF(NOT l.is_authorised AND l.is_refused)                                 AS refused_count,
    SUM(CASE WHEN l.is_authorised THEN l.authorised_amount ELSE 0 END)            AS authorised_amount,
    SAFE_DIVIDE(COUNTIF(l.is_authorised), COUNT(*))                               AS authorisation_rate
FROM {{ ref('core_adyen__payment_lifecycle') }} l
WHERE l.is_authorised OR l.is_refused
GROUP BY 1, 2, 3, 4
