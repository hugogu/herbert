CREATE TABLE users (
  user_id TEXT PRIMARY KEY, apple_subject TEXT UNIQUE, display_name TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'active' CHECK(status IN ('active','blocked','deleted')),
  apple_refresh_cipher TEXT, created_at INTEGER NOT NULL, deleted_at INTEGER
);
CREATE TABLE sessions (
  session_id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(user_id),
  refresh_hash TEXT UNIQUE NOT NULL, expires_at INTEGER NOT NULL, revoked_at INTEGER
);
CREATE INDEX sessions_user ON sessions(user_id);
CREATE TABLE challenges (challenge_id TEXT PRIMARY KEY, nonce_hash TEXT NOT NULL, expires_at INTEGER NOT NULL);
CREATE TABLE submissions (
  submission_id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(user_id),
  request_id TEXT NOT NULL, problem_id INTEGER NOT NULL, puzzle_version TEXT NOT NULL,
  rules_version TEXT NOT NULL, source TEXT NOT NULL, bytes INTEGER NOT NULL, steps INTEGER NOT NULL,
  lit_targets INTEGER NOT NULL, target_count INTEGER NOT NULL, points REAL NOT NULL,
  accepted INTEGER NOT NULL, hidden_at INTEGER, created_at INTEGER NOT NULL,
  UNIQUE(user_id, request_id)
);
CREATE INDEX submissions_ranking ON submissions(puzzle_version, user_id, problem_id, points DESC);
CREATE INDEX submissions_user ON submissions(user_id, created_at DESC);
CREATE TABLE rate_limits (bucket_key TEXT PRIMARY KEY, count INTEGER NOT NULL, expires_at INTEGER NOT NULL);
CREATE TABLE admin_audit (
  audit_id TEXT PRIMARY KEY, actor TEXT NOT NULL, action TEXT NOT NULL,
  target_id TEXT NOT NULL, reason TEXT NOT NULL, created_at INTEGER NOT NULL
);
