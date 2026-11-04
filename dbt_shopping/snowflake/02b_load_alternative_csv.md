# Alternative sans GCS : chargement manuel par CSV

Si la connexion GCS → Snowflake est trop longue à configurer :

1. Dans BigQuery, exporter la table en CSV :
   `bq query --use_legacy_sql=false --format=csv --max_rows=1000000 "select * from shopping_dev.orders" > orders.csv`
2. Dans Snowsight : **Data → Add Data → Load files into a stage / table**, choisir `RAW.SHOPPING.ORDERS`, déposer `orders.csv` (format CSV, en-tête sur 1 ligne).
3. Vérifier : `select count(*) from RAW.SHOPPING.ORDERS;`

En entretien, dire simplement : « j'ai chargé un export de la table BigQuery dans Snowflake ».
