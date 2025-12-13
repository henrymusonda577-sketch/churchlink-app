# Story Feature Implementation

## Overview
Implement complete story functionality including creation, viewing, and integration with home screen and profile screens.

## Tasks

### 1. Make Home Screen Stories Functional
- [ ] Update FacebookHomeScreen to fetch real stories from Firestore
- [ ] Replace hardcoded story cards with dynamic ones
- [ ] Add loading states and error handling
- [ ] Handle empty stories state

### 2. Add Story Creation Functionality
- [ ] Update CreatePostScreen to include story creation option
- [ ] Add story-specific UI (image/video picker, text input)
- [ ] Integrate with PostService.createPost for stories
- [ ] Add validation for story content

### 3. Fix Profile Screen Story Viewing
- [ ] Update FacebookProfileScreen _buildStoryCard onTap
- [ ] Navigate to StoryViewerScreen with user's stories
- [ ] Pass correct story data and initial index

### 4. Story Creation Screen (Optional)
- [ ] Create dedicated CreateStoryScreen if needed
- [ ] Add camera/gallery integration for media
- [ ] Add text overlay functionality

## Technical Details

### Firestore Integration
- Stories are stored in 'stories' collection
- Each story has: postId, userId, content, imageUrl, videoUrl, timestamp, expiresAt
- Stories expire after 23 hours

### UI Components
- StoryViewerScreen: Already implemented with progress bars, auto-advance
- FeedVideoPlayer: For video stories
- Image.network: For image stories
- Text display: For text-only stories

### Navigation Flow
- Home screen stories → StoryViewerScreen
- Profile stories → StoryViewerScreen
- Create post → Add story option → Create story

## Dependencies
- PostService: getStories(), createPost()
- StoryViewerScreen: Already exists
- Firebase Auth: For user authentication
- Cloud Firestore: For data storage
