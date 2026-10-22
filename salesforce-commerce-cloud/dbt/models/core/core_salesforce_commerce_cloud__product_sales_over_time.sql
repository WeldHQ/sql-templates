-- core_salesforce_commerce_cloud__product_sales_over_time
-- The sales equation per product line, on the day the order was placed.
--
-- Grain: day x instance x site x order x product line. Currency: the order's own.
-- Timezone: staging.salesforce_commerce_cloud.settings.report_timezone.
--
-- Depends on: staging.salesforce_commerce_cloud.order, .order_product_item, .settings
--
-- Same order filter as sales_over_time (new, open, completed), and the same
-- limitation: no returns are synced, so there are no RETURN rows.
--
-- Order-level discounts are already allocated to lines by Commerce Cloud itself
-- (price_after_order_discount), so net_sales here sums to net_sales in
-- sales_over_time without any allocation of our own.
-- tests/assert_product_reconciles_to_sales.sql checks it.

WITH settings AS (
    SELECT sfcc_instance, report_timezone
    FROM {{ ref('stg_salesforce_commerce_cloud__settings') }}
)

SELECT
    DATE(COALESCE(o.placed_at, o.created_at), s.report_timezone)   AS date,
    o.sfcc_instance,
    o.site_id,
    o.order_no,
    i.item_position,
    i.item_id,
    i.product_id,
    i.product_name,
    i.is_bonus_item,
    o.currency,
    o.taxation = 'gross'                                            AS prices_include_tax,
    o.status,

    i.quantity,
    i.base_price                                                    AS unit_price,
    i.price                                                         AS gross_sales,
    i.price_after_item_discount - i.price                           AS item_discounts,
    i.price_after_order_discount - i.price_after_item_discount      AS order_discounts,
    i.price_after_order_discount                                    AS net_sales,
    -- The line's tax after discounts. In a gross-taxation site it is contained in
    -- net_sales; in a net-taxation site it is on top.
    i.adjusted_tax                                                  AS taxes,
    i.price_after_order_discount
        - IF(o.taxation = 'gross', COALESCE(i.adjusted_tax, 0), 0)  AS net_sales_ex_tax
FROM {{ ref('stg_salesforce_commerce_cloud__order_product_item') }} i
JOIN {{ ref('stg_salesforce_commerce_cloud__order') }} o USING (sfcc_instance, order_no)
JOIN settings s USING (sfcc_instance)
WHERE o.status IN ('new', 'open', 'completed')
