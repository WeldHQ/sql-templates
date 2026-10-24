-- Promoters, passives and detractors must add up to every NPS answer.
--
-- Typeform's NPS question is 0 to 10 in whole numbers, so the three buckets cover
-- every possible value. A row returned here means a score outside that range
-- reached the model (a fractional value, or a question whose type was changed to
-- nps after it collected answers on another scale), and the NPS for that month is
-- computed over the wrong denominator.

SELECT
    month,
    typeform_account,
    form_id,
    field_id,
    answers,
    promoters + passives + detractors AS bucketed_answers
FROM {{ ref('core_typeform__score_summary') }}
WHERE field_type = 'nps'
  AND promoters + passives + detractors <> answers
