-- Create church-profile-pictures storage bucket
INSERT INTO storage.buckets (id, name, public)
VALUES ('church-profile-pictures', 'church-profile-pictures', true)
ON CONFLICT (id) DO NOTHING;

-- Create policy for church-profile-pictures bucket
-- Allow authenticated users to upload, view, and manage church profile pictures
CREATE POLICY "Allow authenticated users to church-profile-pictures" ON storage.objects
FOR ALL USING (
  bucket_id = 'church-profile-pictures'
  AND auth.role() = 'authenticated'
)
WITH CHECK (
  bucket_id = 'church-profile-pictures'
  AND auth.role() = 'authenticated'
);

-- Make the bucket publicly readable for church profile pictures
CREATE POLICY "Public read access for church-profile-pictures" ON storage.objects
FOR SELECT USING (bucket_id = 'church-profile-pictures');