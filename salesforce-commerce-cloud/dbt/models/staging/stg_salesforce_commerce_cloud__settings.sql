-- stg_salesforce_commerce_cloud__settings
-- Static settings per instance. No raw source: the connector does not sync site
-- preferences, so the reporting time zone has to be declared here.
--
-- WHY THIS EXISTS. Order timestamps are UTC, while Business Manager reports in the
-- site's time zone (Merchant Tools → Site Preferences → Locale and time zone).
-- Truncating UTC to a date moves late-evening orders onto the next day. Set
-- report_timezone to the IANA name your site uses. If your sites run in different
-- time zones, add a site_id column and join on it in core.

SELECT * FROM UNNEST([
    STRUCT('instance_1' AS sfcc_instance, 'UTC' AS report_timezone)
])
