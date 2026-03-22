-- ================================================================
-- Dart Attack — Update survey questions to match game changes
-- Run in Supabase Dashboard > SQL Editor > paste this > Run
--
-- STEP 1: Add new columns to survey_questions
-- STEP 2: Update the question data
-- ================================================================

-- STEP 1: Add new columns (skips if they already exist)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'survey_questions' AND column_name = 'intro_text') THEN
    ALTER TABLE survey_questions ADD COLUMN intro_text TEXT DEFAULT '';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'survey_questions' AND column_name = 'exclusive_answer') THEN
    ALTER TABLE survey_questions ADD COLUMN exclusive_answer TEXT DEFAULT '';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'survey_questions' AND column_name = 'repeatable_days') THEN
    ALTER TABLE survey_questions ADD COLUMN repeatable_days INTEGER DEFAULT 0;
  END IF;
END $$;

-- STEP 2: Now update the question data

-- Q1: Add intro text + exclusive answer
UPDATE survey_questions SET
  intro_text = 'To help our developers build a better game, we''d love to know a bit about you.',
  exclusive_answer = 'None of these'
WHERE id = 1;

-- Q2: Change type from star_rating to rating_select, move to after L2 win, make repeatable every 60 days
UPDATE survey_questions SET
  question_type = 'rating_select',
  trigger_point = 'l2_win_rating',
  repeatable_days = 60
WHERE id = 2;

-- Q3: Update question text + exclusive answer
UPDATE survey_questions SET
  question_text = 'What are you loving about the game, if anything?',
  exclusive_answer = 'Nothing yet'
WHERE id = 3;

-- Q6: Update question text, answers, intro text, exclusive answer
UPDATE survey_questions SET
  question_text = 'Would you pay £££ for any of these?',
  answers = '["Upload a photo to play as yourself", "Upload a photo and nickname to become an opponent everyone plays against", "Add new pre-drinks", "Gift the developers", "I wouldn''t pay"]',
  exclusive_answer = 'I wouldn''t pay',
  intro_text = 'We are determined not to flood this game with cheap adverts which interrupt your play.'
WHERE id = 6;
