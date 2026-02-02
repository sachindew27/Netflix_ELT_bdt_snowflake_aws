Netflix ELT (dbt + Snowflake)

This repo contains a dbt project for modeling the MovieLens dataset in Snowflake.

Project layout
- dbt project: `aws_dbt_netflix/`
- Python env (local only): `.venv/`

Quickstart
1) Create a dbt profile at `~/.dbt/profiles.yml` (not tracked in git).
2) Install deps and run dbt from the project directory.

Example profile (use env vars for secrets)
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

Run commands
```
cd aws_dbt_netflix
dbt deps
dbt seed
dbt run
dbt test
dbt snapshot
dbt docs generate
dbt docs serve
```

Notes
- If your Snowflake user enforces MFA, you must provide a current TOTP passcode
  in the profile for each run (see Snowflake MFA docs).
- Do not commit `profiles.yml` or any secrets.
