-- Fix the users table ID to match the auth user ID
-- First, delete the incorrect user record
DELETE FROM users WHERE id = 'acdaec9c-6d09-45f5-9c02-ce340f9c1220';

-- Then update the church pastor_id to use the correct auth ID
UPDATE churches
SET pastor_id = '5f23e122-d2d5-4f19-8d3a-6603e3085227'::uuid
WHERE pastor_id = 'acdaec9c-6d09-45f5-9c02-ce340f9c1220'::uuid;

-- Insert the correct user record with auth ID
INSERT INTO users (
  id,
  name,
  email,
  role,
  church_id,
  position_in_church,
  church_name,
  created_at,
  updated_at
) VALUES (
  '5f23e122-d2d5-4f19-8d3a-6603e3085227'::uuid,
  'henrymusonda577',
  'henrymusonda577@gmail.com',
  'pastor',
  '550e8400-e29b-41d4-a716-446655440000'::uuid,
  'Pastor',
  'Test Church',
  NOW(),
  NOW()
) ON CONFLICT (id) DO UPDATE SET
  role = EXCLUDED.role,
  church_id = EXCLUDED.church_id,
  position_in_church = EXCLUDED.position_in_church,
  church_name = EXCLUDED.church_name,
  updated_at = NOW();