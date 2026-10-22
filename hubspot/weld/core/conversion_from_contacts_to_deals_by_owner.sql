-- core.hubspot.conversion_from_contacts_to_deals_by_owner
-- Conversion from contacts to deals by owner. Converts contacts to deals by owner
-- in HubSpot, displaying the owner's name, the number of contacts they have, the
-- number of deals they have, and the conversion rate between the two. It uses left
-- joins to connect the necessary tables and groups the results by owner.
--
-- From the weld.app template library. Not reconciled against HubSpot;
-- check the output against the source before relying on it.

select
concat(owners.firstName, ' ', owners.lastName) as owner
, count(contacts.id) as contacts
, count(deals.id) as deals
, count(deals.id) / count(contacts.id) * 100 as conversion_rate
from
{{raw.hubspot.contacts}} as contacts
left join {{raw.hubspot.contact_deal}} as contact_deal on contact_deal.contact_id = contacts.id
left join {{raw.hubspot.deals}} as deals on deals.id = contact_deal.deal_id
left join {{raw.hubspot.owners}} as owners on owners.id = contacts.properties_hubspot_owner_id
group by
owner
