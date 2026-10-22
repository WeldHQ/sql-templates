-- analytics.netsuite.ar_ap_aging
-- BI-facing contract over the core model. Dashboards bind here so core can be
-- renamed, re-grained or split without breaking anything downstream.

SELECT * FROM {{core.netsuite.ar_ap_aging}}
