import 'package:flutter_test/flutter_test.dart';
import 'package:sentix_invest_frontend/core/models/user_profile.dart';

void main() {
  group('UserProfile', () {
    test('fromJson parses all fields correctly', () {
      final json = {
        'id': 'user-123',
        'email': 'test@example.com',
        'fullName': 'Test User',
        'role': 'USER',
        'balance': 5000.50,
        'paperBalance': 100000.0,
        'isPaperTrading': false,
        'preferredCurrency': 'USD',
        'fcmToken': 'token-abc',
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.id, 'user-123');
      expect(profile.email, 'test@example.com');
      expect(profile.fullName, 'Test User');
      expect(profile.role, 'USER');
      expect(profile.balance, 5000.50);
      expect(profile.paperBalance, 100000.0);
      expect(profile.isPaperTrading, false);
      expect(profile.preferredCurrency, 'USD');
      expect(profile.fcmToken, 'token-abc');
    });

    test('activeBalance returns real balance when not paper trading', () {
      final profile = UserProfile(
        id: '1',
        email: 'a@b.com',
        fullName: 'Test',
        role: 'USER',
        balance: 5000.0,
        paperBalance: 100000.0,
        isPaperTrading: false,
        preferredCurrency: 'USD',
      );

      expect(profile.activeBalance, 5000.0);
    });

    test('activeBalance returns paper balance when paper trading', () {
      final profile = UserProfile(
        id: '1',
        email: 'a@b.com',
        fullName: 'Test',
        role: 'USER',
        balance: 5000.0,
        paperBalance: 100000.0,
        isPaperTrading: true,
        preferredCurrency: 'USD',
      );

      expect(profile.activeBalance, 100000.0);
    });

    test('fromJson handles missing optional fields with defaults', () {
      final json = <String, dynamic>{};

      final profile = UserProfile.fromJson(json);

      expect(profile.id, '');
      expect(profile.email, '');
      expect(profile.fullName, '');
      expect(profile.role, 'USER');
      expect(profile.balance, 0.0);
      expect(profile.paperBalance, 100000.0);
      expect(profile.isPaperTrading, false);
      expect(profile.preferredCurrency, 'USD');
      expect(profile.fcmToken, isNull);
    });

    test('fromJson handles integer balance values', () {
      final json = {
        'id': '1',
        'email': 'a@b.com',
        'fullName': 'Test',
        'balance': 5000,
        'paperBalance': 100000,
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.balance, 5000.0);
      expect(profile.paperBalance, 100000.0);
    });

    test('fromJson handles null fcmToken', () {
      final json = {
        'id': '1',
        'email': 'a@b.com',
        'fullName': 'Test',
        'fcmToken': null,
      };

      final profile = UserProfile.fromJson(json);
      expect(profile.fcmToken, isNull);
    });

    test('fromJson parses toggle paper trading response (no id field)', () {
      // The PATCH /users/paper-trading endpoint returns a UserResponse
      // which may not include 'id' — verify defaults work correctly.
      final json = {
        'fullName': 'Test User',
        'email': 'test@example.com',
        'balance': 5000.50,
        'paperBalance': 100000.0,
        'isPaperTrading': true,
        'preferredCurrency': 'USD',
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.fullName, 'Test User');
      expect(profile.email, 'test@example.com');
      expect(profile.balance, 5000.50);
      expect(profile.paperBalance, 100000.0);
      expect(profile.isPaperTrading, true);
      expect(profile.preferredCurrency, 'USD');
      expect(profile.id, ''); // defaults to empty string
      expect(profile.activeBalance, 100000.0); // paper balance when paper trading
    });

    test('fromJson toggle response with null balance defaults correctly', () {
      final json = {
        'fullName': 'Test User',
        'email': 'test@example.com',
        'balance': null,
        'paperBalance': 100000.0,
        'isPaperTrading': true,
        'preferredCurrency': 'USD',
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.balance, 0.0);
      expect(profile.paperBalance, 100000.0);
      expect(profile.isPaperTrading, true);
      expect(profile.activeBalance, 100000.0);
    });

    test('activeBalance switches correctly after toggle', () {
      // Simulate toggling from paper=false to paper=true
      final beforeToggle = UserProfile(
        id: '1',
        email: 'a@b.com',
        fullName: 'Test',
        role: 'USER',
        balance: 5000.0,
        paperBalance: 100000.0,
        isPaperTrading: false,
        preferredCurrency: 'USD',
      );
      expect(beforeToggle.activeBalance, 5000.0);

      // After toggle, backend returns isPaperTrading=true
      final afterToggle = UserProfile(
        id: '1',
        email: 'a@b.com',
        fullName: 'Test',
        role: 'USER',
        balance: 5000.0,
        paperBalance: 100000.0,
        isPaperTrading: true,
        preferredCurrency: 'USD',
      );
      expect(afterToggle.activeBalance, 100000.0);
    });
  });
}
