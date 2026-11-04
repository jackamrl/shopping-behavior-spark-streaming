-- Staging : 1 modèle = 1 source. Typage, nettoyage, noms clairs. Aucune règle métier.
with source as (

    select * from {{ source('shopping_raw', 'orders') }}

),

renamed as (

    select
        -- identifiants
        cast(customer_id as integer)                as customer_id,

        -- client
        cast(age as integer)                        as customer_age,
        lower(trim(gender))                         as gender,
        trim(location)                              as location,
        trim(subscription_status) = 'Yes'           as is_subscriber,
        cast(previous_purchases as integer)         as previous_purchases,
        trim(frequency_of_purchases)                as purchase_frequency,

        -- produit
        trim(item_purchased)                        as item_name,
        trim(category)                              as category,
        trim(size)                                  as size,
        trim(color)                                 as color,

        -- achat
        cast(purchase_amount_usd as double)         as amount_usd,
        trim(discount_applied) = 'Yes'              as has_discount,
        trim(promo_code_used) = 'Yes'               as has_promo_code,
        trim(payment_method)                        as payment_method,
        trim(shipping_type)                         as shipping_type,
        trim(season)                                as season,
        cast(review_rating as double)               as review_rating,

        -- technique : horodatage d'ingestion par Spark (sert de date d'achat)
        cast(processed_time as timestamp)           as purchased_at

    from source

)

select * from renamed
