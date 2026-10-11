-- Account lifecycle events are signed by Apple. Keep replay markers only, no JWTs.
ALTER TABLE sessions ADD COLUMN created_at INTEGER NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN apple_authorized_at INTEGER NOT NULL DEFAULT 0;
CREATE TABLE apple_events (
  event_id TEXT PRIMARY KEY, created_at INTEGER NOT NULL, handled_at INTEGER
);
