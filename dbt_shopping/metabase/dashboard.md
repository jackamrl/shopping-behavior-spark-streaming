# Dashboard Metabase « Comportement d'achat »

Connexion : Snowflake, rôle **REPORTER**, warehouse **REPORTING_WH**, base **ANALYTICS**, schéma **MARTS**.
Metabase ne lit que les marts : si un chiffre doit changer, on le corrige dans dbt, pas ici.

Lancer Metabase en local : `docker run -d -p 3000:3000 --name metabase metabase/metabase`, puis http://localhost:3000.

## Cartes (questions SQL natives sur les marts)

**1. KPI : revenu, achats, panier moyen**
```sql
select sum(net_amount_usd) as revenu, count(*) as achats, sum(net_amount_usd) / count(*) as panier_moyen
from MARTS.FCT_ORDERS;
```

**2. Revenu par catégorie (barres)**
```sql
select p.category, sum(f.net_amount_usd) as revenu
from MARTS.FCT_ORDERS f join MARTS.DIM_PRODUCTS p using (product_id)
group by 1 order by 2 desc;
```

**3. Panier moyen par segment client (barres)**
```sql
select c.customer_segment, avg(f.net_amount_usd) as panier_moyen, count(*) as achats
from MARTS.FCT_ORDERS f join MARTS.DIM_CUSTOMERS c using (customer_id)
group by 1 order by 2 desc;
```

**4. Effet des remises sur le panier**
```sql
select has_discount, avg(net_amount_usd) as panier_moyen, count(*) as achats
from MARTS.FCT_ORDERS group by 1;
```

**5. Note moyenne par saison et catégorie (tableau croisé)**
```sql
select f.season, p.category, round(avg(f.review_rating), 2) as note_moyenne
from MARTS.FCT_ORDERS f join MARTS.DIM_PRODUCTS p using (product_id)
group by 1, 2;
```

**6. Taux d'abonnés et clients récurrents par tranche d'âge**
```sql
select age_band,
       avg(case when is_subscriber then 1 else 0 end) as taux_abonnes,
       avg(case when is_returning_customer then 1 else 0 end) as taux_recurrents
from MARTS.DIM_CUSTOMERS group by 1 order by 1;
```

Les définitions sont les mêmes que dans `models/semantic/_metrics.yml`.
Avec dbt Cloud (Semantic Layer), Metabase ou un autre outil peuvent consommer directement les métriques MetricFlow au lieu de ce SQL.

Faire une capture du dashboard dans `docs/metabase_dashboard.png` pour le README.
