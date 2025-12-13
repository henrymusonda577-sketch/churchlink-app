# Status Post Expiration Implementation

## Task: Update status posts to expire after 23 hours

### Status: ✅ COMPLETED

### Changes Made:
- [x] Updated `post_service.dart` to change story expiration from 24 hours to 23 hours
- [x] Modified `storyExpiresAt` field in posts collection creation
- [x] Modified `expiresAt` field in stories collection creation
- [x] Both fields now use `Duration(hours: 23)` instead of `Duration(hours: 24)`

### Files Modified:
- `flutter_projects/my_flutter_app/lib/services/post_service.dart`

### Implementation Details:
- Status posts (stories) now expire after exactly 23 hours from creation
- The existing filtering logic in `getStories()` and `getUserStories()` methods automatically hides expired stories
- Blue border indicator for status posts was already implemented in `facebook_home_screen.dart`

### Technical Details:
- Stories are stored in both 'posts' and 'stories' collections
- `storyExpiresAt` field tracks expiration in the posts collection
- `expiresAt` field tracks expiration in the stories collection
- Both collections use Firestore Timestamp for precise expiration tracking
- Real-time queries filter out expired stories using `where('expiresAt', isGreaterThan: now)`

### Testing:
- New status posts will expire after 23 hours
- Existing filtering logic ensures expired posts are not displayed
- Blue border visual indicator is already working for active status posts

### Notes:
- The blue border feature for status posts was already implemented
- Only the expiration duration needed to be changed from 24 to 23 hours
- No UI changes were required as the existing implementation handles expiration automatically
