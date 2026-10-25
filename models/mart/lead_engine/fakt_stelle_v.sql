{{ config(materialized='view', tags=['fact']) }}
SELECT * FROM {{ ref('fakt_stelle') }}
