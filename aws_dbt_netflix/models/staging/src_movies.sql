WITH raw_movies AS (
    SELECT * FROM movielens.raw.raw_movies
)
SELECT 
    movieId AS movie_id,
    title,
    genres
FROM raw_movies