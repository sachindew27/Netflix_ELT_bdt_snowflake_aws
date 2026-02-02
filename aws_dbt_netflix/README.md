aws_dbt_netflix

dbt project for modeling MovieLens data in Snowflake.

Directory layout
- models/staging: raw source models
- models/dim: dimension models
- models/fct: fact models
- models/mart: marts
- seeds: static CSVs
- snapshots: slowly changing data
- analyses: ad-hoc analysis queries

Setup
1) Create `~/.dbt/profiles.yml` with a target named `aws_dbt_netflix`.
2) Install dependencies:
   - `dbt-snowflake` (via pip or uv)
3) Run dbt commands from this directory.

Example profile (recommended: env var for password)
```
aws_dbt_netflix:
  outputs:
    dev:
      type: snowflake
      account: "<ACCOUNT>"
      user: "<USER>"
      password: "{{ env_var('SNOWFLAKE_PASSWORD') }}"
      role: "<ROLE>"
      database: "MOVIELENS"
      warehouse: "<WAREHOUSE>"
      schema: "dbt_schema"
      threads: 1
  target: dev
```

Common commands
```
dbt deps
dbt seed
dbt run
dbt test
dbt snapshot
dbt docs generate
dbt docs serve
```

MFA note
If your Snowflake account requires MFA, add a current TOTP passcode in your
profile for each run, or use an approved SSO/keypair setup.
