-- ============================================================
-- P2: List all shows (with timings) at a given theatre on a
--     given date.
-- Directly executable on MySQL after running p1 script.
-- ============================================================
USE bookmyshow;

-- Parameters: change these two values as needed.
SET @p_theatre_id = 1;            -- PVR: Nexus (Forum Mall)
SET @p_show_date  = '2023-04-25'; -- selected date from the 7-day strip

SELECT
    t.name                                   AS theatre,
    s.show_date                              AS show_date,
    m.title                                  AS movie,
    m.certification                          AS certification,
    m.language                               AS language,
    m.format                                 AS format,
    sc.screen_name                           AS screen,
    sc.sound_system                          AS sound_system,
    TIME_FORMAT(s.show_time, '%h:%i %p')     AS show_time,
    s.base_price                             AS base_price
FROM shows    AS s
JOIN screens  AS sc ON sc.screen_id  = s.screen_id
JOIN theatres AS t  ON t.theatre_id  = sc.theatre_id
JOIN movies   AS m  ON m.movie_id    = s.movie_id
WHERE t.theatre_id = @p_theatre_id
  AND s.show_date  = @p_show_date
ORDER BY m.title, s.show_time;

-- Variant: look up the theatre by name instead of id
-- WHERE t.name = 'PVR: Nexus (Forum Mall)' AND s.show_date = '2023-04-25'
