-- The transactions in a statement must add up to what TikTok says the statement
-- paid out.
--
-- statement.settlement_amount is TikTok's own figure for the payout, computed
-- independently of the transaction rows. If the ledger ties to it, no transaction
-- was dropped and no sign was changed. Usual causes of a failure:
--   1. A statement whose transactions synced only partly: check the stream's run
--      history before the SQL.
--   2. A filter or INNER JOIN upstream that removed adjustment or reserve rows.
--   3. A sign that was flipped or an ABS() somewhere in the chain.
--
-- Only statements with at least one synced transaction are checked: the statement
-- list can reach further back than the transaction stream's start date, and those
-- older statements have nothing to tie to. One cent of tolerance per statement.

WITH ledger AS (
    SELECT tiktok_account, shop_id, statement_id, SUM(settlement_amount) AS ledger_total
    FROM {{ ref('core_tiktok_shop__settlement_ledger') }}
    GROUP BY 1, 2, 3
)

SELECT
    st.tiktok_account,
    st.shop_id,
    st.statement_id,
    st.settlement_amount AS statement_total,
    l.ledger_total,
    ROUND(l.ledger_total - st.settlement_amount, 2) AS diff
FROM {{ ref('stg_tiktok_shop__statement') }} st
JOIN ledger l USING (tiktok_account, shop_id, statement_id)
WHERE ABS(l.ledger_total - COALESCE(st.settlement_amount, 0)) > 0.01
