-- Compression bonuses apply only after solving; partial coverage never outranks a solved puzzle.
UPDATE submissions SET points=ROUND(80.0*lit_targets/target_count,2) WHERE accepted=0 AND target_count>0 AND bytes>0;
CREATE INDEX submissions_best_lookup ON submissions(user_id, problem_id, puzzle_version, rules_version, hidden_at, accepted DESC, points DESC, bytes, steps, created_at, submission_id);
CREATE TABLE best_submissions (
  user_id TEXT NOT NULL REFERENCES users(user_id), problem_id INTEGER NOT NULL,
  puzzle_version TEXT NOT NULL, rules_version TEXT NOT NULL,
  submission_id TEXT NOT NULL REFERENCES submissions(submission_id), min_accepted_bytes INTEGER,
  PRIMARY KEY(user_id, problem_id, puzzle_version, rules_version)
);
INSERT INTO best_submissions
SELECT user_id,problem_id,puzzle_version,rules_version,submission_id,min_accepted_bytes FROM (
 SELECT *,ROW_NUMBER() OVER(PARTITION BY user_id,problem_id,puzzle_version,rules_version ORDER BY accepted DESC,points DESC,bytes,steps,created_at,submission_id) attempt,
 MIN(CASE WHEN accepted=1 THEN bytes END) OVER(PARTITION BY user_id,problem_id,puzzle_version,rules_version) min_accepted_bytes
 FROM submissions WHERE hidden_at IS NULL
) WHERE attempt=1;

-- Keep the read model atomic with uploads, moderation and erasure; public reads never rebuild history.
CREATE TRIGGER submissions_best_insert AFTER INSERT ON submissions BEGIN
DELETE FROM best_submissions WHERE user_id=NEW.user_id AND problem_id=NEW.problem_id AND puzzle_version=NEW.puzzle_version AND rules_version=NEW.rules_version;
 INSERT INTO best_submissions
 SELECT user_id,problem_id,puzzle_version,rules_version,submission_id,
   (SELECT MIN(bytes) FROM submissions WHERE user_id=NEW.user_id AND problem_id=NEW.problem_id AND puzzle_version=NEW.puzzle_version AND rules_version=NEW.rules_version AND hidden_at IS NULL AND accepted=1)
 FROM submissions WHERE user_id=NEW.user_id AND problem_id=NEW.problem_id AND puzzle_version=NEW.puzzle_version AND rules_version=NEW.rules_version AND hidden_at IS NULL ORDER BY accepted DESC,points DESC,bytes,steps,created_at,submission_id LIMIT 1;
END;
CREATE TRIGGER submissions_best_update AFTER UPDATE ON submissions BEGIN
DELETE FROM best_submissions WHERE user_id=OLD.user_id AND problem_id=OLD.problem_id AND puzzle_version=OLD.puzzle_version AND rules_version=OLD.rules_version;
 INSERT INTO best_submissions
 SELECT user_id,problem_id,puzzle_version,rules_version,submission_id,
   (SELECT MIN(bytes) FROM submissions WHERE user_id=OLD.user_id AND problem_id=OLD.problem_id AND puzzle_version=OLD.puzzle_version AND rules_version=OLD.rules_version AND hidden_at IS NULL AND accepted=1)
 FROM submissions WHERE user_id=OLD.user_id AND problem_id=OLD.problem_id AND puzzle_version=OLD.puzzle_version AND rules_version=OLD.rules_version AND hidden_at IS NULL ORDER BY accepted DESC,points DESC,bytes,steps,created_at,submission_id LIMIT 1;
DELETE FROM best_submissions WHERE user_id=NEW.user_id AND problem_id=NEW.problem_id AND puzzle_version=NEW.puzzle_version AND rules_version=NEW.rules_version;
 INSERT INTO best_submissions
 SELECT user_id,problem_id,puzzle_version,rules_version,submission_id,
   (SELECT MIN(bytes) FROM submissions WHERE user_id=NEW.user_id AND problem_id=NEW.problem_id AND puzzle_version=NEW.puzzle_version AND rules_version=NEW.rules_version AND hidden_at IS NULL AND accepted=1)
 FROM submissions WHERE user_id=NEW.user_id AND problem_id=NEW.problem_id AND puzzle_version=NEW.puzzle_version AND rules_version=NEW.rules_version AND hidden_at IS NULL ORDER BY accepted DESC,points DESC,bytes,steps,created_at,submission_id LIMIT 1;
END;
CREATE TRIGGER submissions_best_delete AFTER DELETE ON submissions BEGIN
DELETE FROM best_submissions WHERE user_id=OLD.user_id AND problem_id=OLD.problem_id AND puzzle_version=OLD.puzzle_version AND rules_version=OLD.rules_version;
 INSERT INTO best_submissions
 SELECT user_id,problem_id,puzzle_version,rules_version,submission_id,
   (SELECT MIN(bytes) FROM submissions WHERE user_id=OLD.user_id AND problem_id=OLD.problem_id AND puzzle_version=OLD.puzzle_version AND rules_version=OLD.rules_version AND hidden_at IS NULL AND accepted=1)
 FROM submissions WHERE user_id=OLD.user_id AND problem_id=OLD.problem_id AND puzzle_version=OLD.puzzle_version AND rules_version=OLD.rules_version AND hidden_at IS NULL ORDER BY accepted DESC,points DESC,bytes,steps,created_at,submission_id LIMIT 1;
END;
