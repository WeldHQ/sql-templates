-- core_stripe__mrr_summary
-- Summarize Monthly Recurring Revenue (MRR). This SQL model provides a
-- comprehensive view of the Monthly Recurring Revenue (MRR) by categorizing the
-- revenue into new MRR, contraction MRR, churn MRR, and expansion MRR. It also
-- computes the net new MRR and total MRR over time.
--
-- From the weld.app template library. Not reconciled against Stripe;
-- check the output against the source before relying on it.

with mrr_calc as (
 select *
 , case when mrr_rank_asc = 1 then mrr_change else 0 end as new_mrr
 , case when mrr_change < 0 then mrr_change else 0 end as contraction_mrr
 , case when mrr_change > 0 and mrr_rank_asc > 1 then mrr_change else 0 end as expansion_mrr
 , case when mrr_rank_desc = 1 and status = 'canceled' then mrr * -1 else 0 end as churn_mrr
 from {{ ref('core_stripe__mrr_time_series') }})
 , net_mrr_calc as (
 select month
 , sum(new_mrr) new_mrr
 , sum(contraction_mrr) contraction_mrr
 , sum(churn_mrr) churn_mrr
 , sum(expansion_mrr) expansion_mrr
 , sum(new_mrr + contraction_mrr + churn_mrr + expansion_mrr) as net_new_mrr
 from mrr_calc
 group by month)
 select month, new_mrr, contraction_mrr, churn_mrr, expansion_mrr, net_new_mrr, sum(net_new_mrr) over (order by month asc) as mrr_total from net_mrr_calc
