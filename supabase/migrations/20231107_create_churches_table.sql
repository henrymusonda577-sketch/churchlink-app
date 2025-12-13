-- Add missing columns to churches table (assuming it exists)
ALTER TABLE churches ADD COLUMN IF NOT EXISTS church_name TEXT;
ALTER TABLE churches ADD COLUMN IF NOT EXISTS location TEXT;
ALTER TABLE churches ADD COLUMN IF NOT EXISTS address TEXT;
ALTER TABLE churches ADD COLUMN IF NOT EXISTS pastor_id UUID REFERENCES auth.users(id);
ALTER TABLE churches ADD COLUMN IF NOT EXISTS pastor_name TEXT;
ALTER TABLE churches ADD COLUMN IF NOT EXISTS contact_email TEXT;
ALTER TABLE churches ADD COLUMN IF NOT EXISTS contact_phone TEXT;
ALTER TABLE churches ADD COLUMN IF NOT EXISTS website TEXT;
ALTER TABLE churches ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE churches ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
ALTER TABLE churches ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Create index on church_name if not exists
CREATE INDEX IF NOT EXISTS churches_church_name_idx ON churches(church_name);

-- Enable RLS if not already
ALTER TABLE churches ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist and recreate
DROP POLICY IF EXISTS "Authenticated users can read churches" ON churches;
DROP POLICY IF EXISTS "Service role can manage churches" ON churches;

-- Create policy for authenticated users to read churches
CREATE POLICY "Authenticated users can read churches" ON churches
  FOR SELECT USING (auth.role() = 'authenticated');

-- Create policy for service role to manage churches
CREATE POLICY "Service role can manage churches" ON churches
  FOR ALL USING (auth.role() = 'service_role');