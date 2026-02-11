class UserProfile {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final double balance;
  final double paperBalance;
  final bool isPaperTrading;
  final String preferredCurrency;
  final String? fcmToken;

  UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.balance,
    required this.paperBalance,
    required this.isPaperTrading,
    required this.preferredCurrency,
    this.fcmToken,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      fullName: json['fullName'] ?? '',
      role: json['role'] ?? 'USER',
      balance: (json['balance'] ?? 0).toDouble(),
      paperBalance: (json['paperBalance'] ?? 100000).toDouble(),
      isPaperTrading: json['isPaperTrading'] ?? false,
      preferredCurrency: json['preferredCurrency'] ?? 'USD',
      fcmToken: json['fcmToken'],
    );
  }

  /// Returns the active balance based on trading mode.
  double get activeBalance => isPaperTrading ? paperBalance : balance;
}
