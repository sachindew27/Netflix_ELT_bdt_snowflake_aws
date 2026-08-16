# MovieLens dbt + Snowflake

A dbt project that turns raw MovieLens tables in Snowflake into a small star schema: six
staging models, four dimensions, two facts, one mart, plus schema tests, a seed and an SCD
Type 2 snapshot.

This is a learning build. I worked through a public MovieLens walkthrough to get hands on with
dbt's core objects end to end (sources, staging, dims and facts, seeds, snapshots, tests,
packages, docs) against a real Snowflake account. There is no orchestration, no CI, and the raw
load into Snowflake was a manual step. The repo was originally named after the walkthrough
("Netflix"); the data is MovieLens, so the name now says so.

## Dataset

MovieLens (GroupLens Research): user ratings and free-text tags for movies, plus the "tag
genome", a matrix of relevance scores linking every movie to every tag.

Raw tables live in `MOVIELENS.RAW` and are declared in `models/sources/sources.yml`:

| table | contents |
|---|---|
| `RAW_MOVIES` | movie id, title, pipe-delimited genre string |
| `RAW_RATINGS` | user id, movie id, rating, unix timestamp |
| `RAW_TAGS` | user id, movie id, free-text tag, unix timestamp |
| `RAW_LINKS` | movie id to IMDb and TMDB ids |
| `RAW_GENOME_SCORES` | movie id, tag id, relevance score |
| `RAW_GENOME_TAGS` | tag id, tag label |

Loading the CSVs was a one-time step outside this repo, so the project starts where the raw
tables exist.

## Architecture

```
MOVIELENS.RAW.RAW_*                         declared in sources.yml
        |
  models/staging/                           -> schema STAGING
        |
        +---------------------------+----------------------------+
  models/dim/  -> DIM         models/fct/  -> FCT          snapshots/
  dim_movies                  fct_ratings (incremental)     snap_tags (SCD2)
  dim_users                   fct_genome_scores
  dim_genome_tags
  dim_movies_with_tags (ephemeral)
        |
  models/mart/  -> MART
  mart_movie_releases   (fct_ratings + seed_movie_release_dates)
```

Each folder maps to its own schema via `dbt_project.yml`, and
`macros/generate_schema_name.sql` overrides dbt's default naming.

## What's implemented

**Staging (6 models).** Column renames to snake_case and type fixes, including
`TO_TIMESTAMP_LTZ` on the raw unix columns. All six select through `{{ source('netflix', ...) }}`,
so the raw tables appear in the lineage graph and `dbt source freshness` has something to check.

**Dimensions (4).** `dim_movies` standardizes titles with `INITCAP(TRIM(...))` and splits the
pipe-delimited genre string into an array. `dim_users` is a distinct union of user ids from both
ratings and tags, since neither source alone is a complete user list. `dim_genome_tags` cleans
tag labels. `dim_movies_with_tags` is an ephemeral join.

**Facts (2).** `fct_ratings` is incremental with `on_schema_change='fail'` and pulls only
`rating_timestamp > (SELECT MAX(rating_timestamp) FROM {{ this }})` on incremental runs.
`fct_genome_scores` rounds relevance to 4 decimals and drops zero-relevance rows.

**Mart (1).** `mart_movie_releases` joins `fct_ratings` to the seed and flags each row known or
unknown for release-date coverage.

**Snapshot (1).** `snap_tags` tracks history on user tags: `strategy='timestamp'`, composite
`unique_key`, and `invalidate_hard_deletes=True` so deleted tags get closed out rather than left
open. It builds a `row_key` with `dbt_utils.generate_surrogate_key`.

**Tests.** `models/sources/schema.yml` documents every dim and fact column and declares
`not_null` across the keys and measures, plus a `relationships` test asserting every
`fct_ratings.movie_id` exists in `dim_movies`.

**Seed.** `seed_movie_release_dates.csv`, 10 rows, deliberately small: it exists to exercise
`dbt seed` and give the mart something to join against.

**Package.** `dbt_utils` 1.3.0, pinned in `package-lock.yml`.

## How to run

Requires a Snowflake account with a `MOVIELENS` database and a populated `RAW` schema.

```bash
uv sync
# create ~/.dbt/profiles.yml with a profile named aws_dbt_netflix
cd aws_dbt_netflix
uv run dbt deps
uv run dbt seed
uv run dbt run
uv run dbt test
uv run dbt snapshot
uv run dbt docs generate && uv run dbt docs serve
```

`profiles.yml` is never committed. If your Snowflake user has MFA enforced you will need a TOTP
passcode per run, or a keypair setup.

## What I'd do next

1. **Restore the `unique` tests.** `unique` on `dim_movies.movie_id`, `dim_users.user_id` and
   `dim_genome_tags.tag_id` are commented out. Either they pass and should be on, or they fail
   and there are real duplicates worth fixing upstream. Commented-out tests are worse than none.
2. **Use or delete `no_nulls_in_columns`.** The macro is a working generic test body but
   `tests/` is empty, so it is never invoked.
3. **Give `dim_movies_with_tags` a consumer.** It is ephemeral and nothing selects from it.
4. **Finish the rename.** The project directory is still `aws_dbt_netflix` and the source is
   still named `netflix`, neither of which matches the data.
5. **Extend the seed** past 10 rows, or replace the mart with something the genome data can
   actually support.
