-- An invoice can not owe more than it was issued for, or a negative amount.
-- Returns zero rows when it holds.

SELECT invoice_id, invoice_number, amount, due_amount
FROM {{ ref('core_harvest__invoice_aging') }}
WHERE due_amount < 0
   OR due_amount > amount + 0.01
