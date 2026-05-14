-- Filename: 000001_music_jobs.up.sql
-- Author: Tysha Daniels
-- Date: 2026-05-14


-- Step 1 — id, payload, created_at

CREATE TABLE IF NOT EXISTS music_jobs (
    id         UUID        PRIMARY KEY DEFAULT uuidv7(),
    payload    JSONB       NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);


-- Questions & Answers

-- 1. Why UUID over SERIAL for the primary key?
-- ANSWER: UUID is used over SERIAL due to it being more scalable and secure.
--         For instance, if this were a project that required more than one database
--         to store the music jobs table, using SERIAL wouldn't be as ideal due to the fact that
--         it relies on a central authority (in this case, our database) to determine what the next
--         unique ID would be. And if there are multiple databases at play, it can easily lead to duplication of IDs.
--         While with UUID, even if we had multiple databases, the chance of duplication of IDs is extremely low,
--         due it being able to be generated anywhere without needing the database to do it, which makes it more
--         scalable.

--         In regards to security, SERIAL is predicatble. If an attacker knows how many
--         rows are in the table, they can easily guess what the next ID will be, and potentially
--         use it to perform malicious activities. UUID on the other hand is not predicatble, and
--         it is extremely unlikely that two people will generate the same UUID, making it more
--         secure and harder to exploit.

-- 2. Why uuidv7() specifically over uuidv4()?
-- ANSWER: uuidv7() is used specifically because it is time-ordered. Unlike uuidv4(), which is entirely random,
--         uuidv7() embeds a timestamp at the beginning of the ID. This is critical for B-tree performance because
--         it allows PostgreSQL to insert new records sequentially. This prevents index fragmentation and ensures that
--         write speeds remain fast even as the music_jobs table grows, whereas uuidv4() would cause random disk I/O and slow down insertions.

-- 3. Why JSONB over JSON?
-- ANSWER: While both allow for flexible data, JSONB stores data in a binary format rather than as a simple text string.
--         This makes JSONB slightly slower to insert but much faster to query and process since it doesn't require re-parsing.

-- 4. Why TIMESTAMPTZ over TIMESTAMP?
-- ANSWER: TIMESTAMPTZ is used because it stores the time in UTC and converts it to the client's local time upon retrieval.
--         This eliminates ambiguity related to time zones and ensures that everyone sees the same time regardless of their location.
--         TIMESTAMP does not store any timezone information. When inserting a timestamp without a timezone, PostgreSQL 
--         stores it exactly as provided. When retrieving it, it returns the same value without any conversion. 
--         This can lead to confusion if the database is accessed from different time zones.


-- Verification Queries

-- 1. Show all jobs ordered by creation time

-- SELECT * FROM music_jobs ORDER BY created_at ASC;

/*

-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
                  id                  |                                                                       payload                                                                        |          created_at           
--------------------------------------+------------------------------------------------------------------------------------------------------------------------------------------------------+-------------------------------
 019e24de-3f6a-73a7-adc8-217fb2fd7f40 | {"genre": "garifuna", "artist": "Andy Palacio", "status": "pending", "filename": "andy_palacio_watina_live_mix.wav", "duration_sec": 214}             | 2026-05-13 23:03:25.545958-06
 019e24de-3f6e-7563-9edc-40273054f4c8 | {"genre": "soca", "artist": "Supa G", "status": "pending", "filename": "supa_g_belize_riddim_final.mp3", "duration_sec": 187}                         | 2026-05-13 23:03:25.550255-06
 019e24de-3f70-7a10-a857-0a9289f52c9e | {"bpm": 96, "genre": "brukdown", "artist": "Mohobub Flores", "status": "pending", "filename": "mohobub_flores_brukdown_session.wav", "duration_sec": 302} | 2026-05-13 23:03:25.552577-06
(3 rows)

*/

-- 2. Extract filename and mime_type from each job

-- SELECT
--   payload->>'filename'  AS filename,
--   payload->>'mime_type' AS mime_type
-- FROM music_jobs;

/*

-------------------------------------------------
              filename               | mime_type 
-------------------------------------+-----------
 andy_palacio_watina_live_mix.wav    | 
 supa_g_belize_riddim_final.mp3      | 
 mohobub_flores_brukdown_session.wav | 
(3 rows)

*/

-- 3. Find only MP3 uploads

-- SELECT * FROM music_jobs
-- WHERE payload->>'filename' LIKE '%.mp3';

/*

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
                  id                  |                                            payload                                             |          created_at           
--------------------------------------+------------------------------------------------------------------------------------------------+--------------------------------------------------------------
 019e24de-3f6e-7563-9edc-40273054f4c8 | {"genre": "soca", "artist": "Supa G", "status": "pending", "filename": "supa_g_belize_riddim_final.mp3", "duration_sec": 187} | 2026-05-13 23:03:25.550255-06
(1 row)

*/

-- 4. Find the job that has the extra field

-- SELECT * FROM music_jobs
-- WHERE payload ? 'bpm';

/*
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
                  id                  |                                                                          payload                                                                          |          created_at           
--------------------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------------------+-------------------------------
 019e24de-3f70-7a10-a857-0a9289f52c9e | {"bpm": 96, "genre": "brukdown", "artist": "Mohobub Flores", "status": "pending", "filename": "mohobub_flores_brukdown_session.wav", "duration_sec": 302} | 2026-05-13 23:03:25.552577-06
(1 row)

*/