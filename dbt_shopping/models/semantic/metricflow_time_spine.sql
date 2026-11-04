-- Calendrier journalier requis par MetricFlow (une ligne = un jour).
{{ config(materialized='table') }}

with days as (
    {{ dbt.date_spine('day', "cast('2024-01-01' as date)", "cast('2030-12-31' as date)") }}
)
select cast(date_day as date) as date_day
from days
