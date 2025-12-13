-- Add policy for pastors to update their own churches
DROP POLICY IF EXISTS "Pastors can update their own churches" ON churches;
CREATE POLICY "Pastors can update their own churches" ON churches
  FOR UPDATE USING (auth.uid() = pastor_id);