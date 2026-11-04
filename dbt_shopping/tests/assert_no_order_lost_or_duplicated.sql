-- Le nombre d'achats dans les marts doit être égal au nombre d'achats distincts en staging.
-- Échoue si une jointure a multiplié des lignes ou si des achats ont été perdus.
with staging as (
    select count(*) as n from {{ ref('int_orders_deduplicated') }}
),
marts as (
    select count(*) as n from {{ ref('fct_orders') }}
)
select staging.n as staging_rows, marts.n as marts_rows
from staging, marts
where staging.n != marts.n
