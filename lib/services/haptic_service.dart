import 'package:flutter/services.dart';

class HapticService {
  /// Light haptic feedback for minor interactions
  static Future<void> lightImpact() async {
    try {
      await HapticFeedback.lightImpact();
    } catch (e) {
      print('Haptic feedback not available: $e');
    }
  }

  /// Medium haptic feedback for important interactions
  static Future<void> mediumImpact() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (e) {
      print('Haptic feedback not available: $e');
    }
  }

  /// Heavy haptic feedback for critical interactions
  static Future<void> heavyImpact() async {
    try {
      await HapticFeedback.heavyImpact();
    } catch (e) {
      print('Haptic feedback not available: $e');
    }
  }

  /// Selection haptic feedback
  static Future<void> selectionClick() async {
    try {
      await HapticFeedback.selectionClick();
    } catch (e) {
      print('Haptic feedback not available: $e');
    }
  }

  /// Vibration feedback for notifications
  static Future<void> vibrate({int milliseconds = 100}) async {
    try {
      await HapticFeedback.vibrate();
    } catch (e) {
      print('Vibration not available: $e');
    }
  }

  /// Custom haptic feedback for GPS tracking start/stop
  static Future<void> trackingStart() async {
    await Future.wait([
      mediumImpact(),
      vibrate(milliseconds: 200),
    ]);
  }

  /// Custom haptic feedback for GPS tracking stop
  static Future<void> trackingStop() async {
    await Future.wait([
      heavyImpact(),
      vibrate(milliseconds: 300),
    ]);
  }

  /// Custom haptic feedback for navigation
  static Future<void> navigationTap() async {
    await lightImpact();
  }

  /// Custom haptic feedback for form submission
  static Future<void> formSubmit() async {
    await mediumImpact();
  }
} 