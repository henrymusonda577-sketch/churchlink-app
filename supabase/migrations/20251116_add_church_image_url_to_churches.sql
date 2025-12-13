-- Add missing columns to churches table
ALTER TABLE churches ADD COLUMN IF NOT EXISTS name TEXT;
ALTER TABLE churches ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE churches ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE churches ADD COLUMN IF NOT EXISTS denomination TEXT;
ALTER TABLE churches ADD COLUMN IF NOT EXISTS pastor_phone TEXT;
ALTER TABLE churches ADD COLUMN IF NOT EXISTS pastor_email TEXT;
ALTER TABLE churches ADD COLUMN IF NOT EXISTS church_image_url TEXT;
ALTER TABLE churches ADD COLUMN IF NOT EXISTS church_logo_url TEXT;
ALTER TABLE churches ADD COLUMN IF NOT EXISTS profile_picture_url TEXT;
ALTER TABLE churches ADD COLUMN IF NOT EXISTS services JSONB;
ALTER TABLE churches ADD COLUMN IF NOT EXISTS ministries JSONB;
ALTER TABLE churches ADD COLUMN IF NOT EXISTS member_count INTEGER DEFAULT 0;

-- Add policy for authenticated users to insert churches
DROP POLICY IF EXISTS "Authenticated users can insert churches" ON churches;
CREATE POLICY "Authenticated users can insert churches" ON churches
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');