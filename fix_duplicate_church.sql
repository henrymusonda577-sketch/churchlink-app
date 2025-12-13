-- Check what churches exist for this pastor
SELECT id, pastor_id, church_name, created_at FROM churches WHERE pastor_id = '5f23e122-d2d5-4f19-8d3a-6603e3085227'::uuid ORDER BY created_at DESC;

-- Delete all churches for this pastor except the most recent one
DELETE FROM churches
WHERE pastor_id = '5f23e122-d2d5-4f19-8d3a-6603e3085227'::uuid
AND id NOT IN (
  SELECT id FROM churches
  WHERE pastor_id = '5f23e122-d2d5-4f19-8d3a-6603e3085227'::uuid
  ORDER BY created_at DESC
  LIMIT 1
);

-- Verify only one church remains
SELECT id, pastor_id, church_name FROM churches WHERE pastor_id = '5f23e122-d2d5-4f19-8d3a-6603e3085227'::uuid;