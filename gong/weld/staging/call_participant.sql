-- staging.gong.call_participant
-- Thin wrapper over raw `call_participant`: one row per party on a call, from the
-- call's `parties` list.
--
-- `affiliation` is Gong's own 'Internal' / 'External' / 'Unknown', decided from the
-- participant's email domain against your company's domains. `user_id` is set only
-- for participants who are Gong users. `speaker_id` links to
-- staging.gong.call_speaker; a participant who never spoke has none.
--
-- Deduped on (call_id, id) because a call re-read by the weekly lookback rewrites
-- its participants.
--
-- Single Gong instance; see staging.gong.call.

SELECT
    'account_1'                                        AS gong_account,
    CAST(call_id AS STRING)                            AS call_id,
    CAST(id AS STRING)                                 AS participant_id,
    INITCAP(NULLIF(CAST(affiliation AS STRING), ''))   AS affiliation,
    NULLIF(CAST(user_id AS STRING), '')                AS user_id,
    NULLIF(CAST(speaker_id AS STRING), '')             AS speaker_id,
    NULLIF(TRIM(CAST(name AS STRING)), '')             AS name,
    LOWER(NULLIF(TRIM(CAST(email_address AS STRING)), '')) AS email_address,
    NULLIF(TRIM(CAST(title AS STRING)), '')            AS title
FROM {{raw.gong.call_participant}}
WHERE call_id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY call_id, id ORDER BY _weld_synced DESC) = 1
