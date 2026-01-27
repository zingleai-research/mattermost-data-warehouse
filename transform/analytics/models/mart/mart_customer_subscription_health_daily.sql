{{ config(
    materialized = 'table',
    schema = 'gold'
) }}

WITH latest_subscription AS (

    SELECT
        customer_id,
        plan_name AS current_plan_name,
        status AS current_status,
        status_effective_ts,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY status_effective_ts DESC
        ) AS rn
    FROM {{ ref('silver_subscriptions') }}

),

subscription_per_customer AS (

    SELECT
        customer_id,
        current_plan_name,
        current_status
    FROM latest_subscription
    WHERE rn = 1

),

base AS (

    SELECT
        c.customer_id,
        c.segment,
        c.country,
        c.primary_device_type,
        c.signup_date,
        s.current_plan_name,
        s.current_status,
        a.snapshot_date,
        COALESCE(a.login_count_daily, 0)          AS login_count,
        COALESCE(a.cancel_attempt_count_daily, 0) AS cancel_attempt_count,
        COALESCE(a.payment_failed_count_daily, 0) AS payment_failed_count,
        c.acquisition_channel
    FROM {{ ref('silver_customers') }} c
    LEFT JOIN subscription_per_customer s
        ON c.customer_id = s.customer_id
    LEFT JOIN {{ ref('int_customer_daily_activity') }} a
        ON c.customer_id = a.customer_id
    WHERE
        c.is_employee = FALSE
        AND c.is_test_account = FALSE

),

rolling AS (

    SELECT
        customer_id,
        segment,
        country,
        primary_device_type,
        signup_date,
        current_plan_name,
        current_status,
        snapshot_date,

        SUM(login_count) OVER (
            PARTITION BY customer_id
            ORDER BY snapshot_date
            ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
        ) AS logins_last_30d,

        COUNTIF(login_count > 0) OVER (
            PARTITION BY customer_id
            ORDER BY snapshot_date
            ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
        ) AS active_days_last_30d,

        SUM(cancel_attempt_count) OVER (
            PARTITION BY customer_id
            ORDER BY snapshot_date
            ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
        ) AS cancel_attempts_last_30d,

        SUM(payment_failed_count) OVER (
            PARTITION BY customer_id
            ORDER BY snapshot_date
            ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
        ) AS payment_failures_last_30d,

        acquisition_channel

    FROM base

),

final AS (

    SELECT
        customer_id,
        segment,
        country,
        primary_device_type,
        current_plan_name,
        current_status,

        CASE
            WHEN current_status IN ('active', 'trialing', 'on_hold')
                THEN TRUE
            ELSE FALSE
        END AS is_active,

        snapshot_date,
        logins_last_30d,
        active_days_last_30d,
        cancel_attempts_last_30d,
        payment_failures_last_30d,
        acquisition_channel,

        DATE_DIFF(snapshot_date, signup_date, DAY) AS days_since_signup,

        GREATEST(
            0,
            LEAST(
                100,
                50
                + LEAST(logins_last_30d, 30)
                - 5 * cancel_attempts_last_30d
                - 3 * payment_failures_last_30d
            )
        ) AS health_score

    FROM rolling

)

SELECT
    *,
    CASE
        WHEN health_score >= 70 THEN 'healthy'
        WHEN health_score BETWEEN 40 AND 69 THEN 'watchlist'
        ELSE 'at_risk'
    END AS health_bucket
FROM final;
