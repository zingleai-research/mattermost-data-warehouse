{{
    config({
        "materialized": "table",
        "schema": "silver",
        "tags": ["silver", "nightly"]
    })
}}

SELECT
  subscription_id,
  customer_id,
  plan_name,
  status,
  status_effective_ts
FROM {{ source('raw', 'raw_subscriptions') }}

