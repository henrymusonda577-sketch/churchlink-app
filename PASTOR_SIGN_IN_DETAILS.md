# What Happens When You Sign In as a Pastor

## Complete Sign-In Process

### 1. Role Selection
- During sign-up/sign-in, you select "Pastor" from the role dropdown menu
- Available roles include: Pastor, Member, Visitor, Deacon, Youth Leader, Choir Member

### 2. Authentication Process
- Firebase Authentication creates or verifies your user account
- Email and password authentication is used
- All standard Firebase Auth error handling is in place (weak password, email already in use, etc.)

### 3. User Data Storage
Your profile information is saved to Firestore with the following details:
- **Name**: Your full name
- **Phone**: Your phone number
- **Email**: Your email address
- **Role**: Set to "Pastor"
- **Profile Picture**: URL if uploaded during sign-up
- **Bio**: Optional biographical information
- **Timestamps**: Creation date and last login time
- **Statistics**: Followers, following, posts counts (initialized to 0)

### 4. Church Association Check
The app automatically checks if you have an existing church using:
```dart
ChurchService.getChurchByPastorId(userCredential.user!.uid)
```
- This queries Firestore for churches where the `pastorId` matches your user ID
- Returns church data if you already have a church, or `null` if you don't

### 5. Navigation
You are directed to the `PastorDashboard` screen regardless of whether you have a church or not:
- If you have a church: You go to the dashboard to manage your existing church
- If you don't have a church: You go to the dashboard to create a new church

## Pastor-Specific Features Available

### Church Management (via ChurchService)
- **Create Church**: Complete church creation with detailed information
- **Update Church**: Modify church details and information
- **Image Management**: Upload church images and logos to Firebase Storage
- **Member Management**: View, add, and remove church members
- **Visitor Management**: Handle visitor registrations and track visitors
- **Invitations**: Send invitations to visitors to become members
- **Notifications**: Receive notifications about new visitors and church activities
- **Analytics**: Access church statistics and member counts

### User Management (via UserService)
- **New User Notifications**: All pastors are automatically notified when new users join the app
- **User Discovery**: Access to browse all users for potential church invitations
- **Role-based Filtering**: Filter users by specific roles (Pastor, Member, etc.)

### Current Pastor Dashboard Status
The PastorDashboard is currently a placeholder screen that shows:
- Welcome message with your name
- Church icon and basic information
- Message indicating that church management tools are "coming soon"
- Suggestion to use the Home screen for current features

## Technical Implementation Details

### Database Structure
- **Users Collection**: Stores all user profiles with role information
- **Churches Collection**: Stores church data with pastor association
- **Follows Collection**: Tracks user following relationships
- **Notifications Collection**: Stores system notifications
- **Invitations Collection**: Manages church invitation requests

### Services Used
- **ChurchService**: Comprehensive church management functionality
- **UserService**: User data management and pastor notifications
- **NotificationService**: Handles push notifications and alerts

### Firebase Integration
- **Firebase Auth**: User authentication
- **Firebase Firestore**: Data persistence
- **Firebase Storage**: Image and file storage
- **Cloud Functions**: Potential for backend logic (not yet implemented)

## Next Steps for Development
The foundation is solid, but the pastor-specific features need UI implementation:
1. Enhanced PastorDashboard with actual management tools
2. Church creation and editing interfaces
3. Member and visitor management screens
4. Notification center for pastors
5. Analytics and reporting features
6. Church content management (sermons, events, etc.)
