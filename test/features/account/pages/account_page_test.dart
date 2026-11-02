import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glown_scan_mobile/features/account/pages/account_page.dart';
import 'package:glown_scan_mobile/features/account/pages/profile_page.dart';
import 'package:glown_scan_mobile/features/account/services/account_api.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  testWidgets('shows profile, change password, and log out actions', (
    tester,
  ) async {
    final api = _FakeAccountApi();
    var logoutCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccountPage(onLogout: () => logoutCalls++, accountApi: api),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(api.getProfileCalls, 0);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Change password'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);
    expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.logout_rounded), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(api.getProfileCalls, 1);
    expect(find.byType(ProfilePage), findsOneWidget);
    expect(find.text('Bèo Bảo'), findsOneWidget);
    expect(find.text('Male'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    expect(logoutCalls, 1);
  });

  testWidgets('edits profile fields and saves them through the account API', (
    tester,
  ) async {
    final api = _FakeAccountApi();
    await tester.pumpWidget(MaterialApp(home: ProfilePage(accountApi: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Full name'),
      'New name',
    );
    await tester.tap(find.text('Male'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Female').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(api.updateProfileCalls, 1);
    expect(api.updatedFullName, 'New name');
    expect(api.updatedGender, 'FEMALE');
    expect(find.text('New name'), findsOneWidget);
    expect(find.text('Female'), findsOneWidget);
  });
}

class _FakeAccountApi implements AccountApiContract {
  int getProfileCalls = 0;
  int updateProfileCalls = 0;
  String? updatedFullName;
  String? updatedGender;

  UserProfile _profile = const UserProfile(
    id: 'profile-id',
    fullName: 'Bèo Bảo',
    avatarUrl: null,
    dateOfBirth: null,
    gender: 'MALE',
  );

  @override
  Future<UserProfile> getProfile() async {
    getProfileCalls++;
    return _profile;
  }

  @override
  Future<UserProfile> updateProfile({
    required String? fullName,
    required String? dateOfBirth,
    required String? gender,
  }) async {
    updateProfileCalls++;
    updatedFullName = fullName;
    updatedGender = gender;
    _profile = UserProfile(
      id: _profile.id,
      fullName: fullName,
      avatarUrl: _profile.avatarUrl,
      dateOfBirth: dateOfBirth,
      gender: gender,
    );
    return _profile;
  }

  @override
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {}

  @override
  Future<UserProfile> uploadAvatar(XFile image) async => _profile;
}
