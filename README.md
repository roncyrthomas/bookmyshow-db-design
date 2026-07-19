# BookMyShow — Theatre Show Listing: Database Design

**Scenario:** For a given theatre, a user sees the next 7 dates. Choosing a date lists every show running in that theatre on that date along with its show timings (as in the BookMyShow theatre page for *PVR: Nexus*).

- **P1** — Entities, attributes, table structures (normalized to 1NF/2NF/3NF/BCNF), MySQL DDL + sample rows → [`sql/p1_schema_and_sample_data.sql`](sql/p1_schema_and_sample_data.sql)
- **P2** — Query listing all shows at a given theatre on a given date with timings → [`sql/p2_shows_by_theatre_and_date.sql`](sql/p2_shows_by_theatre_and_date.sql)

Both scripts run directly on MySQL 8.x:

```bash
mysql -u root -p < sql/p1_schema_and_sample_data.sql
mysql -u root -p < sql/p2_shows_by_theatre_and_date.sql
```

---

## 1. Entities & Relationships

| Entity | What it represents | Relationships |
|---|---|---|
| **Theatre** | A cinema venue (PVR: Nexus) | has many **Screens** |
| **Screen** | An auditorium inside a theatre, with its sound/projection system (4K ATMOS, Dolby 7.1) | belongs to one **Theatre**; hosts many **Shows** |
| **Movie** | A released movie variant as listed on the app — title + language + format (e.g. *Dasara (UA), Telugu, 2D*) | screened in many **Shows** |
| **Show** | One movie playing on one screen at a specific date & time | belongs to one **Screen** and one **Movie** |

```
Theatre 1 ──── * Screen 1 ──── * Show * ──── 1 Movie
```

The 7-day date strip in the UI needs no table: it is simply `WHERE show_date BETWEEN CURDATE() AND CURDATE() + INTERVAL 6 DAY`.

## 2. Table Structures

### `theatres`

| Column | Type | Constraint |
|---|---|---|
| theatre_id | INT UNSIGNED | PK, auto-increment |
| name | VARCHAR(100) | NOT NULL |
| city | VARCHAR(60) | NOT NULL |
| address | VARCHAR(255) | NOT NULL, UNIQUE with `name` |

Sample rows:

| theatre_id | name | city | address |
|---|---|---|---|
| 1 | PVR: Nexus (Forum Mall) | Bengaluru | Nexus Mall, Koramangala, Bengaluru 560095 |
| 2 | INOX: Garuda Mall | Bengaluru | Garuda Mall, Magrath Road, Bengaluru 560025 |

### `screens`

| Column | Type | Constraint |
|---|---|---|
| screen_id | INT UNSIGNED | PK, auto-increment |
| theatre_id | INT UNSIGNED | FK → theatres, NOT NULL |
| screen_name | VARCHAR(50) | NOT NULL, UNIQUE with `theatre_id` |
| sound_system | VARCHAR(50) | NOT NULL |
| total_seats | SMALLINT UNSIGNED | NOT NULL |

Sample rows:

| screen_id | theatre_id | screen_name | sound_system | total_seats |
|---|---|---|---|---|
| 1 | 1 | Audi 1 | Dolby 7.1 | 220 |
| 2 | 1 | Audi 2 | 4K ATMOS | 180 |
| 4 | 1 | Playhouse | Playhouse 4K | 120 |

### `movies`

| Column | Type | Constraint |
|---|---|---|
| movie_id | INT UNSIGNED | PK, auto-increment |
| title | VARCHAR(150) | NOT NULL |
| language | VARCHAR(30) | NOT NULL |
| format | ENUM('2D','3D','IMAX 2D','IMAX 3D') | NOT NULL |
| certification | ENUM('U','UA','A','S') | NOT NULL |
| duration_min | SMALLINT UNSIGNED | NOT NULL |

`(title, language, format)` is UNIQUE — each variant is one listing, exactly as the app shows *Avatar: The Way of Water (UA), English, 3D*.

Sample rows:

| movie_id | title | language | format | certification | duration_min |
|---|---|---|---|---|---|
| 1 | Dasara | Telugu | 2D | UA | 156 |
| 2 | Kisi Ka Bhai Kisi Ki Jaan | Hindi | 2D | UA | 145 |
| 4 | Avatar: The Way of Water | English | 3D | UA | 192 |

### `shows`

| Column | Type | Constraint |
|---|---|---|
| show_id | INT UNSIGNED | PK, auto-increment |
| screen_id | INT UNSIGNED | FK → screens, NOT NULL |
| movie_id | INT UNSIGNED | FK → movies, NOT NULL |
| show_date | DATE | NOT NULL |
| show_time | TIME | NOT NULL |
| base_price | DECIMAL(8,2) | NOT NULL, CHECK > 0 |

`(screen_id, show_date, show_time)` is UNIQUE — one screen cannot run two shows in the same slot.

Sample rows:

| show_id | screen_id | movie_id | show_date | show_time | base_price |
|---|---|---|---|---|---|
| 1 | 3 | 1 | 2023-04-25 | 12:15:00 | 350.00 |
| 2 | 2 | 2 | 2023-04-25 | 13:00:00 | 300.00 |
| 8 | 4 | 4 | 2023-04-25 | 13:20:00 | 450.00 |

## 3. Normalization (1NF → BCNF)

**1NF — atomic values, no repeating groups.** Every column holds a single scalar value. Show timings are *not* stored as a comma-separated list on the movie or theatre; each timing is its own row in `shows`.

**2NF — no partial dependencies.** Every table's primary key is a single surrogate column, so partial dependency on part of a composite PK is impossible. Checking the natural candidate keys too: in `shows`, the candidate key `(screen_id, show_date, show_time)` determines `movie_id` and `base_price` only as a *whole* — a screen alone or a date alone determines nothing.

**3NF — no transitive dependencies.** Non-key attributes depend only on the key:
- `shows` does **not** store `theatre_id` — that would be transitive (`show → screen → theatre`) and redundant. Theatre is reached by joining through `screens`.
- Theatre attributes (`name`, `city`) live only in `theatres`; screen attributes (`sound_system`) only in `screens`; movie attributes (`language`, `certification`) only in `movies`. Nothing like `screen_id → theatre_name` exists inside a single table.

**BCNF — every determinant is a candidate key.** In each table the only non-trivial functional dependencies are from the primary key or the declared unique keys, all of which are candidate keys:
- `theatres`: `theatre_id → *`, `(name, address) → *`
- `screens`: `screen_id → *`, `(theatre_id, screen_name) → *`
- `movies`: `movie_id → *`, `(title, language, format) → *`
- `shows`: `show_id → *`, `(screen_id, show_date, show_time) → *`

No dependency has a non-key determinant, so all tables satisfy BCNF.

## 4. P2 — Shows at a given theatre on a given date

```sql
SET @p_theatre_id = 1;            -- PVR: Nexus (Forum Mall)
SET @p_show_date  = '2023-04-25';

SELECT
    t.name                               AS theatre,
    m.title                              AS movie,
    m.certification                      AS certification,
    m.language                           AS language,
    m.format                             AS format,
    sc.screen_name                       AS screen,
    sc.sound_system                      AS sound_system,
    TIME_FORMAT(s.show_time, '%h:%i %p') AS show_time,
    s.base_price                         AS base_price
FROM shows    AS s
JOIN screens  AS sc ON sc.screen_id = s.screen_id
JOIN theatres AS t  ON t.theatre_id = sc.theatre_id
JOIN movies   AS m  ON m.movie_id   = s.movie_id
WHERE t.theatre_id = @p_theatre_id
  AND s.show_date  = @p_show_date
ORDER BY m.title, s.show_time;
```

Expected output for theatre 1 on 2023-04-25 (matches the screenshot):

| theatre | movie | certification | language | format | screen | sound_system | show_time | base_price |
|---|---|---|---|---|---|---|---|---|
| PVR: Nexus (Forum Mall) | Avatar: The Way of Water | UA | English | 3D | Playhouse | Playhouse 4K | 01:20 PM | 450.00 |
| PVR: Nexus (Forum Mall) | Dasara | UA | Telugu | 2D | Audi 3 | 4K Dolby 7.1 | 12:15 PM | 350.00 |
| PVR: Nexus (Forum Mall) | Kisi Ka Bhai Kisi Ki Jaan | UA | Hindi | 2D | Audi 2 | 4K ATMOS | 01:00 PM | 300.00 |
| PVR: Nexus (Forum Mall) | Kisi Ka Bhai Kisi Ki Jaan | UA | Hindi | 2D | Audi 2 | 4K ATMOS | 04:10 PM | 300.00 |
| PVR: Nexus (Forum Mall) | Kisi Ka Bhai Kisi Ki Jaan | UA | Hindi | 2D | Audi 3 | 4K Dolby 7.1 | 06:20 PM | 320.00 |
| PVR: Nexus (Forum Mall) | Kisi Ka Bhai Kisi Ki Jaan | UA | Hindi | 2D | Audi 2 | 4K ATMOS | 07:20 PM | 300.00 |
| PVR: Nexus (Forum Mall) | Kisi Ka Bhai Kisi Ki Jaan | UA | Hindi | 2D | Audi 2 | 4K ATMOS | 10:30 PM | 280.00 |
| PVR: Nexus (Forum Mall) | Tu Jhoothi Main Makkaar | UA | Hindi | 2D | Audi 1 | Dolby 7.1 | 01:15 PM | 250.00 |
