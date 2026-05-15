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
-- ANSWER: SERIAL is a sequence. The database hands out IDs one at a time, in order. That's fine
--         for a single database, but if you ever scale out, you'd get duplicate IDs across instances.
--         UUID can be generated anywhere without coordination, so duplication isn't a concern.
--         Security-wise, SERIAL IDs are predictable (1, 2, 3...). An attacker can easily guess
--         other valid IDs. UUIDs aren't guessable.

-- 2. Why uuidv7() specifically over uuidv4()?
-- ANSWER: uuidv7() embeds a millisecond timestamp in its high bits, so IDs sort in the order they
--         were created. That matters for B-tree indexes because it keeps sequential inserts compact
--         and writes fast. uuidv4() is completely random, so every new row lands in a random spot
--         in the index, causing fragmentation and slower writes over time.

-- 3. Why JSONB over JSON?
-- ANSWER: JSON is stored as raw text and re-parsed on every read. JSONB parses the data once at
--         insert time and stores it in binary, so queries are significantly faster. The tradeoff is
--         inserts are slightly slower, but for a job queue that's read far more than it's written,
--         JSONB is the better choice.

-- 4. Why TIMESTAMPTZ over TIMESTAMP?
-- ANSWER: TIMESTAMP stores time as-is with no timezone info. If the server is in UTC and a client
--         is in CST, you'd get confusing results with no way to convert. TIMESTAMPTZ stores
--         everything in UTC internally and converts to the session timezone on retrieval, so
--         everyone sees the correct time regardless of where they are.

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
-- ANSWER: public_id is what gets sent to clients. It shows up in API responses and URLs.
--         uuidv7() embeds a timestamp that anyone can extract with uuid_extract_timestamp(),
--         which would leak when the job was created. uuidv4() is completely random, so there's
--         nothing to extract from it. No metadata, no timing info.

-- 2. What does uuid_extract_timestamp() reveal about uuidv7?
-- ANSWER: It returns the exact millisecond the ID was generated. Running it on id gives you
--         a real timestamp. Running it on public_id returns NULL because uuidv4 has no embedded
--         timestamp — it's just random bytes. That NULL result is the whole point.

-- 3. Why does the UNIQUE constraint make CREATE INDEX unnecessary?
-- ANSWER: PostgreSQL automatically creates a B-tree index to enforce every UNIQUE constraint.
--         Adding CREATE INDEX on top of it would just create a duplicate index, wasting storage.

-- 4. What is the two-ID pattern and why does it matter?
-- ANSWER: The table has two identifiers: id (internal, uuidv7) and public_id (external, uuidv4).
--         id is optimized for database performance because it's time-ordered for fast B-tree inserts.
--         public_id is what gets exposed to clients because it's random, non-guessable, and reveals nothing
--         about the internals. This way we never hand our primary key to the outside world.

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
-- ANSWER: The worker and client query these fields constantly. If they were inside payload,
--         every query would need payload->>'status', which can't use a regular index the same
--         way. Real columns are indexable, type-safe, and have constraints because JSONB fields aren't.

-- 2. What happens if a buggy worker writes status = 'complet'?
-- ANSWER: PostgreSQL rejects the write with a check constraint violation error. The row never
--         makes it into the table, not even partially.

-- 3. Why does the CHECK constraint matter more than application validation?
-- ANSWER: Application validation can be bypassed by a buggy worker, a direct psql edit, a future
--         developer who doesn't know the rules. The CHECK constraint is enforced by the database
--         itself, so no matter how the data gets written, it has to pass. The database is the
--         last line of defense.

-- 4. Draw the state machine for a job lifecycle
-- ANSWER:

/*

  pending
    ↓
  processing
    ↓         ↘
  done       failed

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

-- -- Invalid status
-- UPDATE music_jobs
-- SET status = 'complet'
-- WHERE id = (SELECT id FROM music_jobs ORDER BY created_at LIMIT 1);

-- -- Invalid progress
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
-- ANSWER: An empty object '{}' is safe to merge with || and serializes cleanly to JSON in
--         the application. NULL would require null checks everywhere before doing anything
--         with the result field, which is easy to forget and leads to runtime errors.

-- 2. Why is error_msg TEXT and not inside the result JSONB?
-- ANSWER: error_msg needs to be NULL when there's no error. That NULL is a meaningful signal.
--         If it lived inside result JSONB, you'd have to check result->>'error_msg' IS NULL,
--         which is less clear and can't use a standard index. A separate TEXT column is directly
--         queryable, filterable, and its NULL state is unambiguous.

-- 3. What does the || operator do to a JSONB object?
-- ANSWER: It merges two JSONB objects into one. If both sides have the same key, the
--         right-hand side wins. That's how each stage appends its output without overwriting
--         what the previous stages already stored.

-- 4. Why does each stage read from the original file, not the previous stage's output?
-- ANSWER: It makes each stage idempotent because if the job is retried, it doesn't need the previous
--         stage's output to already exist. It also avoids storing intermediate files that would
--         need cleanup if something fails halfway through.

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
UPDATE music_jobs SET updated_at = created_at;

-- ============================================================================

-- Questions & Answers

-- 1. Why is created_at not enough?
-- ANSWER: created_at never changes because it only tells you when the job was created. You can't
--         use it to detect stuck jobs, recent activity, or whether a job is making progress.
--         You need a column that actually updates when the row changes.

-- 2. What goes wrong if application code maintains updated_at?
-- ANSWER: If even one UPDATE forgets to include updated_at = now(), the column silently shows
--         the wrong time. The database has no way to enforce it, it just stores whatever you
--         give it. A trigger removes that risk by handling it automatically.

-- 3. Write a query that would power an SSE health check endpoint
-- ANSWER: SELECT * FROM music_jobs
--         WHERE updated_at >= now() - INTERVAL '5 seconds'
--         ORDER BY updated_at DESC;
--         The SSE endpoint would run this on a short interval and push any changed rows to
--         connected clients, so they see updates in near real-time without long-polling.

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
-- ANSWER: BEFORE triggers let you modify the NEW row before it's written to disk. AFTER triggers
--         fire after the write is already done, so the row is saved and you can't change it.
--         Since we need to set updated_at on the row being updated, BEFORE is the only option.

-- 2. What is NEW and what is OLD in a trigger function?
-- ANSWER: NEW is the row as it will look after the update — the version we're about to save.
--         OLD is what the row looked like before the update. We modify NEW.updated_at so the
--         new timestamp gets written when the row is saved.

-- 3. Why does returning NEW matter?
-- ANSWER: BEFORE row-level triggers must return the row they want PostgreSQL to save.
--         If we return NULL, the update gets cancelled entirely. If we return NEW without
--         our changes, those changes are lost. Returning the modified NEW is what makes
--         the trigger's work actually stick.

-- 4. Why is the function reusable across tables?
-- ANSWER: The function only references NEW.updated_at because it has no table names or other columns.
--         As long as a table has an updated_at column, you can attach this trigger to it
--         and it'll just work.

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


-- ============================================================================

-- Step 7 — Indexes + EXPLAIN ANALYZE

-- Part A — Generate 50,000 rows with guaranteed distribution
INSERT INTO music_jobs (payload, status, progress)
SELECT
  jsonb_build_object(
    'filename',     'track_' || i || CASE (i % 2) WHEN 0 THEN '.mp3' ELSE '.wav' END,
    'artist',       CASE (i % 4)
                      WHEN 0 THEN 'Andy Palacio'
                      WHEN 1 THEN 'Supa G'
                      WHEN 2 THEN 'Mohobub Flores'
                      ELSE 'Garifuna Collective'
                    END,
    'genre',        CASE (i % 4)
                      WHEN 0 THEN 'garifuna'
                      WHEN 1 THEN 'soca'
                      WHEN 2 THEN 'brukdown'
                      ELSE 'punta'
                    END,
    'mime_type',    CASE (i % 2) WHEN 0 THEN 'audio/mpeg' ELSE 'audio/wav' END,
    'duration_sec', 120 + (i % 180)
  ),
  CASE (i % 4)
    WHEN 0 THEN 'pending'
    WHEN 1 THEN 'processing'
    WHEN 2 THEN 'done'
    ELSE 'failed'
  END,
  CASE (i % 4)
    WHEN 0 THEN 0
    WHEN 1 THEN 50
    WHEN 2 THEN 100
    ELSE 0
  END
FROM generate_series(1, 50000) AS i;

-- ============================================================================

-- B-tree composite index: for worker polling (filter by status, order by created_at)
CREATE INDEX idx_jobs_status_created ON music_jobs (status, created_at);

-- B-tree index: for updated_at queries (SSE / stuck job detection)
CREATE INDEX idx_jobs_updated_at ON music_jobs (updated_at DESC);

-- GIN index: for JSONB containment queries on payload (@>)
CREATE INDEX idx_jobs_payload ON music_jobs USING GIN (payload);

-- GIN index: for JSONB containment queries on result (@>)
CREATE INDEX idx_jobs_result ON music_jobs USING GIN (result);

-- ============================================================================

-- Part B — Run EXPLAIN ANALYZE on three queries BEFORE adding any indexes

/*

                                                           QUERY PLAN                                                           
--------------------------------------------------------------------------------------------------------------------------------
 Limit  (cost=2250.35..2250.35 rows=1 width=164) (actual time=9.253..9.254 rows=1.00 loops=1)
   Buffers: shared hit=1563
   ->  Sort  (cost=2250.35..2281.53 rows=12470 width=164) (actual time=9.251..9.251 rows=1.00 loops=1)
         Sort Key: created_at
         Sort Method: top-N heapsort  Memory: 25kB
         Buffers: shared hit=1563
         ->  Seq Scan on music_jobs  (cost=0.00..2188.00 rows=12470 width=164) (actual time=0.018..7.113 rows=12500.00 loops=1)
               Filter: (status = 'pending'::text)
               Rows Removed by Filter: 37500
               Buffers: shared hit=1563
 Planning:
   Buffers: shared hit=68 dirtied=1
 Planning Time: 0.379 ms
 Execution Time: 9.277 ms
(14 rows)

                                                                QUERY PLAN                                                                
------------------------------------------------------------------------------------------------------------------------------------------
 Index Scan using music_jobs_public_id_key on music_jobs  (cost=0.33..8.35 rows=1 width=64) (actual time=0.015..0.016 rows=1.00 loops=1)
   Index Cond: (public_id = (InitPlan 1).col1)
   Index Searches: 1
   Buffers: shared hit=5
   InitPlan 1
     ->  Limit  (cost=0.00..0.04 rows=1 width=16) (actual time=0.005..0.006 rows=1.00 loops=1)
           Buffers: shared hit=2
           ->  Seq Scan on music_jobs music_jobs_1  (cost=0.00..2063.00 rows=50000 width=16) (actual time=0.004..0.005 rows=1.00 loops=1)
                 Buffers: shared hit=2
 Planning:
   Buffers: shared hit=15
 Planning Time: 0.101 ms
 Execution Time: 0.027 ms
(13 rows)

                                                    QUERY PLAN                                                     
-------------------------------------------------------------------------------------------------------------------
 Seq Scan on music_jobs  (cost=0.00..2249.87 rows=24747 width=48) (actual time=0.006..8.273 rows=25000.00 loops=1)
   Filter: (payload @> '{"mime_type": "audio/mpeg"}'::jsonb)
   Rows Removed by Filter: 25000
   Buffers: shared hit=1563
 Planning Time: 0.054 ms
 Execution Time: 9.020 ms
(6 rows)

*/

-- ============================================================================

-- Part D — Run EXPLAIN ANALYZE on the same three queries AFTER indexes

/*

                                                                      QUERY PLAN                                                                      
------------------------------------------------------------------------------------------------------------------------------------------------------
 Limit  (cost=0.29..0.80 rows=1 width=164) (actual time=0.043..0.043 rows=1.00 loops=1)
   Buffers: shared hit=1 read=2
   ->  Index Scan using idx_jobs_status_created on music_jobs  (cost=0.29..6310.03 rows=12470 width=164) (actual time=0.041..0.042 rows=1.00 loops=1)
         Index Cond: (status = 'pending'::text)
         Index Searches: 1
         Buffers: shared hit=1 read=2
 Planning:
   Buffers: shared hit=57 read=2
 Planning Time: 0.318 ms
 Execution Time: 0.061 ms
(10 rows)

                                                                QUERY PLAN                                                                
------------------------------------------------------------------------------------------------------------------------------------------
 Index Scan using music_jobs_public_id_key on music_jobs  (cost=0.33..8.35 rows=1 width=64) (actual time=0.024..0.025 rows=1.00 loops=1)
   Index Cond: (public_id = (InitPlan 1).col1)
   Index Searches: 1
   Buffers: shared hit=5
   InitPlan 1
     ->  Limit  (cost=0.00..0.04 rows=1 width=16) (actual time=0.009..0.010 rows=1.00 loops=1)
           Buffers: shared hit=2
           ->  Seq Scan on music_jobs music_jobs_1  (cost=0.00..2063.00 rows=50000 width=16) (actual time=0.009..0.009 rows=1.00 loops=1)
                 Buffers: shared hit=2
 Planning Time: 0.087 ms
 Execution Time: 0.040 ms
(11 rows)

                                                              QUERY PLAN                                                              
--------------------------------------------------------------------------------------------------------------------------------------
 Bitmap Heap Scan on music_jobs  (cost=197.09..2131.29 rows=24747 width=48) (actual time=3.216..11.621 rows=25000.00 loops=1)
   Recheck Cond: (payload @> '{"mime_type": "audio/mpeg"}'::jsonb)
   Heap Blocks: exact=1563
   Buffers: shared hit=1587
   ->  Bitmap Index Scan on idx_jobs_payload  (cost=0.00..190.90 rows=24747 width=0) (actual time=2.949..2.949 rows=25000.00 loops=1)
         Index Cond: (payload @> '{"mime_type": "audio/mpeg"}'::jsonb)
         Index Searches: 1
         Buffers: shared hit=24
 Planning:
   Buffers: shared hit=7
 Planning Time: 0.140 ms
 Execution Time: 12.638 ms
(12 rows)

*/

-- ============================================================================

-- Questions and Answers

-- 1. What is a sequential scan and why is it slow at scale?
-- ANSWER: A sequential scan is when the database has to scan through the entire table to find the data it needs.
--         It is slow at scale because as the table grows, the time it takes to scan through the entire table also grows.


-- 2. Why does the worker poll query need a COMPOSITE index and not just an index on status alone?
-- ANSWER: A composite index is needed because the worker query needs to filter by status and order by created_at.
--         An index on status alone would not be enough to satisfy both conditions.

-- 3. Why GIN and not btree for JSONB columns?
-- ANSWER: A GIN (Generalized Inverted Index) is used for JSONB columns because it allows for efficient indexing of the key-value pairs within the JSONB data.
--         B-trees are not suitable for JSONB data because they are designed for ordered, scalar data types.

-- 4. Which operators USE the GIN index? Which do NOT?
-- ANSWER: The GIN index is used for the @> operator (contains).
--         The GIN index is not used for the = operator (equals).

-- 5. What speedup did you measure? Show the before/after execution times.
-- ANSWER:
--   Query 1 (worker poll):      9.277 ms → 0.061 ms (~152x faster)
--                               The composite index on (status, created_at) eliminated
--                               the sequential scan and sort entirely.
--
--   Query 2 (client poll):      0.027 ms → 0.040 ms (no meaningful change)
--                               It was already using the index created automatically
--                               by the UNIQUE constraint on public_id in Step 2.
--
--   Query 3 (JSONB containment): 9.020 ms → 12.638 ms (slightly slower)
--                               The GIN index was used (Bitmap Index Scan), but the
--                               query matches 25,000 of 50,000 rows (50% selectivity).
--                               At that scale, the overhead of fetching 1,563 heap
--                               blocks via bitmap outweighs a sequential scan. GIN
--                               indexes shine on highly selective queries — not when
--                               half the table qualifies.

-- ============================================================================

-- Final Verification

/*

-----------------------------------------------------------------------------------------------------------------------
        indexname         |                                          indexdef                                          
--------------------------+--------------------------------------------------------------------------------------------
 idx_jobs_payload         | CREATE INDEX idx_jobs_payload ON public.music_jobs USING gin (payload)
 idx_jobs_result          | CREATE INDEX idx_jobs_result ON public.music_jobs USING gin (result)
 idx_jobs_status_created  | CREATE INDEX idx_jobs_status_created ON public.music_jobs USING btree (status, created_at)
 idx_jobs_updated_at      | CREATE INDEX idx_jobs_updated_at ON public.music_jobs USING btree (updated_at DESC)
 music_jobs_pkey          | CREATE UNIQUE INDEX music_jobs_pkey ON public.music_jobs USING btree (id)
 music_jobs_public_id_key | CREATE UNIQUE INDEX music_jobs_public_id_key ON public.music_jobs USING btree (public_id)

*/

/*

                           Table "public.music_jobs"
   Column   |           Type           | Collation | Nullable |     Default     
------------+--------------------------+-----------+----------+-----------------
 id         | uuid                     |           | not null | uuidv7()
 payload    | jsonb                    |           | not null | 
 created_at | timestamp with time zone |           |          | now()
 public_id  | uuid                     |           | not null | uuidv4()
 status     | text                     |           | not null | 'pending'::text
 progress   | integer                  |           | not null | 0
 result     | jsonb                    |           | not null | '{}'::jsonb
 error_msg  | text                     |           |          | 
 updated_at | timestamp with time zone |           | not null | now()
Indexes:
    "music_jobs_pkey" PRIMARY KEY, btree (id)
    "idx_jobs_payload" gin (payload)
    "idx_jobs_result" gin (result)
    "idx_jobs_status_created" btree (status, created_at)
    "idx_jobs_updated_at" btree (updated_at DESC)
    "music_jobs_public_id_key" UNIQUE CONSTRAINT, btree (public_id)
Check constraints:
    "music_jobs_progress_check" CHECK (progress >= 0 AND progress <= 100)
    "music_jobs_status_check" CHECK (status = ANY (ARRAY['pending'::text, 'processing'::text, 'done'::text, 'failed'::text]))
Triggers:
    music_jobs_updated_at BEFORE UPDATE ON music_jobs FOR EACH ROW EXECUTE FUNCTION set_updated_at()

*/