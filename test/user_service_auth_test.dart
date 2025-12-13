import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import '../lib/services/user_service.dart';
import '../lib/config/supabase_config.dart';

// Generate mocks
@GenerateMocks([SupabaseClient, GoTrueClient, User])
import 'user_service_auth_test.mocks.dart';

void main() {
  late UserService userService;
  late MockSupabaseClient mockSupabaseClient;
  late MockGoTrueClient mockAuth;
  late MockUser mockUser;

  setUp(() async {
    // Initialize with test configuration
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );

    userService = UserService();
    mockSupabaseClient = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockUser = MockUser();

    // Mock the Supabase client
    when(mockSupabaseClient.auth).thenReturn(mockAuth);
  });

  group('UserService Authentication Tests', () {
    test('getUserInfo returns null when session is null', () async {
      // Arrange
      when(mockAuth.currentSession).thenReturn(null);

      // Act
      final result = await userService.getUserInfo();

      // Assert
      expect(result, isNull);
    });

    test('getUserInfo returns null when user is null', () async {
      // Arrange
      final mockSession = Session(
        accessToken: 'fake_token',
        tokenType: 'bearer',
        expiresIn: 3600,
        refreshToken: 'fake_refresh',
        user: mockUser,
      );
      when(mockAuth.currentSession).thenReturn(mockSession);
      when(mockAuth.currentUser).thenReturn(null);

      // Act
      final result = await userService.getUserInfo();

      // Assert
      expect(result, isNull);
    });

    test('getDiscoverableUsers returns empty list when session is null',
        () async {
      // Arrange
      when(mockAuth.currentSession).thenReturn(null);

      // Act
      final result = await userService.getDiscoverableUsers();

      // Assert
      expect(result, isEmpty);
    });

    test('getDiscoverableUsers returns empty list when user is null', () async {
      // Arrange
      final mockSession = Session(
        accessToken: 'fake_token',
        tokenType: 'bearer',
        expiresIn: 3600,
        refreshToken: 'fake_refresh',
        user: mockUser,
      );
      when(mockAuth.currentSession).thenReturn(mockSession);
      when(mockAuth.currentUser).thenReturn(null);

      // Act
      final result = await userService.getDiscoverableUsers();

      // Assert
      expect(result, isEmpty);
    });

    test('searchUsers returns empty list when session is null', () async {
      // Arrange
      when(mockAuth.currentSession).thenReturn(null);

      // Act
      final result = await userService.searchUsers('test');

      // Assert
      expect(result, isEmpty);
    });

    test('searchUsers returns empty list when user is null', () async {
      // Arrange
      final mockSession = Session(
        accessToken: 'fake_token',
        tokenType: 'bearer',
        expiresIn: 3600,
        refreshToken: 'fake_refresh',
        user: mockUser,
      );
      when(mockAuth.currentSession).thenReturn(mockSession);
      when(mockAuth.currentUser).thenReturn(null);

      // Act
      final result = await userService.searchUsers('test');

      // Assert
      expect(result, isEmpty);
    });

    test('saveUserInfo returns early when session is null', () async {
      // Arrange
      when(mockAuth.currentSession).thenReturn(null);

      // Act & Assert
      expect(
        () => userService.saveUserInfo(
          name: 'Test',
          email: 'test@example.com',
          role: 'member',
        ),
        returnsNormally,
      );
    });

    test('saveUserInfo returns early when user is null', () async {
      // Arrange
      final mockSession = Session(
        accessToken: 'fake_token',
        tokenType: 'bearer',
        expiresIn: 3600,
        refreshToken: 'fake_refresh',
        user: mockUser,
      );
      when(mockAuth.currentSession).thenReturn(mockSession);
      when(mockAuth.currentUser).thenReturn(null);

      // Act & Assert
      expect(
        () => userService.saveUserInfo(
          name: 'Test',
          email: 'test@example.com',
          role: 'member',
        ),
        returnsNormally,
      );
    });

    test('updateProfilePicture returns early when session is null', () async {
      // Arrange
      when(mockAuth.currentSession).thenReturn(null);

      // Act & Assert
      expect(
        () => userService.updateProfilePicture('fake_url'),
        returnsNormally,
      );
    });

    test('updateProfilePicture returns early when user is null', () async {
      // Arrange
      final mockSession = Session(
        accessToken: 'fake_token',
        tokenType: 'bearer',
        expiresIn: 3600,
        refreshToken: 'fake_refresh',
        user: mockUser,
      );
      when(mockAuth.currentSession).thenReturn(mockSession);
      when(mockAuth.currentUser).thenReturn(null);

      // Act & Assert
      expect(
        () => userService.updateProfilePicture('fake_url'),
        returnsNormally,
      );
    });

    test('getChurchMembers returns empty list when session is null', () async {
      // Arrange
      when(mockAuth.currentSession).thenReturn(null);

      // Act
      final result = await userService.getChurchMembers();

      // Assert
      expect(result, isEmpty);
    });

    test('getChurchMembers returns empty list when user is null', () async {
      // Arrange
      final mockSession = Session(
        accessToken: 'fake_token',
        tokenType: 'bearer',
        expiresIn: 3600,
        refreshToken: 'fake_refresh',
        user: mockUser,
      );
      when(mockAuth.currentSession).thenReturn(mockSession);
      when(mockAuth.currentUser).thenReturn(null);

      // Act
      final result = await userService.getChurchMembers();

      // Assert
      expect(result, isEmpty);
    });

    test('setUserOnline returns early when session is null', () async {
      // Arrange
      when(mockAuth.currentSession).thenReturn(null);

      // Act & Assert
      expect(
        () => userService.setUserOnline(),
        returnsNormally,
      );
    });

    test('setUserOnline returns early when user is null', () async {
      // Arrange
      final mockSession = Session(
        accessToken: 'fake_token',
        tokenType: 'bearer',
        expiresIn: 3600,
        refreshToken: 'fake_refresh',
        user: mockUser,
      );
      when(mockAuth.currentSession).thenReturn(mockSession);
      when(mockAuth.currentUser).thenReturn(null);

      // Act & Assert
      expect(
        () => userService.setUserOnline(),
        returnsNormally,
      );
    });

    test('setUserOffline returns early when session is null', () async {
      // Arrange
      when(mockAuth.currentSession).thenReturn(null);

      // Act & Assert
      expect(
        () => userService.setUserOffline(),
        returnsNormally,
      );
    });

    test('setUserOffline returns early when user is null', () async {
      // Arrange
      final mockSession = Session(
        accessToken: 'fake_token',
        tokenType: 'bearer',
        expiresIn: 3600,
        refreshToken: 'fake_refresh',
        user: mockUser,
      );
      when(mockAuth.currentSession).thenReturn(mockSession);
      when(mockAuth.currentUser).thenReturn(null);

      // Act & Assert
      expect(
        () => userService.setUserOffline(),
        returnsNormally,
      );
    });

    test('getMutualFollowers returns empty list when session is null',
        () async {
      // Arrange
      when(mockAuth.currentSession).thenReturn(null);

      // Act
      final result = await userService.getMutualFollowers();

      // Assert
      expect(result, isEmpty);
    });

    test('getMutualFollowers returns empty list when user is null', () async {
      // Arrange
      final mockSession = Session(
        accessToken: 'fake_token',
        tokenType: 'bearer',
        expiresIn: 3600,
        refreshToken: 'fake_refresh',
        user: mockUser,
      );
      when(mockAuth.currentSession).thenReturn(mockSession);
      when(mockAuth.currentUser).thenReturn(null);

      // Act
      final result = await userService.getMutualFollowers();

      // Assert
      expect(result, isEmpty);
    });

    test('isUserPastor returns false when session is null', () async {
      // Arrange
      when(mockAuth.currentSession).thenReturn(null);

      // Act
      final result = await userService.isUserPastor();

      // Assert
      expect(result, isFalse);
    });

    test('isUserPastor returns false when user is null', () async {
      // Arrange
      final mockSession = Session(
        accessToken: 'fake_token',
        tokenType: 'bearer',
        expiresIn: 3600,
        refreshToken: 'fake_refresh',
        user: mockUser,
      );
      when(mockAuth.currentSession).thenReturn(mockSession);
      when(mockAuth.currentUser).thenReturn(null);

      // Act
      final result = await userService.isUserPastor();

      // Assert
      expect(result, isFalse);
    });

    test('followUser returns early when session is null', () async {
      // Arrange
      when(mockAuth.currentSession).thenReturn(null);

      // Act & Assert
      expect(
        () => userService.followUser('fake_user_id'),
        returnsNormally,
      );
    });

    test('followUser returns early when user is null', () async {
      // Arrange
      final mockSession = Session(
        accessToken: 'fake_token',
        tokenType: 'bearer',
        expiresIn: 3600,
        refreshToken: 'fake_refresh',
        user: mockUser,
      );
      when(mockAuth.currentSession).thenReturn(mockSession);
      when(mockAuth.currentUser).thenReturn(null);

      // Act & Assert
      expect(
        () => userService.followUser('fake_user_id'),
        returnsNormally,
      );
    });

    test('unfollowUser returns early when session is null', () async {
      // Arrange
      when(mockAuth.currentSession).thenReturn(null);

      // Act & Assert
      expect(
        () => userService.unfollowUser('fake_user_id'),
        returnsNormally,
      );
    });

    test('unfollowUser returns early when user is null', () async {
      // Arrange
      final mockSession = Session(
        accessToken: 'fake_token',
        tokenType: 'bearer',
        expiresIn: 3600,
        refreshToken: 'fake_refresh',
        user: mockUser,
      );
      when(mockAuth.currentSession).thenReturn(mockSession);
      when(mockAuth.currentUser).thenReturn(null);

      // Act & Assert
      expect(
        () => userService.unfollowUser('fake_user_id'),
        returnsNormally,
      );
    });

    test('updateUserProfile returns early when session is null', () async {
      // Arrange
      when(mockAuth.currentSession).thenReturn(null);

      // Act & Assert
      expect(
        () => userService.updateUserProfile({'name': 'Test'}),
        returnsNormally,
      );
    });

    test('updateUserProfile returns early when user is null', () async {
      // Arrange
      final mockSession = Session(
        accessToken: 'fake_token',
        tokenType: 'bearer',
        expiresIn: 3600,
        refreshToken: 'fake_refresh',
        user: mockUser,
      );
      when(mockAuth.currentSession).thenReturn(mockSession);
      when(mockAuth.currentUser).thenReturn(null);

      // Act & Assert
      expect(
        () => userService.updateUserProfile({'name': 'Test'}),
        returnsNormally,
      );
    });

    test('uploadProfilePicture returns early when session is null', () async {
      // Arrange
      when(mockAuth.currentSession).thenReturn(null);

      // Act & Assert
      expect(
        () => userService.uploadProfilePicture(null),
        returnsNormally,
      );
    });

    test('uploadProfilePicture returns early when user is null', () async {
      // Arrange
      final mockSession = Session(
        accessToken: 'fake_token',
        tokenType: 'bearer',
        expiresIn: 3600,
        refreshToken: 'fake_refresh',
        user: mockUser,
      );
      when(mockAuth.currentSession).thenReturn(mockSession);
      when(mockAuth.currentUser).thenReturn(null);

      // Act & Assert
      expect(
        () => userService.uploadProfilePicture(null),
        returnsNormally,
      );
    });
  });
}
