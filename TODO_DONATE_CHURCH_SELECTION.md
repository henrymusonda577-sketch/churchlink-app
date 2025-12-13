# TODO: Implement Church Selection in Donation Screen

## Tasks
- [ ] Import ChurchService in donate_screen.dart
- [ ] Add state variables for church data (userChurchId, userChurchName, availableChurches, selectedChurchId, isLoadingChurches)
- [ ] Add method to load user's church membership from Firestore
- [ ] Add method to load all available churches
- [ ] Modify _buildGiveTab to show church selection UI when "Church" purpose is selected
- [ ] Create _buildChurchSelectionWidget method for church selection interface
- [ ] Update donation processing to include selected church name in purpose/message
- [ ] Handle loading states and error cases
- [ ] Test the implementation

## Files to Edit
- flutter_projects/my_flutter_app/lib/donate_screen.dart
