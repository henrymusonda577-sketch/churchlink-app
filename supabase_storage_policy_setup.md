# Supabase Storage Policy Setup Guide

## Step-by-Step Instructions for Creating Storage Policies

### 1. Access Supabase Dashboard
1. Go to [supabase.com](https://supabase.com) and sign in
2. Select your project
3. Click on **Storage** in the left sidebar

### 2. Create Policies for Each Bucket

#### For the "videos" bucket:
1. Click on the **videos** bucket
2. Click on the **Policies** tab
3. Click **Create Policy**
4. Fill in the policy details:

**Policy Name:** `Allow authenticated users to videos`
**Allowed Operations:** Check all (SELECT, INSERT, UPDATE, DELETE)
**Policy Definition:**
```sql
auth.role() = 'authenticated'
```

#### For the "content_videos" bucket:
1. Click on the **content_videos** bucket
2. Click on the **Policies** tab
3. Click **Create Policy**
4. Fill in the policy details:

**Policy Name:** `Allow authenticated users to content_videos`
**Allowed Operations:** Check all (SELECT, INSERT, UPDATE, DELETE)
**Policy Definition:**
```sql
auth.role() = 'authenticated'
```

#### For the "audio" bucket:
1. Click on the **audio** bucket
2. Click on the **Policies** tab
3. Click **Create Policy**
4. Fill in the policy details:

**Policy Name:** `Allow authenticated users to audio`
**Allowed Operations:** Check all (SELECT, INSERT, UPDATE, DELETE)
**Policy Definition:**
```sql
auth.role() = 'authenticated'
```

#### For the "profile_pictures" bucket:
1. Click on the **profile_pictures** bucket
2. Click on the **Policies** tab
3. Click **Create Policy**
4. Fill in the policy details:

**Policy Name:** `Allow authenticated users to profile_pictures`
**Allowed Operations:** Check all (SELECT, INSERT, UPDATE, DELETE)
**Policy Definition:**
```sql
auth.role() = 'authenticated'
```

#### For the "chat-media" bucket:
1. Click on the **chat-media** bucket
2. Click on the **Policies** tab
3. Click **Create Policy**
4. Fill in the policy details:

**Policy Name:** `Allow authenticated users to chat-media`
**Allowed Operations:** Check all (SELECT, INSERT, UPDATE, DELETE)
**Policy Definition:**
```sql
auth.role() = 'authenticated'
```

#### For the "church-profile-pictures" bucket:
1. Click on the **church-profile-pictures** bucket
2. Click on the **Policies** tab
3. Click **Create Policy**
4. Fill in the policy details:

**Policy Name:** `Allow authenticated users to church-profile-pictures`
**Allowed Operations:** Check all (SELECT, INSERT, UPDATE, DELETE)
**Policy Definition:**
```sql
auth.role() = 'authenticated'
```

### 3. Verify the Policies
After creating policies for all buckets, you should see them listed in each bucket's Policies tab.

### 4. Test the Fix
1. Go back to your Flutter app
2. Try uploading a video
3. The "new row violates row-level security policy" error should be resolved

## Alternative: Quick Test (Temporary - Not for Production)

If you want to quickly test if this fixes the issue:

1. For the **videos** bucket only, create a policy with:
   - **Policy Definition:** `true` (this allows everyone - remove this after testing!)

**⚠️ WARNING:** Using `true` allows anyone to access your storage. This is only for testing!

## Troubleshooting

If you still get errors after setting up policies:

1. Make sure you're logged in as an authenticated user in your app
2. Check that the bucket names match exactly ('videos', 'content_videos', etc.)
3. Verify the policies are active (green status in the dashboard)

## Security Note

The policies above allow all authenticated users to upload and view files. For production, you might want to restrict this further:

- Only allow users to see their own files: `auth.uid() = user_id`
- Only allow specific roles: `auth.jwt() ->> 'role' = 'admin'`

But for your current video upload issue, allowing all authenticated users should work.