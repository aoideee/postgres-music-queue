-- Filename: 000001_music_jobs.up.sql
-- Author: Tysha Daniels
-- Date: 2026-05-14


-- Step 1 — id, payload, created_at

CREATE TABLE IF NOT EXISTS music_jobs (
    id         UUID        PRIMARY KEY DEFAULT uuidv7(),
    payload    JSONB       NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================

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

-- ============================================================================

-- Sample Data

-- INSERT INTO music_jobs (payload) VALUES (
--   '{
--     "filename": "andy_palacio_watina_live_mix.wav",
--     "artist": "Andy Palacio",
--     "genre": "garifuna",
--     "duration_sec": 214,
--     "status": "pending"
--   }'::jsonb
-- );

-- INSERT INTO music_jobs (payload) VALUES (
--   '{
--     "filename": "supa_g_belize_riddim_final.mp3",
--     "artist": "Supa G",
--     "genre": "soca",
--     "duration_sec": 187,
--     "status": "pending"
--   }'::jsonb
-- );

-- INSERT INTO music_jobs (payload) VALUES (
--   '{
--     "filename": "mohobub_flores_brukdown_session.wav",
--     "artist": "Mohobub Flores",
--     "genre": "brukdown",
--     "duration_sec": 302,
--     "status": "pending",
--     "bpm": 96
--   }'::jsonb
-- );

-- ============================================================================

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

*/

-- ============================================================================

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

*/

-- ============================================================================

-- 3. Find only MP3 uploads

-- SELECT * FROM music_jobs
-- WHERE payload->>'filename' LIKE '%.mp3';

/*

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
                  id                  |                                            payload                                             |          created_at           
--------------------------------------+------------------------------------------------------------------------------------------------+--------------------------------------------------------------
 019e24de-3f6e-7563-9edc-40273054f4c8 | {"genre": "soca", "artist": "Supa G", "status": "pending", "filename": "supa_g_belize_riddim_final.mp3", "duration_sec": 187} | 2026-05-13 23:03:25.550255-06

*/

-- ============================================================================

-- 4. Find the job that has the extra field

-- SELECT * FROM music_jobs
-- WHERE payload ? 'bpm';

/*

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
                  id                  |                                                                          payload                                                                          |          created_at           
--------------------------------------+-----------------------------------------------------------------------------------------------------------------------------------------------------------+-------------------------------
 019e24de-3f70-7a10-a857-0a9289f52c9e | {"bpm": 96, "genre": "brukdown", "artist": "Mohobub Flores", "status": "pending", "filename": "mohobub_flores_brukdown_session.wav", "duration_sec": 302} | 2026-05-13 23:03:25.552577-06

*/


-- ============================================================================


-- Step 2 — public_id

ALTER TABLE music_jobs
ADD COLUMN public_id UUID NOT NULL UNIQUE DEFAULT uuidv4();

-- ============================================================================

-- Questions and Answers

-- 1. Why does this column use uuidv4() and not uuidv7()?
-- ANSWER: uuidv4() is used because it is a random identifier that is not time-ordered.
--         This ensures that the public_id is unique and cannot be predicted. This is useful 
--         for security reasons, as it prevents attackers from guessing the public_id and 
--         accessing the job.

-- 2. What does uuid_extract_timestamp() reveal about uuidv7?
-- ANSWER: It reveals the exact date and millisecond that the ID was generated. It proves that
--         that uuidv7 are not randomly generated and that they can be used to determine when the job
--         was created.

-- 3. Why does the UNIQUE constraint make CREATE INDEX unnecessary?
-- ANSWER: The UNIQUE constraint creates an index automatically, so CREATE INDEX is not needed.

-- 4. What is the two-ID pattern and why does it matter?
-- ANSWER: The two-ID pattern is when you have two primary keys for a table, one is the 
--         internal ID and the other is the public ID. It matters because it allows for 
--         easy querying and retrieval of data without exposing the internal ID.

-- ============================================================================

-- Verification Queries

-- 1. Show id vs public_id side by side

-- SELECT id, public_id FROM music_jobs;

/*

-----------------------------------------------------------------------------
                  id                  |              public_id               
--------------------------------------+--------------------------------------
 019e2556-4207-7e37-9116-399ed78e6666 | 498eb6a6-6de1-4afd-af81-3b3b671d25a5
 019e2556-420c-70e8-a3be-7cc6aebbace1 | f4d4835c-c560-40a9-a6eb-3678aacb4e35
 019e2556-420e-74e7-ac2a-ef8b7e1d60d3 | 613aa1b4-6248-4079-8ac6-ca9882e91ad0


*/

-- ============================================================================

-- 2. Run uuid_extract_timestamp() on both columns

-- SELECT
--   uuid_extract_timestamp(id)        AS id_timestamp,
--   uuid_extract_timestamp(public_id) AS public_id_timestamp
-- FROM music_jobs;

/*

--------------------------------------------------
        id_timestamp        | public_id_timestamp 
----------------------------+---------------------
 2026-05-14 01:14:30.535-06 | 
 2026-05-14 01:14:30.54-06  | 
 2026-05-14 01:14:30.542-06 | 

*/

-- ============================================================================

-- 3. What the Go server would return to the client after insert

-- SELECT public_id, payload->>'status' AS status
-- FROM music_jobs;


/*

------------------------------------------------
              public_id               | status  
--------------------------------------+---------
 498eb6a6-6de1-4afd-af81-3b3b671d25a5 | pending
 f4d4835c-c560-40a9-a6eb-3678aacb4e35 | pending
 613aa1b4-6248-4079-8ac6-ca9882e91ad0 | pending

*/

-- ============================================================================

-- 4. What the Go server would do when the client polls

-- SELECT payload->>'status' AS status
-- FROM music_jobs
-- WHERE public_id = '498eb6a6-6de1-4afd-af81-3b3b671d25a5';

/*

 status  
---------
 pending

*/


-- ============================================================================


--Step 3 — status, progress

ALTER TABLE music_jobs
ADD COLUMN status   TEXT    NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'processing', 'done', 'failed')),
ADD COLUMN progress INTEGER NOT NULL DEFAULT 0
    CHECK (progress BETWEEN 0 AND 100);

-- ============================================================================

-- Questions and Answers

-- 1. Why are status and progress real columns, not inside payload JSONB?
-- ANSWER: They are real columns because they are frequently queried by the Go server to
--         determine the status of the job, and adding indexes to real columns is more
--         efficient than querying JSONB.

-- 2. What happens if a buggy worker writes status = 'complet'?
-- ANSWER: It would be rejected with an error message stating that the value violates the
--         CHECK constraint.

-- 3. Why does the CHECK constraint matter more than application validation?
-- ANSWER: It ensures data integrity at the database level, preventing invalid data from 
--         being inserted into the table, even if the application code is buggy.

-- 4. Draw the state machine for a job lifecycle
-- ANSWER: 

/*

  pending
    ↓
  processing
    ↓
  done

*/

-- ============================================================================

-- Sample Data

-- -- Claim the oldest pending job (UPDATE with subquery)
-- UPDATE music_jobs
-- SET status = 'processing'
-- WHERE id = (
--   SELECT id FROM music_jobs
--   WHERE status = 'pending'
--   ORDER BY created_at ASC
--   LIMIT 1
-- );

-- -- Advance progress to 25%
-- UPDATE music_jobs
-- SET progress = 25
-- WHERE status = 'processing';

-- -- Advance progress to 50%
-- UPDATE music_jobs
-- SET progress = 50
-- WHERE status = 'processing';

-- -- Complete the job
-- UPDATE music_jobs
-- SET status = 'done', progress = 100
-- WHERE status = 'processing';

-- -- Invalid status (copy its error message)
-- UPDATE music_jobs
-- SET status = 'complet'
-- WHERE id = (SELECT id FROM music_jobs ORDER BY created_at LIMIT 1);

-- -- Invalid progress (copy its error message)
-- UPDATE music_jobs
-- SET progress = 150
-- WHERE id = (SELECT id FROM music_jobs ORDER BY created_at LIMIT 1);

-- Sample Data Error Messages:
-- ERROR:  new row for relation "music_jobs" violates check constraint "music_jobs_status_check"
-- DETAIL:  Failing row contains (019e2590-6b9f-7a98-88ef-582c58c9f516, {"genre": "garifuna", "artist": "Andy Palacio", "status": "pendi..., 2026-05-14 02:18:02.271318-06, e90e5867-0df2-4a21-8e8d-9075bbbebe20, complet, 100).
-- ERROR:  new row for relation "music_jobs" violates check constraint "music_jobs_progress_check"
-- DETAIL:  Failing row contains (019e2590-6b9f-7a98-88ef-582c58c9f516, {"genre": "garifuna", "artist": "Andy Palacio", "status": "pendi..., 2026-05-14 02:18:02.271318-06, e90e5867-0df2-4a21-8e8d-9075bbbebe20, done, 150).

-- ============================================================================

-- Verification Queries

-- 1. What does the client see when polling a processing job?

-- SELECT public_id, status, progress
-- FROM music_jobs
-- WHERE public_id = 'e90e5867-0df2-4a21-8e8d-9075bbbebe20';

/*

----------------------------------------------------------
              public_id               | status | progress 
--------------------------------------+--------+----------
 e90e5867-0df2-4a21-8e8d-9075bbbebe20 | done   |      100

*/

-- ============================================================================

-- 2. What query does the worker run to find its next job?

-- SELECT id, payload
-- FROM music_jobs
-- WHERE status = 'pending'
-- ORDER BY created_at ASC
-- LIMIT 1;

/*

----------------------------------------------------------------------------------------------------------------------------------------------------------------------
                  id                  |                                                            payload                                                            
--------------------------------------+-------------------------------------------------------------------------------------------------------------------------------
 019e2590-6bac-7dcd-93d4-c40dd2028f56 | {"genre": "soca", "artist": "Supa G", "status": "pending", "filename": "supa_g_belize_riddim_final.mp3", "duration_sec": 187}

*/

-- ============================================================================

-- 3. Show all jobs with their current state

-- SELECT id, status, progress FROM music_jobs;

/*
----------------------------------------------------------
                  id                  | status  | progress 
--------------------------------------+---------+----------
 019e2590-6bac-7dcd-93d4-c40dd2028f56 | pending |        0
 019e2590-6baf-7096-ab4f-5fbbc773b73f | pending |        0
 019e2590-6b9f-7a98-88ef-582c58c9f516 | done    |      100

*/


-- ============================================================================

-- Step 4 — result, error_msg

ALTER TABLE music_jobs
ADD COLUMN result    JSONB NOT NULL DEFAULT '{}',
ADD COLUMN error_msg TEXT;

-- ============================================================================

-- Questions and Answers

--  1. Why does the result default to '{}' and not NULL?
-- ANSWER: It defaults to an empty JSON object so that the application code doesn't
--         have to handle NULL values when parsing the result.

-- 2. Why is error_msg TEXT and not inside the result JSONB?
-- ANSWER: To ensure data integrity at the database level, preventing invalid data from
--         being inserted into the table, even if the application code is buggy.

-- 3. What does the || operator do to a JSONB object?
-- ANSWER: It merges two JSONB objects, with the right-hand side overriding the left-hand side in case of duplicate keys.

-- 4. Why does each stage read from the original file, not the previous stage's output?
-- ANSWER: It avoids storing intermediate files, reducing disk usage and potential
--          corruption if a job is retried.

-- ============================================================================

-- Sample Data

-- -- First, claim a pending job to work on
-- UPDATE music_jobs
-- SET status = 'processing'
-- WHERE id = (
--   SELECT id FROM music_jobs
--   WHERE status = 'pending'
--   ORDER BY created_at ASC
--   LIMIT 1
-- );

-- -- Stage 1 — normalize complete (25%)
-- UPDATE music_jobs
-- SET progress = 25,
--     result = result || '{"normalize": "complete", "lufs": -14.2}'::jsonb
-- WHERE status = 'processing';

-- SELECT id, status, progress, result FROM music_jobs WHERE status = 'processing';

-- -- Stage 2 — trim silence complete (50%)
-- UPDATE music_jobs
-- SET progress = 50,
--     result = result || '{"trim_silence": "complete", "trimmed_ms": 320}'::jsonb
-- WHERE status = 'processing';

-- SELECT id, status, progress, result FROM music_jobs WHERE status = 'processing';

-- -- Stage 3 — convert complete (75%)
-- UPDATE music_jobs
-- SET progress = 75,
--     result = result || '{"convert": "complete", "output_format": "mp3", "bitrate_kbps": 320}'::jsonb
-- WHERE status = 'processing';

-- SELECT id, status, progress, result FROM music_jobs WHERE status = 'processing';

-- -- Stage 4 — waveform complete, job done (100%)
-- UPDATE music_jobs
-- SET status = 'done',
--     progress = 100,
--     result = result || '{"waveform": "complete", "peaks": [0.2, 0.8, 0.5, 0.9, 0.3], "output_url": "s3://music-queue/processed.mp3"}'::jsonb
-- WHERE status = 'processing';

-- SELECT id, status, progress, result FROM music_jobs WHERE status = 'done' ORDER BY created_at DESC LIMIT 1;

-- -- Simulate failure on a different job
-- UPDATE music_jobs
-- SET status = 'failed',
--     error_msg = 'codec not found: unable to decode wav header, file may be corrupt'
-- WHERE id = (
--   SELECT id FROM music_jobs
--   WHERE status = 'pending'
--   ORDER BY created_at ASC
--   LIMIT 1
-- );

-- SELECT id, status, error_msg FROM music_jobs WHERE status = 'failed';

-- ============================================================================

-- Sample Data Results:

-- Stage 1 — normalize complete (25%)

/*

---------------------------------------------------------------------------------------------------------
                  id                  |   status   | progress |                  result                  
--------------------------------------+------------+----------+------------------------------------------
 019e2982-afe0-719f-afd6-9d0ca0700f5f | processing |       25 | {"lufs": -14.2, "normalize": "complete"}

*/


-- Stage 2 — trim silence complete (50%)

/*

--------------------------------------------------------------------------------------------------------------------------------------------------------
                  id                  |   status   | progress |                                         result                                          
--------------------------------------+------------+----------+-----------------------------------------------------------------------------------------
 019e2982-afe0-719f-afd6-9d0ca0700f5f | processing |       50 | {"lufs": -14.2, "normalize": "complete", "trimmed_ms": 320, "trim_silence": "complete"}

*/


-- Stage 3 — convert complete (75%)

/*

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
                  id                  |   status   | progress |                                                    result                                                     
--------------------------------------+------------+----------+---------------------------------------------------------------------------------------------------------------
 019e2982-afe0-719f-afd6-9d0ca0700f5f | processing |       75 | {"lufs": -14.2, "convert": "complete", "normalize": "complete", "trimmed_ms": 320, "bitrate_kbps": 320, ...}

*/


-- Stage 4 — waveform complete, job done (100%)

/*

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
                  id                  | status | progress |                                                                                               result                                                                                               
--------------------------------------+--------+----------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 019e2982-afe0-719f-afd6-9d0ca0700f5f | done   |      100 | {"lufs": -14.2, "peaks": [0.2, 0.8, 0.5, 0.9, 0.3], "convert": "complete", "waveform": "complete", "normalize": "complete", "output_url": "s3://music-queue/processed.mp3", "trimmed_ms": 320, ...}

*/


-- Simulate failure on a different job

/*

-------------------------------------------------------------------------------------------------------------------
                  id                  | status |                             error_msg                             
--------------------------------------+--------+-------------------------------------------------------------------
 019e2982-afe2-7746-a23d-c4e006c05f39 | failed | codec not found: unable to decode wav header, file may be corrupt

*/

-- ============================================================================

-- Verification Queries

--  1. What does the client see when polling a completed job?

-- SELECT public_id, status, progress, result
-- FROM music_jobs
-- WHERE status = 'done';

/*

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
public_id               | status | progress |                                                                                               result                                                                                               
--------------------------------------+--------+----------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 78c48301-5db9-46d0-998d-6a7e4d9d1ad1 | done   |      100 | {}
 8e884845-603f-4ab1-97b1-920746996897 | done   |      100 | {"lufs": -14.2, "peaks": [0.2, 0.8, 0.5, 0.9, 0.3], "convert": "complete", "waveform": "complete", "normalize": "complete", "output_url": "s3://music-queue/processed.mp3", ...}

*/

-- ============================================================================

-- 2. What does the client see mid-processing (partial result)?

-- SELECT public_id, status, progress, result
-- FROM music_jobs
-- WHERE status = 'processing';

/*

--------------------------------------------------------------------------------------------------------------------------------------------------------
              public_id               |   status   | progress |                                         result                                          
--------------------------------------+------------+----------+-----------------------------------------------------------------------------------------
 3bd510de-bccd-40a2-b7eb-a23f75ce3216 | processing |       50 | {"lufs": -14.2, "normalize": "complete", "trimmed_ms": 320, "trim_silence": "complete"}

*/

-- ============================================================================

-- 3. How do you find all failed jobs?

-- SELECT id, public_id, error_msg
-- FROM music_jobs
-- WHERE status = 'failed';

/*

-------------------------------------------------------------------------------------------------------------------------------------------------
                  id                  |              public_id               |                             error_msg                             
--------------------------------------+--------------------------------------+-------------------------------------------------------------------
 019e2998-4a39-798d-9653-cd8bc8de04f0 | 497e30fc-5338-4083-8da4-622d10fc05f1 | codec not found: unable to decode wav header, file may be corrupt

*/

-- ============================================================================

-- 4. Show the full result object for a completed job

-- SELECT public_id, result
-- FROM music_jobs
-- WHERE status = 'done';

/*

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
              public_id               |                                                                                               result                                                                                               
--------------------------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 508aae29-e3ee-4580-966d-9c163ddd53fa | {}
 3bd510de-bccd-40a2-b7eb-a23f75ce3216 | {"lufs": -14.2, "peaks": [0.2, 0.8, 0.5, 0.9, 0.3], "convert": "complete", "waveform": "complete", "normalize": "complete", "output_url": "s3://music-queue/processed.mp3", ...}

*/


-- ============================================================================

-- Step 5 — updated_at

ALTER TABLE music_jobs
ADD COLUMN updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

-- Make it consistent: set updated_at = created_at for existing rows
UPDATE music_jobs SET updated_at = created_at;

-- ============================================================================

-- Questions & Answers

-- 1. Why is created_at not enough?
-- ANSWER: It only tells you when the job was created. It doesn't tell you when it was last updated.

-- 2. What goes wrong if application code maintains updated_at?
-- ANSWER: The database doesn't know when the job was last updated. So it doesn't know if the job is still being processed or not.

-- 3. Write a query that would power an SSE health check endpoint
-- ANSWER: SELECT * FROM music_jobs WHERE status != 'done';

-- ============================================================================

-- Sample Data

-- -- Update progress WITHOUT setting updated_at — updated_at will be stale
-- UPDATE music_jobs
-- SET progress = 10
-- WHERE id = (
--   SELECT id FROM music_jobs
--   WHERE status = 'pending'
--   ORDER BY created_at ASC
--   LIMIT 1
-- );

-- SELECT id, progress, created_at, updated_at FROM music_jobs
-- WHERE id = (
--   SELECT id FROM music_jobs ORDER BY created_at ASC LIMIT 1
-- );

-- -- Update the same job WITH updated_at = now() — now it is correct
-- UPDATE music_jobs
-- SET progress = 20,
--     updated_at = now()
-- WHERE id = (
--   SELECT id FROM music_jobs
--   ORDER BY created_at ASC
--   LIMIT 1
-- );

-- SELECT id, progress, created_at, updated_at FROM music_jobs
-- WHERE id = (
--   SELECT id FROM music_jobs ORDER BY created_at ASC LIMIT 1
-- );

-- -- Why this is fragile:
-- -- Every developer must remember to manually set updated_at = now() on every
-- -- UPDATE. If even one UPDATE forgets it, updated_at silently lies. There is
-- -- nothing stopping a buggy worker from updating progress and leaving updated_at
-- -- stale — the database will not catch it. A trigger solves this automatically.

-- ============================================================================

-- Sample Data Results:

-- Update progress WITHOUT setting updated_at — updated_at will be stale

/*

-----------------------------------------------------------------------------------------------------------------
                  id                  | progress |          created_at           |          updated_at           
--------------------------------------+----------+-------------------------------+-------------------------------
 019e29ab-64f2-7c5a-a606-2302f89976a9 |      100 | 2026-05-14 21:25:58.898295-06 | 2026-05-14 21:25:58.898295-06


*/



-- Update the same job WITH updated_at = now() — now it is correct

/*

----------------------------------------------------------------------------------------------------------------
                  id                  | progress |          created_at           |          updated_at          
--------------------------------------+----------+-------------------------------+------------------------------
 019e29ab-64f2-7c5a-a606-2302f89976a9 |       20 | 2026-05-14 21:25:58.898295-06 | 2026-05-14 21:27:15.69243-06

*/


-- Why this is fragile:
-- Every developer must remember to manually set updated_at = now() on every
-- UPDATE. If even one UPDATE forgets it, updated_at silently lies. There is
-- nothing stopping a buggy worker from updating progress and leaving updated_at
-- stale — the database will not catch it. A trigger solves this automatically.

-- ============================================================================


-- Verification Queries

-- 1. Find jobs that changed in the last 60 seconds

-- SELECT id, status, progress, updated_at
-- FROM music_jobs
-- WHERE updated_at >= now() - INTERVAL '60 seconds';

/*

-------------------------------------
 id | status | progress | updated_at 
----+--------+----------+------------

*/

-- ============================================================================

-- 2. Find jobs stuck in processing for more than 5 minutes

-- SELECT id, status, progress, updated_at
-- FROM music_jobs
-- WHERE status = 'processing'
--   AND updated_at < now() - INTERVAL '5 minutes';

/*

-------------------------------------
 id | status | progress | updated_at 
----+--------+----------+------------

*/

-- ============================================================================

-- 3. How long did each completed job take?

-- SELECT
--   public_id,
--   status,
--   created_at,
--   updated_at,
--   updated_at - created_at AS duration
-- FROM music_jobs
-- WHERE status = 'done';

/*

---------------------------------------------------------------------------------------------------------------------------------
              public_id               | status |          created_at           |          updated_at           |    duration     
--------------------------------------+--------+-------------------------------+-------------------------------+-----------------
 ba7dd3b3-be49-49c0-a810-4e10efa3dbee | done   | 2026-05-14 21:25:58.901502-06 | 2026-05-14 21:25:58.901502-06 | 00:00:00
 97b71d7a-f67b-426d-9ff9-0087c2aa2091 | done   | 2026-05-14 21:25:58.898295-06 | 2026-05-14 21:27:15.69243-06  | 00:01:16.794135

*/


-- ============================================================================

-- Step 6 — Trigger on updated_at

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER music_jobs_updated_at
BEFORE UPDATE ON music_jobs
FOR EACH ROW EXECUTE FUNCTION set_updated_at();


-- ============================================================================

-- Questions & Answers

-- 1. Why BEFORE UPDATE and not AFTER UPDATE?
-- ANSWER: BEFORE triggers operate on the NEW row *before* it's written. AFTER triggers operate 
--         on the *already written* row, so you can't modify it.

-- 2. What is NEW and what is OLD in a trigger function?
-- ANSWER: NEW refers to the row *after* the update. OLD refers to the row *before* the update.

-- 3. Why does returning NEW matter?
-- ANSWER: If you modify NEW (like setting NEW.updated_at = now()), returning NEW ensures 
--         those changes are saved back into the row. Without it, the trigger would run but 
--         its changes would be discarded.

-- 4. Why is the function reusable across tables?
-- ANSWER: Because it doesn't depend on any specific column names other than updated_at.

-- ============================================================================

-- Sample Data

-- -- Update progress WITHOUT mentioning updated_at — trigger fires automatically
-- UPDATE music_jobs
-- SET progress = 55
-- WHERE id = (
--   SELECT id FROM music_jobs ORDER BY created_at ASC LIMIT 1
-- );

-- SELECT id, progress, updated_at FROM music_jobs
-- WHERE id = (SELECT id FROM music_jobs ORDER BY created_at ASC LIMIT 1);
-- -- updated_at should now reflect the current time, even though we never set it

-- -- Try to sabotage it — set updated_at = '2000-01-01'
-- UPDATE music_jobs
-- SET progress = 60,
--     updated_at = '2000-01-01'
-- WHERE id = (
--   SELECT id FROM music_jobs ORDER BY created_at ASC LIMIT 1
-- );

-- SELECT id, progress, updated_at FROM music_jobs
-- WHERE id = (SELECT id FROM music_jobs ORDER BY created_at ASC LIMIT 1);
-- -- updated_at will still be now() — the trigger overwrote '2000-01-01'

-- ============================================================================

-- Sample Data Results

-- Update progress WITHOUT mentioning updated_at — trigger fires automatically

/*

---------------------------------------------------------------------------------
                  id                  | progress |          updated_at           
--------------------------------------+----------+-------------------------------
 019e29c1-6c7d-7cac-a938-0da189d3fddd |       55 | 2026-05-14 21:51:37.919729-06


*/


-- Try to sabotage it — set updated_at = '2000-01-01'

/*

---------------------------------------------------------------------------------
                  id                  | progress |          updated_at           
--------------------------------------+----------+-------------------------------
 019e29c1-6c7d-7cac-a938-0da189d3fddd |       60 | 2026-05-14 21:53:09.388063-06


*/

-- ============================================================================

-- Verification Queries

-- 1. Show trigger details from information_schema.triggers

-- SELECT trigger_name, event_manipulation, event_object_table,
--        action_timing, action_orientation
-- FROM information_schema.triggers
-- WHERE trigger_schema = 'public';

/*

------------------------------------------------------------------------------------------------------
     trigger_name      | event_manipulation | event_object_table | action_timing | action_orientation 
-----------------------+--------------------+--------------------+---------------+--------------------
 music_jobs_updated_at | UPDATE             | music_jobs         | BEFORE        | ROW

*/

-- ============================================================================


-- 2. Show function details from information_schema.routines

-- SELECT routine_name, routine_type, data_type, routine_definition
-- FROM information_schema.routines
-- WHERE routine_schema = 'public'
--   AND routine_name = 'set_updated_at';

/*

-------------------------------------------------------------------------
  routine_name  | routine_type | data_type |     routine_definition      
----------------+--------------+-----------+-----------------------------
 set_updated_at | FUNCTION     | trigger   |                            +
                |              |           | BEGIN                      +
                |              |           |     NEW.updated_at = now();+
                |              |           |     RETURN NEW;            +
                |              |           | END;                       +
                |              |           | 

*/