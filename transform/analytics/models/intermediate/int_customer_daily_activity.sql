{{
    config({
        "materialized": "table",
        "schema": "intermediate",
        "tags": ["intermediate", "nightly"]
    })
}}

SELECT
  customer_id,
  DATE(event_ts) AS activity_date,
  COUNTIF(event_type = 'login') AS login_count,
  COUNTIF(event_type = 'cancel_attempt') AS cancel_attempt_count,
  COUNTIF(event_type = 'payment_failed') AS payment_failed_count
FROM {{ ref('silver_events') }}
GROUP BY
  customer_id,
  DATE(event_ts)

