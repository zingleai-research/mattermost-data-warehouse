with user_metrics as (
    select activity_date,
    server_id AS server_id,
    {{ dbt_utils.pivot(
      'user_role',
      dbt_utils.get_column_values(ref('int_user_nps_score_spined'), 'user_role'),
      agg='sum',
      then_value='promoters',
      quote_identifiers=False,
      prefix='count_',
      suffix='_promoters_daily'
  ) }},
    {{ dbt_utils.pivot(
      'user_role',
      dbt_utils.get_column_values(ref('int_user_nps_score_spined'), 'user_role'),
      agg='sum',
      then_value='detractors',
      quote_identifiers=False,
      prefix='count_',
      suffix='_detractors_daily'
  ) }},
    {{ dbt_utils.pivot(
      'user_role',
      dbt_utils.get_column_values(ref('int_user_nps_score_spined'), 'user_role'),
      agg='sum',
      then_value='passives',
      quote_identifiers=False,
      prefix='count_',
      suffix='_passives_daily'
  ) }},
    {{ dbt_utils.pivot(
      'user_role',
      dbt_utils.get_column_values(ref('int_user_nps_score_spined'), 'user_role'),
      agg='sum',
      then_value='nps_users',
      quote_identifiers=False,
      prefix='count_',
      suffix='_nps_users_daily'
  ) }},
    {{ dbt_utils.pivot(
      'user_role',
      dbt_utils.get_column_values(ref('int_user_nps_score_spined'), 'user_role'),
      agg='sum',
      then_value='promoters_last90d',
      quote_identifiers=False,
      prefix='count_',
      suffix='_promoters_last90d'
  ) }},
    {{ dbt_utils.pivot(
      'user_role',
      dbt_utils.get_column_values(ref('int_user_nps_score_spined'), 'user_role'),
      agg='sum',
      then_value='detractors_last90d',
      quote_identifiers=False,
      prefix='count_',
      suffix='_detractors_last90d'
  ) }},
    {{ dbt_utils.pivot(
      'user_role',
      dbt_utils.get_column_values(ref('int_user_nps_score_spined'), 'user_role'),
      agg='sum',
      then_value='passives_last90d',
      quote_identifiers=False,
      prefix='count_',
      suffix='_passives_last90d'
  ) }},
    {{ dbt_utils.pivot(
      'user_role',
      dbt_utils.get_column_values(ref('int_user_nps_score_spined'), 'user_role'),
      agg='sum',
      then_value='nps_users_last90d',
      quote_identifiers=False,
      prefix='count_',
      suffix='_nps_users_last90d'
  ) }}
    FROM
    {{ ref('int_user_nps_score_spined') }}
    group by activity_date
    , server_id
)
SELECT a.*,
    {{ dbt_utils.generate_surrogate_key(['a.server_id', 'a.activity_date']) }} as daily_server_id,
    {{ dbt_utils.generate_surrogate_key(['b.server_version_full']) }} AS version_id,
    a.count_user_promoters_daily + a.count_team_admin_promoters_daily + a.count_system_admin_promoters_daily AS count_promoters_daily,
    a.count_user_detractors_daily + a.count_team_admin_detractors_daily + a.count_system_admin_detractors_daily AS count_detractors_daily,
    a.count_user_passives_daily + a.count_team_admin_passives_daily + a.count_system_admin_passives_daily AS count_passives_daily,
    a.count_user_nps_users_daily + a.count_team_admin_nps_users_daily + a.count_system_admin_nps_users_daily AS count_nps_users_daily,
    a.count_user_promoters_last90d + a.count_team_admin_promoters_last90d + a.count_system_admin_promoters_last90d AS count_promoters_last90d,
    a.count_user_detractors_last90d + a.count_team_admin_detractors_last90d + a.count_system_admin_detractors_last90d AS count_detractors_last90d,
    a.count_user_passives_last90d + a.count_team_admin_passives_last90d + a.count_system_admin_passives_last90d AS count_passives_last90d,
    a.count_user_nps_users_last90d + a.count_team_admin_nps_users_last90d + a.count_system_admin_nps_users_last90d AS count_nps_users_last90d,
    -- New: NPS Score Calculation
    -- Formula: ((Promoters - Detractors) / Total Respondents) × 100
    CASE 
        WHEN (a.count_user_nps_users_daily + a.count_team_admin_nps_users_daily + a.count_system_admin_nps_users_daily) > 0 
        THEN ROUND(
            ((a.count_user_promoters_daily + a.count_team_admin_promoters_daily + a.count_system_admin_promoters_daily - 
              a.count_user_detractors_daily - a.count_team_admin_detractors_daily - a.count_system_admin_detractors_daily)::float / 
             (a.count_user_nps_users_daily + a.count_team_admin_nps_users_daily + a.count_system_admin_nps_users_daily)::float) * 100, 
            2
        )
        ELSE NULL
    END AS nps_score_daily,
    CASE 
        WHEN (a.count_user_nps_users_last90d + a.count_team_admin_nps_users_last90d + a.count_system_admin_nps_users_last90d) > 0 
        THEN ROUND(
            ((a.count_user_promoters_last90d + a.count_team_admin_promoters_last90d + a.count_system_admin_promoters_last90d - 
              a.count_user_detractors_last90d - a.count_team_admin_detractors_last90d - a.count_system_admin_detractors_last90d)::float / 
             (a.count_user_nps_users_last90d + a.count_team_admin_nps_users_last90d + a.count_system_admin_nps_users_last90d)::float) * 100, 
            2
        )
        ELSE NULL
    END AS nps_score_last90d,
    -- New: End User (user_role = 'user') NPS Score
    CASE 
        WHEN a.count_user_nps_users_daily > 0 
        THEN ROUND(
            ((a.count_user_promoters_daily - a.count_user_detractors_daily)::float / a.count_user_nps_users_daily::float) * 100, 
            2
        )
        ELSE NULL
    END AS end_user_nps_score_daily,
    CASE 
        WHEN a.count_user_nps_users_last90d > 0 
        THEN ROUND(
            ((a.count_user_promoters_last90d - a.count_user_detractors_last90d)::float / a.count_user_nps_users_last90d::float) * 100, 
            2
        )
        ELSE NULL
    END AS end_user_nps_score_last90d,
    -- New: MME Customer Flag (for company scorecard)
    CASE 
        WHEN customer.customer_tier IN ('MME', 'Enterprise', 'Strategic') OR customer.sku IN ('professional', 'enterprise', 'e20', 'e30')
        THEN true 
        ELSE false 
    END AS is_mme_customer,
    customer.customer_tier,
    customer.company_name as customer_company_name
    from user_metrics a join
    {{ ref('int_nps_server_version_spined') }} b 
    on a.server_id = b.server_id and a.activity_date = b.activity_date
    -- New: Join with customer info for MME filtering
    LEFT JOIN {{ ref('dim_latest_server_customer_info') }} customer
        on a.server_id = customer.server_id
