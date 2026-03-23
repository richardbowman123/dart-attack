-- ================================================================
-- Dart Attack — Complete RLS policy fix (idempotent — safe to re-run)
-- Run in Supabase Dashboard > SQL Editor > paste this > Run
--
-- Uses DROP IF EXISTS + CREATE so it works whether or not
-- policies already exist. No errors, no conflicts.
-- ================================================================

-- ── SESSIONS ──
DROP POLICY IF EXISTS "sessions_insert_own" ON sessions;
CREATE POLICY "sessions_insert_own"
  ON sessions FOR INSERT TO authenticated
  WITH CHECK (player_id = auth.uid());

DROP POLICY IF EXISTS "sessions_select_own" ON sessions;
CREATE POLICY "sessions_select_own"
  ON sessions FOR SELECT TO authenticated
  USING (player_id = auth.uid());

DROP POLICY IF EXISTS "sessions_update_own" ON sessions;
CREATE POLICY "sessions_update_own"
  ON sessions FOR UPDATE TO authenticated
  USING (player_id = auth.uid())
  WITH CHECK (player_id = auth.uid());

-- ── PROFILES ──
DROP POLICY IF EXISTS "profiles_select_own" ON profiles;
CREATE POLICY "profiles_select_own"
  ON profiles FOR SELECT TO authenticated
  USING (id = auth.uid());

DROP POLICY IF EXISTS "profiles_update_own" ON profiles;
CREATE POLICY "profiles_update_own"
  ON profiles FOR UPDATE TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- ── EVENTS ──
DROP POLICY IF EXISTS "events_insert_own" ON events;
CREATE POLICY "events_insert_own"
  ON events FOR INSERT TO authenticated
  WITH CHECK (player_id = auth.uid());

-- ── SURVEY QUESTIONS (all authenticated users can read) ──
DROP POLICY IF EXISTS "survey_questions_select_all" ON survey_questions;
CREATE POLICY "survey_questions_select_all"
  ON survey_questions FOR SELECT TO authenticated
  USING (true);

-- ── SURVEY RESPONSES ──
DROP POLICY IF EXISTS "survey_responses_insert_own" ON survey_responses;
CREATE POLICY "survey_responses_insert_own"
  ON survey_responses FOR INSERT TO authenticated
  WITH CHECK (player_id = auth.uid());

DROP POLICY IF EXISTS "survey_responses_select_own" ON survey_responses;
CREATE POLICY "survey_responses_select_own"
  ON survey_responses FOR SELECT TO authenticated
  USING (player_id = auth.uid());
