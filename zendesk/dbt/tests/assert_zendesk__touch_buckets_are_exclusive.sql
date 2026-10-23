-- One-, two- and multi-touch are mutually exclusive, and only solved tickets can
-- be in one. A ticket in two buckets, or an unsolved ticket in any, means the
-- reply-count thresholds in ticket_lifecycle drifted apart.

SELECT zendesk_account, ticket_id, is_solved, is_one_touch, is_two_touch, is_multi_touch
FROM {{ ref('core_zendesk__ticket_lifecycle') }}
WHERE IF(is_one_touch, 1, 0) + IF(is_two_touch, 1, 0) + IF(is_multi_touch, 1, 0) > 1
   OR (NOT is_solved AND (is_one_touch OR is_two_touch OR is_multi_touch))
