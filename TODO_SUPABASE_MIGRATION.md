# Supabase Migration TODO

## Setup Phase
- [ ] Set up Supabase project and get API keys (URL and anon key)
- [ ] Create Supabase configuration file (lib/config/supabase_config.dart)
- [ ] Initialize Supabase client in main.dart
- [ ] Remove Firebase initialization from main.dart

## Authentication Migration
- [ ] Update sign_in.dart to use Supabase Auth instead of Firebase Auth
- [ ] Update user_service.dart to use Supabase Auth
- [ ] Update all authentication-related code across the app
- [ ] Handle user session management with Supabase

## Database Migration
- [ ] Create Supabase database schema (tables for users, posts, donations, churches, etc.)
- [ ] Update donation_service.dart to use Supabase database instead of Firestore
- [ ] Update post_service.dart to use Supabase
- [ ] Update church_service.dart to use Supabase
- [ ] Update firebase_chat_service.dart to use Supabase (rename to supabase_chat_service.dart)
- [ ] Update prayer_service.dart to use Supabase
- [ ] Update gospel_songs_service.dart to use Supabase
- [ ] Update reading_plan_service.dart to use Supabase
- [ ] Update bible_service.dart to use Supabase
- [ ] Update all other services using Firestore

## Storage Migration
- [ ] Update video_firebase_service.dart to use Supabase Storage (rename to video_supabase_service.dart)
- [ ] Update audio_firebase_service.dart to use Supabase Storage
- [ ] Update any other storage operations

## Real-time Features
- [ ] Implement real-time subscriptions for chat using Supabase
- [ ] Implement real-time subscriptions for posts
- [ ] Implement real-time subscriptions for notifications

## Configuration Updates
- [ ] Remove Firebase dependencies from pubspec.yaml
- [ ] Remove google-services.json from android/app
- [ ] Update Android build.gradle.kts to remove Firebase
- [ ] Update iOS configuration if needed
- [ ] Add Supabase configuration to build files

## Testing and Cleanup
- [ ] Test authentication flow
- [ ] Test donation functionality
- [ ] Test chat functionality
- [ ] Test video/audio upload
- [ ] Test all database operations
- [ ] Remove unused Firebase code
- [ ] Update any remaining Firebase references
