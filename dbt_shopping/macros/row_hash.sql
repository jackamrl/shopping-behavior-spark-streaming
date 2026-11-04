{#- Hash MD5 d'une ligne, identique au row_hash du job Spark (null -> chaîne vide). -#}
{% macro row_hash(columns) -%}
    md5(
        {%- for c in columns %}
        coalesce(cast({{ c }} as varchar), ''){% if not loop.last %} || '|' ||{% endif %}
        {%- endfor %}
    )
{%- endmacro %}
