-- Règles métier déplacées du job Spark vers dbt : versionnées, testées, documentées.
with orders as (

    select * from {{ ref('int_orders_deduplicated') }}

)

select
    order_id,
    customer_id,
    item_name,
    category,
    purchased_at,
    season,
    case when season in ('Spring', 'Summer') then 'High Season' else 'Low Season' end
                                                            as season_type,
    payment_method,
    shipping_type,
    has_discount,
    has_promo_code,
    review_rating,

    -- montants
    amount_usd                                              as gross_amount_usd,
    case when has_discount then amount_usd * 0.9 else amount_usd end
                                                            as net_amount_usd,
    case when has_discount then amount_usd * 0.1 else 0 end as discount_amount_usd,

    -- catégorie de panier
    case
        when (case when has_discount then amount_usd * 0.9 else amount_usd end) < 50  then 'Small'
        when (case when has_discount then amount_usd * 0.9 else amount_usd end) < 150 then 'Medium'
        when (case when has_discount then amount_usd * 0.9 else amount_usd end) < 300 then 'Large'
        else 'Premium'
    end                                                     as basket_size,

    -- satisfaction
    case
        when review_rating >= 4.5 then 'Very Satisfied'
        when review_rating >= 4.0 then 'Satisfied'
        when review_rating >= 3.0 then 'Neutral'
        when review_rating >= 2.0 then 'Dissatisfied'
        else 'Very Dissatisfied'
    end                                                     as satisfaction_level,

    -- attributs client (pour construire dim_customers)
    customer_age,
    gender,
    location,
    is_subscriber,
    previous_purchases,
    purchase_frequency

from orders
