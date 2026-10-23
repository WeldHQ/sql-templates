-- core.hubspot.conversion_from_contacts_to_deals_by_owner
-- Conversion from contacts to deals by owner. Converts contacts to deals by owner
-- in HubSpot, displaying the owner's name, the number of contacts they have, the
-- number of deals they have, and the conversion rate between the two. It uses left
-- joins to connect the necessary tables and groups the results by owner.
--
-- Owner is the contact's owner. Each contact and each deal counts once per
-- owner, however many associations link them; conversion_rate is deals per
-- 100 contacts.
--
-- From the weld.app template library, corrected. Not reconciled against
-- HubSpot; check the output against the source before relying on it.

select
concat(owners.firstName, ' ', owners.lastName) as owner
, count(distinct contacts.id) as contacts
, count(distinct deals.id) as deals
, safe_divide(count(distinct deals.id), count(distinct contacts.id)) * 100 as conversion_rate
from
{{raw.hubspot.contacts}} as contacts
left join {{raw.hubspot.contact_deal}} as contact_deal on contact_deal.contact_id = contacts.id
left join {{raw.hubspot.deals}} as deals on deals.id = contact_deal.deal_id
left join {{raw.hubspot.owners}} as owners on cast(owners.id as string) = cast(contacts.properties_hubspot_owner_id as string)
group by
owner
