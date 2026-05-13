# postgres-music-queue

### Database Setup

1. Create database:
   ```sql
   CREATE DATABASE music_queue;
   \c music_queue
   CREATE USER music_queue WITH PASSWORD 'music_queue';
   GRANT ALL PRIVILEGES ON DATABASE music_queue TO music_queue;
   GRANT ALL PRIVILEGES ON SCHEMA public TO music_queue;
   ```

2. Connect to the database:
   ```bash
   psql -h localhost -U music_queue -d music_queue
   ```

### Migration Setup

1. Create migrations folder:
   ```bash
   mkdir -p migrations
   ```

2. Create migrations:
   ```bash
   migrate create -ext sql -dir ./migrations -seq <name-of-table>
   ```

3. Apply migrations:
   ```bash
   migrate -path ./migrations -database "postgresql://music_queue:music_queue@localhost:5432/music_queue?sslmode=disable" up
   ```
   OR to rollback migrations:
   ```bash
   migrate -path ./migrations -database "postgresql://music_queue:music_queue@localhost:5432/music_queue?sslmode=disable" down
   ```
   


   