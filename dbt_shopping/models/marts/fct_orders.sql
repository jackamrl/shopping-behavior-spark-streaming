-- Une ligne = un achat. Table de faits du modèle en étoile.
select
    o.order_id,
    o.customer_id,
    md5(lower(o.item_name))   as product_id,
    o.purchased_at,
    cast(o.purchased_at as date) as purchase_date,
    o.season,
    o.season_type,
    o.payment_method,
    o.shipping_type,
    o.has_discount,
    o.has_promo_code,
    o.basket_size,
    o.review_rating,
    o.satisfaction_level,
    o.gross_amount_usd,
    o.discount_amount_usd,
    o.net_amount_usd
from {{ ref('int_orders_enriched') }} o
