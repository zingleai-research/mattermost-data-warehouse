{{
    config({
        "materialized": "table",
        "schema": "silver",
        "tags": ["silver", "nightly"]
    })
}}

SELECT
  customer_id,
  email,
  segment,
  country,
  primary_device_type,
  signup_date,
  is_employee,
  is_test_account
FROM {{ source('raw', 'raw_customers') }}

