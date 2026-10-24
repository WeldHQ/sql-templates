-- The channel columns in response_volume split `responses` without gaps or
-- overlaps: email, SMS, anonymous link, personal link and other must add up to
-- the total on every row. A new channel value that slips through both a named
-- column and the catch-all would show up here.

SELECT day, qualtrics_account, survey_id, responses,
       responses_email + responses_sms + responses_anonymous_link
         + responses_personal_link + responses_other_channel AS channel_total
FROM {{ ref('core_qualtrics__response_volume') }}
WHERE responses <> responses_email + responses_sms + responses_anonymous_link
                 + responses_personal_link + responses_other_channel
