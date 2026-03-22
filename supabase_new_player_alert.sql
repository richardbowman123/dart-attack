-- ================================================================
-- Dart Attack — Email Richard when a new player signs up
-- Run in Supabase Dashboard > SQL Editor > paste this > Run
-- ================================================================

-- 1. Enable pg_net (lets the database make HTTP requests)
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

-- 2. Store Resend API key securely in Supabase vault
-- (delete old entries first — previous run had params swapped)
DELETE FROM vault.secrets WHERE name = 'resend_api_key';
DELETE FROM vault.secrets WHERE name = 're_cR4vKvk6_HXDTNXKckcs6Nyd4MwMi2DVY';
SELECT vault.create_secret(
  're_cR4vKvk6_HXDTNXKckcs6Nyd4MwMi2DVY',
  'resend_api_key',
  'Resend API key for new player email notifications'
);

-- 3. Create the notification function
CREATE OR REPLACE FUNCTION notify_new_player()
RETURNS TRIGGER AS $$
DECLARE
  api_key TEXT;
BEGIN
  SELECT decrypted_secret INTO api_key
    FROM vault.decrypted_secrets
    WHERE name = 'resend_api_key' LIMIT 1;

  IF api_key IS NOT NULL THEN
    PERFORM net.http_post(
      url := 'https://api.resend.com/emails',
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || api_key,
        'Content-Type', 'application/json'
      ),
      body := jsonb_build_object(
        'from', 'Dart Attack <onboarding@resend.dev>',
        'to', 'r_a_bowman@hotmail.com',
        'subject', 'New Dart Attack player!',
        'html', '<p style="font-family:Arial,sans-serif;font-size:16px;">A new player just signed up:</p><p style="font-family:Arial,sans-serif;font-size:20px;font-weight:bold;">' || COALESCE(NEW.email, 'unknown') || '</p><p style="font-family:Arial,sans-serif;font-size:14px;color:#888;">Check the <a href="https://supabase.com/dashboard">Supabase dashboard</a> for details.</p>'
      )
    );
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Never let a notification failure break signups
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Create the trigger (fires after every new profile row)
DROP TRIGGER IF EXISTS on_new_player ON profiles;
CREATE TRIGGER on_new_player
  AFTER INSERT ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION notify_new_player();
