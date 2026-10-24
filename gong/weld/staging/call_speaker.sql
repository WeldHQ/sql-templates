-- staging.gong.call_speaker
-- Thin wrapper over raw `call_speaker`: talk time per speaker on a call, from
-- Gong's `interaction.speakers`. `talk_time` is in seconds.
--
-- Deduped on (call_id, speaker id).
--
-- Single Gong instance; see staging.gong.call.

SELECT
    'account_1'                              AS gong_account,
    CAST(call_id AS STRING)                  AS call_id,
    CAST(id AS STRING)                       AS speaker_id,
    NULLIF(CAST(user_id AS STRING), '')      AS user_id,
    CAST(talk_time AS FLOAT64)               AS talk_time_seconds
FROM {{raw.gong.call_speaker}}
WHERE call_id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY call_id, id ORDER BY _weld_synced DESC) = 1
