-- staging.recurly.subscription
-- Thin wrapper over raw `subscription`. One row per subscription, current state.
-- Casts and renames only.
--
-- state is one of future, in_trial, active, paused, canceled, expired. A
-- `canceled` subscription still runs until expires_at; only `expired` has ended.
-- expiration_reason is Recurly's own label for why it ended. It is normalised to
-- lower case with underscores here (Recurly has used both "Non-payment" and
-- "nonpayment" style values), and grouped in core.

SELECT
    CAST(id AS STRING)                                          AS subscription_id,
    CAST(account_id AS STRING)                                  AS account_id,
    CAST(plan_id AS STRING)                                     AS plan_id,
    LOWER(CAST(state AS STRING))                                AS state,
    UPPER(NULLIF(TRIM(CAST(currency AS STRING)), ''))           AS currency,
    NULLIF(
        REGEXP_REPLACE(LOWER(TRIM(CAST(expiration_reason AS STRING))), r'[\s\-]+', '_'),
        ''
    )                                                           AS expiration_reason,
    CAST(created_at AS TIMESTAMP)                               AS created_at,
    CAST(activated_at AS TIMESTAMP)                             AS activated_at,
    CAST(trial_ends_at AS TIMESTAMP)                            AS trial_ends_at,
    CAST(canceled_at AS TIMESTAMP)                              AS canceled_at,
    CAST(expires_at AS TIMESTAMP)                               AS expires_at
FROM {{raw.recurly.subscription}}
QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) = 1
