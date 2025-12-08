{{
    config({
        "materialized": "table",
        "schema": "silver",
        "tags": ["silver", "nightly"]
    })
}}

SELECT
  event_id,
  customer_id,
  event_type,
  event_ts,
  device_type,
  metadata
FROM {{ source('raw', 'raw_events') }}

