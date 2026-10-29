import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class UserModel {
  final String fullName;
  final String username;
  final String email;
  final String dietaryPreference; // 'Veg', 'Non-Veg', 'Vegan', etc.
  final String targetGroup; // 'Self', 'Kids & Babies', 'Seniors', 'Family'
  final int totalScans;
  final String memberSince;
  final bool isGuest;

  UserModel({
    required this.fullName,
    required this.username,
    required this.email,
    this.dietaryPreference = 'Veg',
    this.targetGroup = 'Family',
    this.totalScans = 0,
    required this.memberSince,
    this.isGuest = false,
  });

  Map<String, dynamic> toMap() => {
        'fullName': fullName,
        'username': username,
        'email': email,
        'dietaryPreference': dietaryPreference,
        'targetGroup': targetGroup,
        'totalScans': totalScans,
        'memberSince': memberSince,
        'isGuest': isGuest,
      };

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
        fullName: map['fullName'] ?? 'Food Conscious User',
        username: map['username'] ?? 'User',
        email: map['email'] ?? '',
        dietaryPreference: map['dietaryPreference'] ?? 'Veg',
        targetGroup: map['targetGroup'] ?? 'Family',
        totalScans: map['totalScans'] ?? 0,
        memberSince: map['memberSince'] ?? 'October 2026',
        isGuest: map['isGuest'] ?? false,
      );

  UserModel copyWith({
    String? fullName,
    String? username,
    String? email,
    String? dietaryPreference,
    String? targetGroup,
    int? totalScans,
    String? memberSince,
    bool? isGuest,
  }) {
    return UserModel(
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      email: email ?? this.email,
      dietaryPreference: dietaryPreference ?? this.dietaryPreference,
      targetGroup: targetGroup ?? this.targetGroup,
      totalScans: totalScans ?? this.totalScans,
      memberSince: memberSince ?? this.memberSince,
      isGuest: isGuest ?? this.isGuest,
    );
  }
}

class AuthService {
  static const String _userSessionKey = 'user_session_v1';
  static const String _usersDbKey = 'registered_users_db_v1';

  /// Get currently logged in user session
  static Future<UserModel?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_userSessionKey);
    if (data == null) return null;
    try {
      return UserModel.fromMap(jsonDecode(data));
    } catch (_) {
      return null;
    }
  }

  /// Sign In with Username or Email & Password
  static Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    final query = identifier.trim().toLowerCase();
    if (query.isEmpty || password.isEmpty) {
      return {'success': false, 'message': 'Please enter both username/email and password.'};
    }

    final prefs = await SharedPreferences.getInstance();
    final usersDbRaw = prefs.getString(_usersDbKey);
    Map<String, dynamic> usersDb = {};
    if (usersDbRaw != null) {
      try {
        usersDb = Map<String, dynamic>.from(jsonDecode(usersDbRaw));
      } catch (_) {}
    }

    Map<String, dynamic>? foundUser;
    for (var u in usersDb.values) {
      if ((u['email']?.toString().toLowerCase() == query ||
           u['username']?.toString().toLowerCase() == query) &&
          u['password'] == password) {
        foundUser = Map<String, dynamic>.from(u);
        break;
      }
    }

    // Built-in Demo account or first-time auto-login if password is valid
    if (foundUser == null && (query == 'demo' || query == 'admin' || query == 'user') && password.length >= 4) {
      foundUser = {
        'fullName': 'Health Conscious User',
        'username': query,
        'email': '$query@nutriscan.ai',
        'dietaryPreference': 'Veg',
        'targetGroup': 'Family',
        'totalScans': 3,
        'memberSince': 'October 2026',
        'isGuest': false,
      };
    }

    if (foundUser != null) {
      final user = UserModel(
        fullName: foundUser['fullName'] ?? 'Healthy Consumer',
        username: foundUser['username'] ?? query,
        email: foundUser['email'] ?? '$query@nutriscan.ai',
        dietaryPreference: foundUser['dietaryPreference'] ?? 'Veg',
        targetGroup: foundUser['targetGroup'] ?? 'Family',
        totalScans: foundUser['totalScans'] ?? 0,
        memberSince: foundUser['memberSince'] ?? 'October 2026',
        isGuest: false,
      );
      await prefs.setString(_userSessionKey, jsonEncode(user.toMap()));
      return {'success': true, 'user': user};
    }

    return {'success': false, 'message': 'Invalid credentials. Please register an account or try Demo.'};
  }

  /// Register a new user
  static Future<Map<String, dynamic>> register({
    required String fullName,
    required String username,
    required String email,
    required String password,
    String dietaryPreference = 'Veg',
    String targetGroup = 'Family',
  }) async {
    final cleanUsername = username.trim().toLowerCase();
    final cleanEmail = email.trim().toLowerCase();

    if (fullName.trim().isEmpty || cleanUsername.isEmpty || cleanEmail.isEmpty || password.isEmpty) {
      return {'success': false, 'message': 'Please fill all fields.'};
    }
    if (password.length < 6) {
      return {'success': false, 'message': 'Password must be at least 6 characters.'};
    }

    final prefs = await SharedPreferences.getInstance();
    final usersDbRaw = prefs.getString(_usersDbKey);
    Map<String, dynamic> usersDb = {};
    if (usersDbRaw != null) {
      try {
        usersDb = Map<String, dynamic>.from(jsonDecode(usersDbRaw));
      } catch (_) {}
    }

    if (usersDb.containsKey(cleanUsername)) {
      return {'success': false, 'message': 'Username is already taken.'};
    }

    final newUser = {
      'fullName': fullName.trim(),
      'username': username.trim(),
      'email': cleanEmail,
      'password': password,
      'dietaryPreference': dietaryPreference,
      'targetGroup': targetGroup,
      'totalScans': 0,
      'memberSince': 'October 2026',
      'isGuest': false,
    };

    usersDb[cleanUsername] = newUser;
    await prefs.setString(_usersDbKey, jsonEncode(usersDb));

    // Save as active session
    final userModel = UserModel(
      fullName: fullName.trim(),
      username: username.trim(),
      email: cleanEmail,
      dietaryPreference: dietaryPreference,
      targetGroup: targetGroup,
      totalScans: 0,
      memberSince: 'October 2026',
      isGuest: false,
    );
    await prefs.setString(_userSessionKey, jsonEncode(userModel.toMap()));
    return {'success': true, 'user': userModel};
  }

  /// Continue as Guest
  static Future<UserModel> loginAsGuest() async {
    final prefs = await SharedPreferences.getInstance();
    final guest = UserModel(
      fullName: 'Guest Explorer',
      username: 'Guest',
      email: 'guest@nutriscan.ai',
      dietaryPreference: 'Veg',
      targetGroup: 'Family',
      totalScans: 0,
      memberSince: 'October 2026',
      isGuest: true,
    );
    await prefs.setString(_userSessionKey, jsonEncode(guest.toMap()));
    return guest;
  }

  /// Increment Scan Count
  static Future<void> incrementScanCount() async {
    final user = await getCurrentUser();
    if (user != null) {
      final updated = user.copyWith(totalScans: user.totalScans + 1);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userSessionKey, jsonEncode(updated.toMap()));
    }
  }

  /// Update User Profile
  static Future<void> updateProfile(UserModel updatedUser) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userSessionKey, jsonEncode(updatedUser.toMap()));
  }

  /// Sign Out
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userSessionKey);
  }
}
