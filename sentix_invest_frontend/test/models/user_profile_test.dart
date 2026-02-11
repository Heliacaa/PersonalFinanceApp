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
  });
}
