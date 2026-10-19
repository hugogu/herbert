-- Transactional outbox: encrypted Apple grants survive only until revocation or bounded abandonment.
CREATE TABLE apple_revocations (
  revocation_id TEXT PRIMARY KEY,
  cipher TEXT UNIQUE,
  attempts INTEGER NOT NULL DEFAULT 0,
  next_attempt_at INTEGER NOT NULL,
  lease_until INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','revoked','unrevocable','exhausted')),
  created_at INTEGER NOT NULL,
  finished_at INTEGER
);
CREATE INDEX apple_revocations_due ON apple_revocations(status, next_attempt_at, lease_until);
