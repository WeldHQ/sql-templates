-- staging.amazon_seller.marketplace
-- Static map from Amazon's marketplace domain to its marketplace ID. No raw source.
--
-- WHY THIS EXISTS. Amazon identifies the marketplace three different ways depending
-- on which report you are reading, and the values do not overlap:
--
--   marketplace_id    'ATVPDKIKX0DER'  Business Reports, listings, returns, inventory
--   sales_channel     'Amazon.com'     the order report
--   marketplace_name  'Amazon.com'     the settlement report
--
-- Every model in this library keys on `marketplace_id`, because it is the only one of
-- the three that is a stable identifier rather than a display string. The two
-- name-based reports are resolved through this map in staging, so nothing downstream
-- has to know the difference. Without it, joining order data to listings compares
-- 'Amazon.com' against 'ATVPDKIKX0DER' and matches nothing - silently, since a
-- LEFT JOIN just returns NULLs.
--
-- These IDs are public and stable. If you sell in a marketplace that is not listed,
-- add it here and nothing else changes;
-- tests/assert_marketplace_keys_are_consistent.sql fails on any unmapped value rather
-- than letting it through as a broken join key.

SELECT * FROM UNNEST([
    STRUCT('amazon.com'       AS marketplace_domain, 'ATVPDKIKX0DER'  AS marketplace_id, 'US' AS country_code, 'NA' AS region),
    ('amazon.ca',            'A2EUQ1WTGCTBG2', 'CA', 'NA'),
    ('amazon.com.mx',        'A1AM78C64UM0Y8', 'MX', 'NA'),
    ('amazon.com.br',        'A2Q3Y263D00KWC', 'BR', 'NA'),

    ('amazon.co.uk',         'A1F83G8C2ARO7P', 'GB', 'EU'),
    ('amazon.de',            'A1PA6795UKMFR9', 'DE', 'EU'),
    ('amazon.fr',            'A13V1IB3VIYZZH', 'FR', 'EU'),
    ('amazon.it',            'APJ6JRA9NG5V4',  'IT', 'EU'),
    ('amazon.es',            'A1RKKUPIHCS9HS', 'ES', 'EU'),
    ('amazon.nl',            'A1805IZSGTT6HS', 'NL', 'EU'),
    ('amazon.se',            'A2NODRKZP88ZB9', 'SE', 'EU'),
    ('amazon.pl',            'A1C3SOZRARQ6R3', 'PL', 'EU'),
    ('amazon.com.be',        'AMEN7PMS3EDWL',  'BE', 'EU'),
    ('amazon.com.tr',        'A33AVAJ2PDY3EV', 'TR', 'EU'),
    ('amazon.ae',            'A2VIGQ35RCS4UG', 'AE', 'EU'),
    ('amazon.sa',            'A17E79C6D8DWNP', 'SA', 'EU'),
    ('amazon.eg',            'ARBP9OOSHTCHU',  'EG', 'EU'),
    ('amazon.in',            'A21TJRUUN4KGV',  'IN', 'EU'),
    ('amazon.co.za',         'AE08WJ6YKNBMC',  'ZA', 'EU'),

    ('amazon.co.jp',         'A1VC38T7YXB528', 'JP', 'FE'),
    ('amazon.com.au',        'A39IBJ37TRP1C6', 'AU', 'FE'),
    ('amazon.sg',            'A19VAU5U5O7RUS', 'SG', 'FE')
])
