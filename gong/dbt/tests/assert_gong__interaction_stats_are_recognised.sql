-- Lists every interaction statistic Gong sent that core_gong__calls does not pivot
-- into a column. Gong's six standard statistics are mapped; anything listed here is
-- silently missing from the reports until a column is added for it.
--
-- Returns zero rows when every statistic is recognised.

SELECT stat_name, stat_key, COUNT(*) AS calls
FROM {{ ref('stg_gong__call_interaction') }}
WHERE stat_key NOT IN (
    'talk_ratio', 'longest_monologue', 'longest_customer_story',
    'interactivity', 'patience', 'question_rate'
)
GROUP BY 1, 2
