-- macros/cross_db/dates/date_diff.sql

{% macro date_diff(datepart, start_date, end_date) %}
    {{ return(adapter.dispatch('date_diff', 'my_project')(datepart, start_date, end_date)) }}
{% endmacro %}

{% macro default__date_diff(datepart, start_date, end_date) %}
    -- ANSI fallback
    ({{ end_date }} - {{ start_date }})
{% endmacro %}

{% macro snowflake__date_diff(datepart, start_date, end_date) %}
    datediff('{{ datepart }}', {{ start_date }}, {{ end_date }})
{% endmacro %}

{% macro bigquery__date_diff(datepart, start_date, end_date) %}
    date_diff({{ end_date }}, {{ start_date }}, {{ datepart }})
{% endmacro %}

{% macro databricks__date_diff(datepart, start_date, end_date) %}
    datediff({{ datepart }}, {{ start_date }}, {{ end_date }})
{% endmacro %}

{% macro trino__date_diff(datepart, start_date, end_date) %}
    date_diff('{{ datepart }}', {{ start_date }}, {{ end_date }})
{% endmacro %}

{% macro presto__date_diff(datepart, start_date, end_date) %}
    date_diff('{{ datepart }}', {{ start_date }}, {{ end_date }})
{% endmacro %}

{% macro starrocks__date_diff(datepart, start_date, end_date) %}
    datediff({{ end_date }}, {{ start_date }})
    {# StarRocks only supports day-level diff natively #}
{% endmacro %}

{% macro redshift__date_diff(datepart, start_date, end_date) %}
    datediff({{ datepart }}, {{ start_date }}, {{ end_date }})
{% endmacro %}
