-- Update existing user names from usernames to full names
-- This script updates the existing users in the database to use full names instead of usernames

-- Update user with ID 32a2bdb4-a838-4c80-b328-d6900946cf5c (currently "bwalya")
UPDATE users 
SET name = 'Bwalya Musonda', updated_at = NOW()
WHERE id = '32a2bdb4-a838-4c80-b328-d6900946cf5c';

-- Update user with ID 5f23e122-d2d5-4f19-8d3a-6603e3085227 (currently "henrymusonda577")
UPDATE users 
SET name = 'Henry Musonda', updated_at = NOW()
WHERE id = '5f23e122-d2d5-4f19-8d3a-6603e3085227';

-- Note: Replace the full names above with the actual desired full names for each user
-- You can add more UPDATE statements for other existing users as needed

-- To find all users that need updating, you can run this query first:
-- SELECT id, name, email FROM users WHERE name NOT LIKE '% %' OR LENGTH(name) < 5;

-- This will show users whose names don't contain spaces (likely usernames) or are very short