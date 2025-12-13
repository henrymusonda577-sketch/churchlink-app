-- Fix pastor user data to show dashboard and church icons
-- Update the user with email henrymusonda577@gmail.com to have pastor role

-- First, create the church if it doesn't exist
INSERT INTO churches (
  id,
  name,
  church_name,
  location,
  pastor_id,
  pastor_name,
  contact_email,
  created_at,
  updated_at
) VALUES (
  '550e8400-e29b-41d4-a716-446655440000'::uuid,
  'Test Church',
  'Test Church',  -- Replace with actual church name
  'Test Location',
  '5f23e122-d2d5-4f19-8d3a-6603e3085227'::uuid,  -- Auth user ID
  'Henry Musonda',
  'henrymusonda577@gmail.com',
  NOW(),
  NOW()
) ON CONFLICT (id) DO NOTHING;

-- Then update the user in the users table
UPDATE users
SET
  role = 'pastor',
  position_in_church = 'Pastor',
  church_id = '550e8400-e29b-41d4-a716-446655440000'::uuid,
  updated_at = NOW()
WHERE email = 'henrymusonda577@gmail.com';