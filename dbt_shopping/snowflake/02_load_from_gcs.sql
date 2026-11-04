-- =====================================================================
-- Chargement de la table BigQuery (exportée en Parquet dans GCS) vers RAW.SHOPPING.ORDERS
-- Prérequis : scripts/export_bigquery.sh a déposé les fichiers dans gs://<BUCKET>/exports/orders/
-- =====================================================================
use role accountadmin;

-- 1. Intégration de stockage GCS (Snowflake crée un compte de service GCP)
create storage integration if not exists GCS_SHOPPING_INT
  type = external_stage
  storage_provider = 'GCS'
  enabled = true
  storage_allowed_locations = ('gcs://<BUCKET>/exports/');

-- Récupérer le compte de service (STORAGE_GCP_SERVICE_ACCOUNT),
-- puis lui donner le rôle "Storage Object Viewer" sur le bucket dans la console GCP.
desc storage integration GCS_SHOPPING_INT;

grant usage on integration GCS_SHOPPING_INT to role LOADER;

-- 2. Stage externe + format de fichier
use role LOADER;
use warehouse LOADING_WH;
use schema RAW.SHOPPING;

create file format if not exists PARQUET_FMT type = parquet;

create stage if not exists GCS_ORDERS_STAGE
  url = 'gcs://<BUCKET>/exports/orders/'
  storage_integration = GCS_SHOPPING_INT
  file_format = PARQUET_FMT;

list @GCS_ORDERS_STAGE;

-- 3. Table brute (même schéma que la table BigQuery écrite par Spark)
create table if not exists ORDERS (
    customer_id            integer,
    age                    integer,
    gender                 varchar,
    item_purchased         varchar,
    category               varchar,
    purchase_amount_usd    double,
    location               varchar,
    size                   varchar,
    color                  varchar,
    season                 varchar,
    review_rating          double,
    subscription_status    varchar,
    shipping_type          varchar,
    discount_applied       varchar,
    promo_code_used        varchar,
    previous_purchases     integer,
    payment_method         varchar,
    frequency_of_purchases varchar,
    processed_time         timestamp_ntz
    -- les colonnes enrichies par Spark (final_amount_usd, customer_segment...) ne sont pas chargées :
    -- ces règles sont recalculées dans dbt pour être testées et documentées au même endroit.
);

-- 4. Chargement (rejouable : Snowflake ignore les fichiers déjà chargés)
copy into ORDERS
  from @GCS_ORDERS_STAGE
  match_by_column_name = case_insensitive;

select count(*) from ORDERS;
