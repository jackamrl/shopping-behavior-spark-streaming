{#- Règle métier unique pour le segment client (reprise du job Spark). -#}
{% macro segment_from_previous_purchases(col) -%}
    case
        when {{ col }} >= 10 then 'VIP'
        when {{ col }} >= 5  then 'Regular'
        when {{ col }} >= 2  then 'Occasional'
        else 'New'
    end
{%- endmacro %}
