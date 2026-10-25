{{ config(materialized='view', tags=['dimension']) }}
SELECT * FROM {{ ref('dim_stelle') }}
