-- staging.gong.user
-- Thin wrapper over raw `user`: every Gong user, active or not, with their
-- manager. Current state only; the connector reads the full list each sync.
--
-- Single Gong instance; see staging.gong.call.

SELECT
    'account_1'                                             AS gong_account,
    CAST(id AS STRING)                                      AS user_id,
    NULLIF(TRIM(CONCAT(COALESCE(first_name, ''), ' ', COALESCE(last_name, ''))), '')
                                                            AS user_name,
    LOWER(NULLIF(TRIM(CAST(email_address AS STRING)), '')) AS email_address,
    NULLIF(TRIM(CAST(title AS STRING)), '')                 AS title,
    NULLIF(CAST(manager_id AS STRING), '')                  AS manager_id,
    COALESCE(CAST(active AS BOOL), FALSE)                   AS is_active,
    CAST(created AS TIMESTAMP)                              AS created_at
FROM {{raw.gong.user}}
WHERE id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) = 1
