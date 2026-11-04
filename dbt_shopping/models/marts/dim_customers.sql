-- Une ligne = un client. Attributs les plus récents connus.
with orders as (

    select * from {{ ref('int_orders_enriched') }}

),

latest as (

    select
        *,
        min(purchased_at) over (partition by customer_id) as first_seen_at,
        row_number() over (partition by customer_id order by purchased_at desc) as rn
    from orders

)

select
    customer_id,
    first_seen_at,
    customer_age,
    case
        when customer_age < 25 then '18-24'
        when customer_age < 35 then '25-34'
        when customer_age < 50 then '35-49'
        when customer_age < 65 then '50-64'
        else '65+'
    end                                                         as age_band,
    gender,
    location,
    is_subscriber,
    previous_purchases,
    purchase_frequency,
    {{ segment_from_previous_purchases('previous_purchases') }} as customer_segment,
    previous_purchases > 0                                      as is_returning_customer,
    case
        when is_subscriber and previous_purchases >= 5 then 'High'
        when is_subscriber or previous_purchases >= 3  then 'Medium'
        else 'Low'
    end                                                         as loyalty_level
from latest
where rn = 1
