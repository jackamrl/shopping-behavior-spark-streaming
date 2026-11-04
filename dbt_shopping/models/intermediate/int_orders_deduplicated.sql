-- Filet de sécurité : Spark déduplique déjà en streaming (left anti-join sur le hash),
-- mais un rechargement manuel de RAW peut réintroduire des doublons.
-- On recalcule le même hash et on garde la ligne la plus récente.
with orders as (

    select * from {{ ref('stg_orders') }}

),

hashed as (

    select
        {{ row_hash([
            'customer_id', 'customer_age', 'gender', 'item_name', 'category',
            'amount_usd', 'location', 'size', 'color', 'season', 'review_rating',
            'is_subscriber', 'shipping_type', 'has_discount', 'has_promo_code',
            'previous_purchases', 'payment_method', 'purchase_frequency'
        ]) }} as order_id,
        *
    from orders

),

ranked as (

    select
        *,
        row_number() over (partition by order_id order by purchased_at desc) as rn
    from hashed

)

select * exclude (rn)
from ranked
where rn = 1
