-- Fix church pastor_id to match the users table ID
UPDATE churches
SET pastor_id = 'acdaec9c-6d09-45f5-9c02-ce340f9c1220'::uuid
WHERE pastor_id = '5f23e122-d2d5-4f19-8d3a-6603e3085227'::uuid;