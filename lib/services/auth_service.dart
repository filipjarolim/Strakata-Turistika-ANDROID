import 'package:google_sign_in/google_sign_in.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:mongo_dart/mongo_dart.dart';
import 'database/database_service.dart';
import '../config/google_auth_config.dart';

class AuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: GoogleAuthConfig.scopes,
    // Use default configuration - let Google Sign-In handle the client ID
  );
  
  static User? _currentUser;
  static bool _isInitialized = false;
  
  // Initialize auth service
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Check for existing session
      await _loadSessionFromStorage();
    } catch (e) {
      print('⚠️ Auth initialization warning: $e');
      // Continue without session - this is not critical
    }
    
    // Test plugin availability
    await _testPluginAvailability();
    
    _isInitialized = true;
  }
  
  // Test plugin availability
  static Future<void> _testPluginAvailability() async {
    try {
      // Test SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      print('✅ SharedPreferences plugin is available');
    } catch (e) {
      print('❌ SharedPreferences plugin not available: $e');
    }
    
    try {
      // Test Google Sign-In with a simple operation
      final isSignedIn = await _googleSignIn.isSignedIn();
      print('✅ Google Sign-In plugin is available (isSignedIn: $isSignedIn)');
    } catch (e) {
      print('❌ Google Sign-In plugin not available: $e');
    }
  }
  
  // Get current user
  static User? get currentUser => _currentUser;
  
  // Check if user is logged in
  static bool get isLoggedIn => _currentUser != null;
  
  // Update current user (for profile updates)
  static void updateCurrentUser(User user) {
    _currentUser = user;
  }
  
  // Refresh current user from database (force reload)
  static Future<bool> refreshCurrentUser() async {
    try {
      if (_currentUser == null) return false;
      
      print('🔄 Refreshing user data from database...');
      print('   Current cached role: ${_currentUser!.role}');
      
      final freshUser = await _findUserByEmail(_currentUser!.email);
      
      if (freshUser != null) {
        
        _currentUser = freshUser;
        await _saveSessionToStorage();
        
        return true;
      }
      
      return false;
    } catch (e) {
      print('❌ Error refreshing user: $e');
      return false;
    }
  }
  
  // Clear cached session and force fresh login
  static Future<void> clearCache() async {
    try {
      await _clearSessionFromStorage();
      print('✅ Cache cleared - user needs to login again');
    } catch (e) {
      print('❌ Error clearing cache: $e');
    }
  }
  
  // Test if Google Sign-In plugin is available
  static Future<bool> isGoogleSignInAvailable() async {
    try {
      // Try to access the Google Sign-In instance with a simple operation
      final isSignedIn = await _googleSignIn.isSignedIn();
      return true;
    } catch (e) {
      print('⚠️ Google Sign-In plugin not available: $e');
      return false;
    }
  }
  
  // Google Sign In with retry
  static Future<AuthResult> signInWithGoogle() async {
    // Check if Google configuration is complete
    if (!GoogleAuthConfig.isConfigured) {
      return AuthResult(
        success: false,
        error: 'Google Client ID not configured. Update lib/config/google_auth_config.dart',
      );
    }
    
    // Try up to 3 times with increasing delays
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        // Add delay that increases with each attempt
        if (attempt > 1) {
          await Future.delayed(Duration(milliseconds: 500 * attempt));
        }
        
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        
        if (googleUser == null) {
          return AuthResult(
            success: false,
            error: 'Sign in cancelled',
          );
        }
        
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        
        // Create user object from Google data
        final user = User(
          id: googleUser.id,
          email: googleUser.email.toLowerCase(),
          name: googleUser.displayName ?? '',
          image: googleUser.photoUrl,
          isOAuth: true,
          provider: 'google',
          providerAccountId: googleUser.id,
        );
        
        // Check if user exists in database
        final existingUser = await _findUserByEmail(user.email);
        
        if (existingUser != null) {
          // Update existing user's image if needed
          if (user.image != null && existingUser.image != user.image) {
            await _updateUserImage(existingUser.id, user.image!);
            // Create new user instance with updated image
            _currentUser = User(
              id: existingUser.id,
              email: existingUser.email,
              name: existingUser.name,
              image: user.image,
              isOAuth: existingUser.isOAuth,
              provider: existingUser.provider,
              providerAccountId: existingUser.providerAccountId,
              role: existingUser.role,
              isTwoFactorEnabled: existingUser.isTwoFactorEnabled,
              dogName: existingUser.dogName,
            );
          } else {
            _currentUser = existingUser;
          }
        } else {
          // Create new user
          final createdUser = await _createUser(user);
          _currentUser = createdUser;
        }
        
        // Save session
        await _saveSessionToStorage();
        
        return AuthResult(
          success: true,
          user: _currentUser,
        );
        
      } catch (e) {
        print('❌ Google Sign In Error (attempt $attempt): $e');
        
        // Check if it's a plugin issue
        if (e.toString().contains('MissingPluginException')) {
          if (attempt < 3) {
            print('🔄 Retrying Google Sign-In (attempt ${attempt + 1}/3)...');
            continue;
          } else {
            return AuthResult(
              success: false,
              error: 'Google Sign-In plugin not responding after 3 attempts. Try restarting the app.',
            );
          }
        }
        
        return AuthResult(
          success: false,
          error: 'Failed to sign in with Google: $e',
        );
      }
    }
    
    return AuthResult(
      success: false,
      error: 'Google Sign-In failed after all attempts',
    );
  }
  
  // Sign In with credentials
  static Future<AuthResult> signInWithCredentials(String email, String password) async {
    try {
      // Normalize email to lowercase for case-insensitive comparison
      final normalizedEmail = email.trim().toLowerCase();
      
      if (normalizedEmail.isEmpty || password.isEmpty) {
        return AuthResult(
          success: false,
          error: 'Email and password are required',
        );
      }
      
      if (password.length < 6) {
        return AuthResult(
          success: false,
          error: 'Password must be at least 6 characters',
        );
      }
      
      // Create or find user by email
      final user = User(
        id: 'credential_user_${normalizedEmail.hashCode}',
        email: normalizedEmail,
        name: 'User ${normalizedEmail.split('@')[0]}',
        image: null,
        isOAuth: false,
        provider: 'credentials',
        providerAccountId: normalizedEmail,
      );
      
      // Check if user exists in database
      final existingUser = await _findUserByEmail(user.email);
      
      if (existingUser != null) {
        _currentUser = existingUser;
      } else {
        // Create new user
        final createdUser = await _createUser(user);
        _currentUser = createdUser;
      }
      
      // Save session
      await _saveSessionToStorage();
      
      return AuthResult(
        success: true,
        user: _currentUser,
      );
      
    } catch (e) {
      print('❌ Credential Sign In Error: $e');
      return AuthResult(
        success: false,
        error: 'Failed to sign in with credentials: $e',
      );
    }
  }
  
  // Sign Up with credentials
  static Future<AuthResult> signUpWithCredentials(String email, String password, String name) async {
    try {
      // Normalize email to lowercase for case-insensitive comparison
      final normalizedEmail = email.trim().toLowerCase();
      
      // Validate input
      if (normalizedEmail.isEmpty || password.isEmpty || name.isEmpty) {
        return AuthResult(
          success: false,
          error: 'All fields are required',
        );
      }
      
      if (password.length < 6) {
        return AuthResult(
          success: false,
          error: 'Password must be at least 6 characters',
        );
      }
      
      // Check if user already exists
      final existingUser = await _findUserByEmail(normalizedEmail);
      if (existingUser != null) {
        return AuthResult(
          success: false,
          error: 'User with this email already exists',
        );
      }
      
      // Create new user
      final user = User(
        id: 'credential_user_${DateTime.now().millisecondsSinceEpoch}',
        email: normalizedEmail,
        name: name,
        image: null,
        isOAuth: false,
        provider: 'credentials',
        providerAccountId: normalizedEmail,
      );
      
      final createdUser = await _createUser(user);
      _currentUser = createdUser;
      
      // Save session
      await _saveSessionToStorage();
      
      return AuthResult(
        success: true,
        user: _currentUser,
      );
      
    } catch (e) {
      print('❌ Credential Sign Up Error: $e');
      return AuthResult(
        success: false,
        error: 'Failed to sign up with credentials: $e',
      );
    }
  }
  
  // Sign Out
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      _currentUser = null;
      await _clearSessionFromStorage();
    } catch (e) {
      print('❌ Sign Out Error: $e');
      // Always clear in-memory session even if plugin call failed.
      _currentUser = null;
    }
  }
  
  // Find user by email
  static Future<User?> _findUserByEmail(String email) async {
    try {
      // Normalize email to lowercase for case-insensitive search
      final normalizedEmail = email.trim().toLowerCase();
      
      final userCollection = await DatabaseService().getCollection('users');
      if (userCollection == null) return null;
      
      final users = await userCollection.find({'email': normalizedEmail}).take(1).toList();
      if (users.isEmpty) return null;
      
      final userData = users.first;
      return User.fromMap(userData);
    } catch (e) {
      print('❌ Error finding user by email: $e');
      return null;
    }
  }
  
  // Create new user
  static Future<User> _createUser(User user) async {
    try {
      final userCollection = await DatabaseService().getCollection('users');
      final accountCollection = await DatabaseService().getCollection('accounts');
      
      if (userCollection == null || accountCollection == null) {
        throw Exception('Database collections not available');
      }
      
      // Jednotné stringové _id v Mongo (stejný model jako Prisma / web). Google sub je v providerAccountId.
      final mongoUserId = ObjectId().toHexString();

      final userDoc = {
        '_id': mongoUserId,
        'email': user.email.toLowerCase(),
        'name': user.name,
        'image': user.image,
        'emailVerified': DateTime.now().toIso8601String(),
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'role': 'UZIVATEL',
        'isTwoFactorEnabled': false,
      };

      await userCollection.insertOne(userDoc);

      final accountDoc = {
        '_id': ObjectId().toHexString(),
        'userId': mongoUserId,
        'type': 'oidc',
        'provider': user.provider,
        'providerAccountId': user.providerAccountId,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };
      
      await accountCollection.insertOne(accountDoc);
      
      print('✅ User created successfully');
      
      final createdUsers = await userCollection.find({'email': user.email.toLowerCase()}).take(1).toList();
      if (createdUsers.isNotEmpty) {
         return User.fromMap(createdUsers.first);
      }
      
      throw Exception('Created user could not be loaded back from database');
      
    } catch (e) {
      print('❌ Error creating user: $e');
      rethrow;
    }
  }
  
  // Update user image
  static Future<void> _updateUserImage(String userId, String imageUrl) async {
    try {
      final userCollection = await DatabaseService().getCollection('users');
      if (userCollection == null) return;
      
      await userCollection.updateOne(
        {'_id': userId},
        {
          '\$set': {
            'image': imageUrl,
            'updatedAt': DateTime.now().toIso8601String(),
          }
        }
      );
      
      print('✅ User image updated');
    } catch (e) {
      print('❌ Error updating user image: $e');
      // rethrow; // Optional depending on if we want to bubble up
    }
  }
  
  // Update user dog name
  static Future<bool> updateUserDogName(String userId, String dogName) async {
    try {
      final userCollection = await DatabaseService().getCollection('users');
      if (userCollection == null) return false;
      
      await userCollection.updateOne(
        {'_id': userId},
        {
          '\$set': {
            'dogName': dogName,
            'updatedAt': DateTime.now().toIso8601String(),
          }
        }
      );
      
      // Update current user in memory
      if (_currentUser != null && _currentUser!.id == userId) {
        _currentUser = User(
          id: _currentUser!.id,
          email: _currentUser!.email,
          name: _currentUser!.name,
          image: _currentUser!.image,
          isOAuth: _currentUser!.isOAuth,
          provider: _currentUser!.provider,
          providerAccountId: _currentUser!.providerAccountId,
          role: _currentUser!.role,
          isTwoFactorEnabled: _currentUser!.isTwoFactorEnabled,
          dogName: dogName,
        );
        
        // Save updated session
        await _saveSessionToStorage();
      }
      
      print('✅ User dog name updated');
      return true;
    } catch (e) {
      print('❌ Error updating user dog name: $e');
      return false;
    }
  }
  
  // Load session from local storage
  static Future<void> _loadSessionFromStorage() async {
    try {
      // Check if SharedPreferences is available
      final prefs = await SharedPreferences.getInstance();
      final sessionData = prefs.getString('user_session');
      
      if (sessionData != null) {
        final userData = jsonDecode(sessionData);
        _currentUser = User.fromMap(userData);
        
        // Always refresh from database to get latest data (including role changes)
        if (_currentUser?.email != null) {
          final freshUser = await _findUserByEmail(_currentUser!.email);
          if (freshUser != null) {
            _currentUser = freshUser;
            // Update cached session with fresh data
            await _saveSessionToStorage();
          }
        } else {
          print('ℹ️ Session loaded but email is null');
        }
      } else {
        print('ℹ️ No saved session found (App needs to login)');
      }
    } catch (e) {
      print('⚠️ SharedPreferences not available (this is normal on first run): $e');
      // Don't rethrow - this is expected when no session exists or plugin not ready
    }
  }
  
  // Save session to local storage
  static Future<void> _saveSessionToStorage() async {
    try {
      // Check if SharedPreferences is available
      final prefs = await SharedPreferences.getInstance();
      if (_currentUser != null) {
        await prefs.setString('user_session', jsonEncode(_currentUser!.toMap()));
      }
    } catch (e) {
      print('⚠️ Could not save session to storage (this is normal during development): $e');
      // Don't rethrow - session saving is not critical for core functionality
      // The user will still be logged in for the current session
    }
  }
  
  // Clear session from local storage
  static Future<void> _clearSessionFromStorage() async {
    try {
      // Check if SharedPreferences is available
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_session');
      print('✅ Session cleared from storage');
    } catch (e) {
      print('⚠️ Could not clear session from storage (this is normal during development): $e');
      // Don't rethrow - session clearing is not critical for core functionality
    }
  }
  
}

// User model
class User {
  final String id;
  final String email;
  final String name;
  final String? image;
  final bool isOAuth;
  final String provider;
  final String providerAccountId;
  final String? role;
  final bool? isTwoFactorEnabled;
  final String? dogName;
  
  User({
    required this.id,
    required this.email,
    required this.name,
    this.image,
    required this.isOAuth,
    required this.provider,
    required this.providerAccountId,
    this.role,
    this.isTwoFactorEnabled,
    this.dogName,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'image': image,
      'isOAuth': isOAuth,
      'provider': provider,
      'providerAccountId': providerAccountId,
      'role': role,
      'isTwoFactorEnabled': isTwoFactorEnabled,
      'dogName': dogName,
    };
  }
  
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: (map['_id'] ?? map['id'] ?? '').toString(),
      email: map['email']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      image: map['image']?.toString(),
      isOAuth: map['isOAuth'] == true,
      provider: map['provider']?.toString() ?? 'google',
      providerAccountId: map['providerAccountId']?.toString() ?? '',
      role: map['role']?.toString(),
      isTwoFactorEnabled: map['isTwoFactorEnabled'] == true,
      dogName: map['dogName']?.toString(),
    );
  }
}

// Auth result model
class AuthResult {
  final bool success;
  final User? user;
  final String? error;
  
  AuthResult({
    required this.success,
    this.user,
    this.error,
  });
} 