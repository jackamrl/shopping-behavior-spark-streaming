-- Une remise ne peut jamais augmenter le montant payé.
select order_id, gross_amount_usd, net_amount_usd
from {{ ref('fct_orders') }}
where net_amount_usd > gross_amount_usd
