-- ================================================================
-- Dart Attack — Fix missing RLS policies
-- Run in Supabase Dashboard > SQL Editor > paste this > Run
--
-- Problem: INSERT policies existed but SELECT/UPDATE were missing.
-- This meant sessions couldn't be read back (no session_id on events)
-- and couldn't be updated (no ended_at or duration).
-- Also fixes survey and profile policies that may have been failing
-- silently.
--
-- If any line fails with "policy already exists", that's fine —
-- it means that policy was already set up correctly.
-- ================================================================

-- SESSIONS: players can read + update their own sessions
CREATE POLICY "sessions_select_own"
  ON sessions FOR SELECT TO authenticated
  USING (player_id = auth.uid());

CREATE POLICY "sessions_update_own"
  ON sessions FOR UPDATE TO authenticated
  USING (player_id = auth.uid())
  WITH CHECK (player_id = auth.uid());

-- PROFILES: players can read + update their own profile
CREATE POLICY "profiles_select_own"
  ON profiles FOR SELECT TO authenticated
  USING (id = auth.uid());

CREATE POLICY "profiles_update_own"
  ON profiles FOR UPDATE TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- SURVEY QUESTIONS: all authenticated users can read questions
CREATE POLICY "survey_questions_select_all"
  ON survey_questions FOR SELECT TO authenticated
  USING (true);

-- SURVEY RESPONSES: players can save + read their own responses
CREATE POLICY "survey_responses_insert_own"
  ON survey_responses FOR INSERT TO authenticated
  WITH CHECK (player_id = auth.uid());

CREATE POLICY "survey_responses_select_own"
  ON survey_responses FOR SELECT TO authenticated
  USING (player_id = auth.uid());
