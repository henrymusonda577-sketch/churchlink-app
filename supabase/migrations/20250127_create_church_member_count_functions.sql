-- Create RPC functions for managing church member counts

-- Function to increment church member count
CREATE OR REPLACE FUNCTION increment_church_members(church_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE churches
  SET member_count = member_count + 1,
      updated_at = NOW()
  WHERE id = church_id;
END;
$$;

-- Function to decrement church member count
CREATE OR REPLACE FUNCTION decrement_church_members(church_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE churches
  SET member_count = GREATEST(member_count - 1, 0),
      updated_at = NOW()
  WHERE id = church_id;
END;
$$;

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION increment_church_members(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION decrement_church_members(UUID) TO authenticated;