-- core.xero.journal_entries_report
-- Journal Entries Report. This template generates a report on journal entries from
-- Xero, breaking down the data by year and month. It gives you a count of all
-- journal entries and a count of individual journal lines for each journal entry
-- within the specified periods.
--
-- Entries are counted once each; lines are the journal lines joined to them,
-- so a journal with no lines counts as an entry with zero lines.
--
-- From the weld.app template library, corrected. Not reconciled against Xero;
-- check the output against the source before relying on it.

SELECT
EXTRACT(YEAR FROM journal_date) AS year,
EXTRACT(MONTH FROM journal_date) AS month,
COUNT(DISTINCT j.journal_id) AS number_of_journal_entries,
COUNT(jl.journal_line_id) AS number_of_journal_lines
FROM
{{raw.xero.journal}} j
-- Join with journal_line to count the number of journal lines for each journal entry
LEFT JOIN
{{raw.xero.journal_line}} jl
ON
j.journal_id = jl.journal_id
GROUP BY
1,2
ORDER BY
year DESC,
month DESC
