# TODO: Implement Live Feature for Pastors

## Plan Summary
Implement logic for the "Live" feature so that it is only visible and functional when a user is signed in as a pastor. When the pastor taps the Live button, prompt them to choose between streaming to everyone or only to their church members. If streaming to church members, trigger notifications to all church members.

## Steps to Complete

### Step 1: Add Role Check Method in UserService
- [x] Add a method `isUserPastor()` in `lib/services/user_service.dart` to check if the current user's role is 'pastor'.

### Step 2: Add Live Button to Pastor Dashboard
- [x] Modify `lib/pastor_dashboard.dart` to check the user's role and show the Live button only if they are a pastor.
- [x] Add the Live button in the Overview tab or as a floating action button.

### Step 3: Implement Streaming Options Dialog
- [x] Create a dialog in `lib/pastor_dashboard.dart` that appears when the Live button is tapped, with options for "Stream to everyone" and "Stream to church members".

### Step 4: Add Notification Method for Multiple Users
- [x] Add a method `sendNotificationToUsers()` in `lib/services/notification_service.dart` to send notifications to a list of user IDs.

### Step 5: Trigger Notifications for Church Members
- [x] In `lib/pastor_dashboard.dart`, when "Stream to church members" is selected, get the list of church members using `church_service.dart` and send notifications using the new notification method.

### Step 6: Handle Navigation to Stream Screen
- [x] Add logic to navigate to a stream screen (create if necessary) when the pastor selects a streaming option.

### Step 7: Testing and Error Handling
- [x] Test the role-based visibility and functionality.
- [x] Verify notifications are sent correctly.
- [x] Add error handling for cases like no church members or notification failures.

## Files to Edit
- `lib/services/user_service.dart`
- `lib/pastor_dashboard.dart`
- `lib/services/notification_service.dart`
- `lib/services/church_service.dart` (use existing methods)

## Status
- [x] Step 1: Completed
- [x] Step 2: Completed
- [x] Step 3: Completed
- [x] Step 4: Completed
- [x] Step 5: Completed
- [x] Step 6: Completed
- [x] Step 7: Completed
