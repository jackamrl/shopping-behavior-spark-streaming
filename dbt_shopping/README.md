# Shopping Behavior — couche analytics (dbt · Snowflake · MetricFlow · Metabase · agent Claude)

Ce dossier est la **deuxième partie** du projet `shopping-behavior-spark-streaming`.

```
Partie 1 — ingestion temps réel (dossier racine)
  Producer Scala → Cloud Storage → Spark Structured Streaming (Dataproc)
  → nettoyage, enrichissements, déduplication MD5, checkpoints → BigQuery
  Infra : Terraform · CI/CD : GitHub Actions

Partie 2 — analytics engineering (ce dossier)
  BigQuery → export Parquet → Snowflake RAW
  → dbt : staging → intermediate → marts (modèle en étoile), tests, docs
  → MetricFlow : métriques certifiées (revenu, panier moyen, rétention...)
  → Metabase : dashboard
  → Agent Claude via un serveur MCP qui n'interroge que les métriques certifiées
```

## Pourquoi cette deuxième partie

Dans la partie 1, les règles métier (montant après remise, segment client, satisfaction…) étaient codées dans le job Spark.
C'était difficile à tester, à documenter et à faire évoluer par quelqu'un d'autre qu'un développeur Scala.

Ici, **Spark ne garde que l'ingestion et la qualité technique**. Les règles métier vivent dans **dbt** : en SQL, versionnées, testées, documentées.
Les indicateurs sont définis **une seule fois** dans **MetricFlow**, et le dashboard comme l'agent IA s'appuient dessus.

## Modèles

| Couche | Modèle | Grain (1 ligne =) | Rôle |
|---|---|---|---|
| staging | `stg_orders` | un achat brut | typage, `snake_case`, booléens au lieu de Yes/No |
| intermediate | `int_orders_deduplicated` | un achat unique | même hash MD5 que Spark, garde la version la plus récente |
| intermediate | `int_orders_enriched` | un achat | montant net après remise, taille de panier, satisfaction, saison |
| marts | `fct_orders` | un achat | table de faits |
| marts | `dim_customers` | un client | âge, segment, abonnement, fidélité |
| marts | `dim_products` | un article | catégorie |
| semantic | `metricflow_time_spine` | un jour | calendrier pour MetricFlow |

Macros : `row_hash` (hash identique à Spark), `segment_from_previous_purchases` (règle VIP/Regular/Occasional/New définie une seule fois), `generate_schema_name` (schémas séparés dev / prod).

## Tests (39 au total)

- `unique` / `not_null` sur les clés de chaque modèle
- `relationships` : chaque achat pointe vers un client et un article existants
- `accepted_values` : saison, taille de panier, segment, satisfaction, fidélité
- test générique maison `value_between` : note entre 1 et 5, montants entre 0 et 10 000
- `assert_no_order_lost_or_duplicated` : autant d'achats en marts qu'en intermediate (détecte une jointure qui multiplie les lignes)
- `assert_net_amount_not_above_gross` : une remise ne peut pas augmenter le montant
- fraîcheur de la source (`dbt source freshness`)

## Métriques (MetricFlow)

| Métrique | Type | Définition |
|---|---|---|
| `revenue` | simple | somme des montants après remise |
| `orders` | simple | nombre d'achats |
| `average_basket` | ratio | revenue / orders |
| `discount_rate` | ratio | remises / revenu brut |
| `active_buyers` | simple | clients distincts ayant acheté |
| `average_rating` | simple | note moyenne |
| `retention_rate` | ratio | clients ayant déjà acheté / clients (approximation, voir limites) |
| `subscriber_rate` | ratio | abonnés / clients |

Exemples :
```bash
mf query --metrics revenue,average_basket --group-by customer__customer_segment
mf query --metrics average_basket --group-by order__has_discount
mf query --metrics retention_rate,subscriber_rate --group-by customer__age_band
```

## Agent IA

`agent/metrics_mcp_server.py` est un serveur MCP qui donne à Claude trois outils : `list_metrics`, `list_dimensions`, `query_metrics`.

Garde-fous :
- liste blanche des métriques, aucun SQL libre ;
- résultats limités ;
- chaque réponse cite les métriques utilisées.

`agent/SKILL.md` donne les règles de comportement, dont **dire quand la donnée ne permet pas de répondre**.
`agent/eval_questions.csv` contient 15 questions-tests, dont 3 où l'agent doit refuser.

## Lancer le projet

1. **Snowflake** (essai gratuit 30 jours) : exécuter `snowflake/01_setup.sql`.
2. **Charger la donnée** : `scripts/export_bigquery.sh <bucket>` puis `snowflake/02_load_from_gcs.sql`. Autre option : `snowflake/02b_load_alternative_csv.md`.
3. **dbt** :
   ```bash
   python -m venv .venv && source .venv/bin/activate
   pip install "dbt-metricflow[dbt-snowflake]" "mcp>=1.2,<2" pyyaml
   cp profiles.example.yml ~/.dbt/profiles.yml   # puis remplir
   export SNOWFLAKE_PASSWORD=...
   dbt debug
   dbt build                 # modèles + 39 tests
   dbt docs generate && dbt docs serve   # documentation + lignage
   mf validate-configs
   ```
4. **Metabase** : voir `metabase/dashboard.md`.
5. **Agent** : adapter `agent/claude_desktop_config.example.json` dans la configuration de Claude Desktop, redémarrer Claude, puis poser les questions de `agent/eval_questions.csv`.
6. **CI** : copier `.github/workflows/dbt_ci.yml` à la racine du dépôt et ajouter les secrets `SNOWFLAKE_ACCOUNT`, `SNOWFLAKE_USER`, `SNOWFLAKE_PASSWORD`.

## Limites connues (assumées)

- **Pas de date d'achat dans la source** : `purchased_at` est l'heure de traitement par Spark. Pas d'analyse de tendance temporelle fiable.
- **Pas d'historique par client** (un achat par client dans le jeu de données) : `retention_rate` est une approximation fondée sur `previous_purchases`. Avec un historique, je la calculerais par cohorte mensuelle.
- **CLV** : la formule du job Spark (`previous_purchases × montant × 0,3`) est volontairement laissée hors des marts. Une vraie CLV demande la fréquence et la durée de vie réelles.
- **Pas de modèle incrémental** : vu le volume (quelques milliers de lignes), les marts sont en `table`. Avec une table qui grossit chaque jour, `fct_orders` passerait en `incremental` avec `unique_key = 'order_id'`.

## Captures à ajouter

- `docs/lineage.png` : graphe de lignage dbt Docs
- `docs/metabase_dashboard.png`
- `docs/agent_conversation.png` : une question / réponse de l'agent citant la métrique
