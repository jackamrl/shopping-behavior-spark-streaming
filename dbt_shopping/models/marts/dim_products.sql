-- Une ligne = un article. Pas d'identifiant produit dans la source : clé = nom de l'article.
select distinct
    md5(lower(item_name))   as product_id,
    item_name,
    category
from {{ ref('int_orders_enriched') }}
