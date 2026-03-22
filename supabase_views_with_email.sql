-- ================================================================
-- Dart Attack — Create browsable views with email addresses
-- Run in Supabase Dashboard > SQL Editor > paste this > Run
-- ================================================================

-- Sessions with email
CREATE OR REPLACE VIEW sessions_with_email AS
SELECT
  s.*,
  p.email
FROM sessions s
LEFT JOIN profiles p ON s.player_id = p.id;

-- Events with email
CREATE OR REPLACE VIEW events_with_email AS
SELECT
  e.*,
  p.email
FROM events e
LEFT JOIN profiles p ON e.player_id = p.id;

-- Survey responses with email
CREATE OR REPLACE VIEW survey_responses_with_email AS
SELECT
  sr.*,
  p.email,
  sq.question_text
FROM survey_responses sr
LEFT JOIN profiles p ON sr.player_id = p.id
LEFT JOIN survey_questions sq ON sr.question_id = sq.id;
