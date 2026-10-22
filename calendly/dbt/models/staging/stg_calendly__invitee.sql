-- stg_calendly__invitee
-- Thin wrapper over raw `list_event_invitees`. One row per invitee booking on a
-- scheduled event. Casts, renames, unpacks tracking (UTM), no-show and payment.
--
-- DEDUPED ON uri, because invitees are read per scheduled event and a multi-host
-- event is read once per host (see staging.calendly.scheduled_event).
--
-- RESCHEDULES. Calendly models a reschedule as a cancel plus a new booking: the old
-- invitee goes to status 'canceled' with rescheduled = TRUE and new_invitee set,
-- and the replacement invitee carries old_invitee. is_new_booking marks the rows
-- that are a genuinely new booking, so a meeting moved twice is not counted as
-- three bookings.
--
-- WHAT IS NOT HERE: the invitee's own cancellation object (who canceled, when, why)
-- is not synced. Cancellation detail lives on the scheduled event instead, and for
-- a one-on-one meeting it is the same thing.
--
-- Single Calendly organisation; see staging.calendly.scheduled_event.

SELECT
    'account_1'                                           AS calendly_account,
    CAST(uri AS STRING)                                   AS invitee_uri,
    CAST(event AS STRING)                                 AS event_uri,
    LOWER(NULLIF(TRIM(CAST(email AS STRING)), ''))        AS email,
    NULLIF(TRIM(CAST(name AS STRING)), '')                AS name,
    LOWER(CAST(status AS STRING))                         AS status,
    CAST(timezone AS STRING)                              AS timezone,
    -- When the invitee booked. Booking lead time is measured from here.
    SAFE_CAST(created_at AS TIMESTAMP)                    AS booked_at,
    SAFE_CAST(updated_at AS TIMESTAMP)                    AS updated_at,

    COALESCE(CAST(rescheduled AS BOOL), FALSE)            AS is_rescheduled,
    NULLIF(CAST(old_invitee AS STRING), '')               AS old_invitee_uri,
    NULLIF(CAST(new_invitee AS STRING), '')               AS new_invitee_uri,
    NULLIF(CAST(old_invitee AS STRING), '') IS NULL       AS is_new_booking,

    NULLIF(CAST(routing_form_submission AS STRING), '')   AS routing_form_submission_uri,
    NULLIF(CAST(scheduling_method AS STRING), '')         AS scheduling_method,
    NULLIF(CAST(invitee_scheduled_by AS STRING), '')      AS invitee_scheduled_by,

    -- UTM parameters on the booking link. Blank strings become NULL so they group
    -- with genuinely untracked bookings.
    NULLIF(JSON_VALUE(tracking, '$.utm_source'), '')      AS utm_source,
    NULLIF(JSON_VALUE(tracking, '$.utm_medium'), '')      AS utm_medium,
    NULLIF(JSON_VALUE(tracking, '$.utm_campaign'), '')    AS utm_campaign,
    NULLIF(JSON_VALUE(tracking, '$.utm_content'), '')     AS utm_content,
    NULLIF(JSON_VALUE(tracking, '$.utm_term'), '')        AS utm_term,
    NULLIF(JSON_VALUE(tracking, '$.salesforce_uuid'), '') AS salesforce_uuid,

    -- no_show is NULL unless the host marked the invitee as a no-show.
    JSON_VALUE(no_show, '$.uri') IS NOT NULL              AS is_no_show,
    SAFE_CAST(JSON_VALUE(no_show, '$.created_at') AS TIMESTAMP) AS no_show_marked_at,

    -- Payment collected at booking (Stripe or PayPal), in the event type's currency.
    SAFE_CAST(JSON_VALUE(payment, '$.amount') AS NUMERIC) AS payment_amount,
    JSON_VALUE(payment, '$.currency')                     AS payment_currency,
    SAFE_CAST(JSON_VALUE(payment, '$.successful') AS BOOL) AS payment_successful
FROM {{ source('calendly', 'list_event_invitees') }}
WHERE uri IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY uri ORDER BY SAFE_CAST(updated_at AS TIMESTAMP) DESC) = 1
