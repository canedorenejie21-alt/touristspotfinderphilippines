import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tourist_spot_finder_ph_smooth/main.dart';

class FakeApiClient extends ApiClient {
  FakeApiClient({this.failLogin = false});

  final bool failLogin;
  String registeredName = 'Test Traveler';

  @override
  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    if (failLogin) {
      throw const ApiException('Invalid email or password', 401);
    }
    return AppUser(
      id: 1,
      fullName: 'Test Traveler',
      email: email,
      isAdmin: true,
    );
  }

  @override
  Future<bool> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    registeredName = fullName;
    return false;
  }

  @override
  Future<AppUser> verifyEmail({
    required String email,
    required String code,
  }) async {
    return AppUser(
      id: 1,
      fullName: registeredName,
      email: email,
      isAdmin: true,
    );
  }

  @override
  Future<void> resendVerification({required String email}) async {}

  @override
  Future<AppUser> loginWithGoogle(String idToken) async {
    return AppUser(
      id: 2,
      fullName: 'Google Traveler',
      email: 'google@example.com',
      isAdmin: false,
    );
  }

  @override
  Future<List<TouristSpot>> fetchSpots({
    String q = '',
    String category = '',
  }) async => fallbackSpots;

  @override
  Future<List<TravelPost>> fetchPosts() async => fallbackPosts;

  @override
  Future<TravelPost> createPost(String body) async {
    return TravelPost('Traveler Update', body, authorName: 'Test Traveler');
  }

  @override
  Future<AppUser> updateProfileName(String fullName) async {
    return AppUser(
      id: 1,
      fullName: fullName,
      email: 'test@example.com',
      isAdmin: true,
    );
  }
}

void main() {
  testWidgets('shows login before the home screen', (tester) async {
    await tester.pumpWidget(const TouristSpotFinderApp());

    expect(find.text('Tourist Spot Finder'), findsOneWidget);
    expect(find.text('Login'), findsNWidgets(2));
    expect(find.text('Explore The Philippines'), findsNothing);
  });

  testWidgets('logs in and shows the Tourist Spot Finder home screen', (
    tester,
  ) async {
    await tester.pumpWidget(TouristSpotFinderApp(api: FakeApiClient()));
    final email =
        'logincheck${DateTime.now().microsecondsSinceEpoch}@example.com';

    await tester.ensureVisible(find.text('No account yet? Register'));
    await tester.tap(find.text('No account yet? Register'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Login Check');
    await tester.enterText(find.byType(TextField).at(1), email);
    await tester.enterText(find.byType(TextField).at(2), 'password123');
    await tester.tap(find.text('Register').last);
    await tester.pumpAndSettle();

    expect(find.text('Explore The Philippines'), findsOneWidget);
    expect(find.text('Start Exploring'), findsOneWidget);
    expect(find.text('Pin Locations'), findsOneWidget);
  });

  testWidgets('invalid backend login stays on the login screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      TouristSpotFinderApp(api: FakeApiClient(failLogin: true)),
    );

    await tester.enterText(
      find.byType(TextField).at(0),
      'notregistered${DateTime.now().microsecondsSinceEpoch}@example.com',
    );
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(find.text('Login').last);
    await tester.pumpAndSettle();

    expect(find.text('Explore The Philippines'), findsNothing);
    expect(find.text('Login'), findsWidgets);
  });

  testWidgets('registers then navigates to community and creates a post', (
    tester,
  ) async {
    await tester.pumpWidget(TouristSpotFinderApp(api: FakeApiClient()));
    final email =
        'community${DateTime.now().microsecondsSinceEpoch}@example.com';

    await tester.ensureVisible(find.text('No account yet? Register'));
    await tester.tap(find.text('No account yet? Register'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Renejay Explorer');
    await tester.enterText(find.byType(TextField).at(1), email);
    await tester.enterText(find.byType(TextField).at(2), 'password123');
    await tester.tap(find.text('Register').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Community'));
    await tester.pumpAndSettle();

    expect(find.text('Share Your Travel'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Share your experience...'),
      'Loved the cold breeze in Baguio.',
    );
    await tester.tap(find.text('Post'));
    await tester.pumpAndSettle();

    expect(find.text('Loved the cold breeze in Baguio.'), findsOneWidget);
  });
}
