-- ============================================================
-- P1: BookMyShow - Theatre Show Listing Schema (MySQL 8.x)
-- Tables are normalized to 1NF, 2NF, 3NF and BCNF.
-- Directly executable: mysql -u <user> -p < p1_schema_and_sample_data.sql
-- ============================================================

CREATE DATABASE IF NOT EXISTS bookmyshow;
USE bookmyshow;

-- Drop in FK-safe order so the script is re-runnable
DROP TABLE IF EXISTS shows;
DROP TABLE IF EXISTS movies;
DROP TABLE IF EXISTS screens;
DROP TABLE IF EXISTS theatres;

-- ------------------------------------------------------------
-- 1. THEATRES: a cinema venue (e.g. "PVR: Nexus")
-- ------------------------------------------------------------
CREATE TABLE theatres (
    theatre_id   INT UNSIGNED     NOT NULL AUTO_INCREMENT,
    name         VARCHAR(100)     NOT NULL,
    city         VARCHAR(60)      NOT NULL,
    address      VARCHAR(255)     NOT NULL,
    PRIMARY KEY (theatre_id),
    UNIQUE KEY uk_theatre_name_address (name, address)
) ENGINE = InnoDB;

-- ------------------------------------------------------------
-- 2. SCREENS: an auditorium inside a theatre.
--    sound_system captures badges like "4K ATMOS", "Dolby 7.1".
-- ------------------------------------------------------------
CREATE TABLE screens (
    screen_id    INT UNSIGNED     NOT NULL AUTO_INCREMENT,
    theatre_id   INT UNSIGNED     NOT NULL,
    screen_name  VARCHAR(50)      NOT NULL,
    sound_system VARCHAR(50)      NOT NULL,
    total_seats  SMALLINT UNSIGNED NOT NULL,
    PRIMARY KEY (screen_id),
    UNIQUE KEY uk_screen_per_theatre (theatre_id, screen_name),
    CONSTRAINT fk_screens_theatre
        FOREIGN KEY (theatre_id) REFERENCES theatres (theatre_id)
) ENGINE = InnoDB;

-- ------------------------------------------------------------
-- 3. MOVIES: one row per released variant, matching how
--    BookMyShow lists "Dasara (UA) | Telugu, 2D" as one entry.
-- ------------------------------------------------------------
CREATE TABLE movies (
    movie_id      INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    title         VARCHAR(150)    NOT NULL,
    language      VARCHAR(30)     NOT NULL,
    format        ENUM('2D','3D','IMAX 2D','IMAX 3D') NOT NULL DEFAULT '2D',
    certification ENUM('U','UA','A','S') NOT NULL,
    duration_min  SMALLINT UNSIGNED NOT NULL,
    PRIMARY KEY (movie_id),
    UNIQUE KEY uk_movie_variant (title, language, format)
) ENGINE = InnoDB;

-- ------------------------------------------------------------
-- 4. SHOWS: a movie playing on a screen at a date + time.
--    A screen cannot host two shows at the same date/time.
-- ------------------------------------------------------------
CREATE TABLE shows (
    show_id     INT UNSIGNED      NOT NULL AUTO_INCREMENT,
    screen_id   INT UNSIGNED      NOT NULL,
    movie_id    INT UNSIGNED      NOT NULL,
    show_date   DATE              NOT NULL,
    show_time   TIME              NOT NULL,
    base_price  DECIMAL(8, 2)     NOT NULL,
    PRIMARY KEY (show_id),
    UNIQUE KEY uk_screen_slot (screen_id, show_date, show_time),
    CONSTRAINT fk_shows_screen
        FOREIGN KEY (screen_id) REFERENCES screens (screen_id),
    CONSTRAINT fk_shows_movie
        FOREIGN KEY (movie_id) REFERENCES movies (movie_id),
    CONSTRAINT chk_price_positive CHECK (base_price > 0)
) ENGINE = InnoDB;

-- ============================================================
-- Sample data (mirrors the reference screenshot: PVR Nexus, 25 Apr)
-- ============================================================

INSERT INTO theatres (name, city, address) VALUES
    ('PVR: Nexus (Forum Mall)', 'Bengaluru', 'Nexus Mall, Koramangala, Bengaluru 560095'),
    ('INOX: Garuda Mall',       'Bengaluru', 'Garuda Mall, Magrath Road, Bengaluru 560025');

INSERT INTO screens (theatre_id, screen_name, sound_system, total_seats) VALUES
    (1, 'Audi 1',    'Dolby 7.1',    220),
    (1, 'Audi 2',    '4K ATMOS',     180),
    (1, 'Audi 3',    '4K Dolby 7.1', 200),
    (1, 'Playhouse', 'Playhouse 4K', 120),
    (2, 'Screen 1',  'Dolby 7.1',    250);

INSERT INTO movies (title, language, format, certification, duration_min) VALUES
    ('Dasara',                   'Telugu',  '2D', 'UA', 156),
    ('Kisi Ka Bhai Kisi Ki Jaan','Hindi',   '2D', 'UA', 145),
    ('Tu Jhoothi Main Makkaar',  'Hindi',   '2D', 'UA', 159),
    ('Avatar: The Way of Water', 'English', '3D', 'UA', 192);

-- Shows at PVR: Nexus on 2023-04-25 (as in the screenshot)
INSERT INTO shows (screen_id, movie_id, show_date, show_time, base_price) VALUES
    (3, 1, '2023-04-25', '12:15:00', 350.00),  -- Dasara, 4K Dolby 7.1
    (2, 2, '2023-04-25', '13:00:00', 300.00),  -- KKBKKJ, 4K ATMOS
    (2, 2, '2023-04-25', '16:10:00', 300.00),
    (3, 2, '2023-04-25', '18:20:00', 320.00),
    (2, 2, '2023-04-25', '19:20:00', 300.00),
    (2, 2, '2023-04-25', '22:30:00', 280.00),
    (1, 3, '2023-04-25', '13:15:00', 250.00),  -- TJMM, Dolby 7.1
    (4, 4, '2023-04-25', '13:20:00', 450.00);  -- Avatar 3D, Playhouse 4K

-- Shows on the next day + another theatre (proves date/theatre filtering)
INSERT INTO shows (screen_id, movie_id, show_date, show_time, base_price) VALUES
    (1, 1, '2023-04-26', '12:15:00', 350.00),
    (2, 4, '2023-04-26', '19:00:00', 450.00),
    (5, 2, '2023-04-25', '14:00:00', 260.00);
