import 'package:flutter/material.dart';
import 'app_animations.dart';

class GpsAnimations {
  static AnimationController createPulseController(TickerProvider vsync) {
    return AnimationController(
      duration: AppAnimations.durationGpsPulse,
      vsync: vsync,
    );
  }

  static AnimationController createSlideController(TickerProvider vsync) {
    return AnimationController(
      duration: AppAnimations.durationMedium,
      vsync: vsync,
    );
  }

  static AnimationController createSpeedPulseController(TickerProvider vsync) {
    return AnimationController(
      duration: AppAnimations.durationStandard,
      vsync: vsync,
    );
  }

  static AnimationController createFadeController(TickerProvider vsync) {
    return AnimationController(
      duration: AppAnimations.durationShort,
      vsync: vsync,
    );
  }

  static AnimationController createBounceController(TickerProvider vsync) {
    return AnimationController(
      duration: AppAnimations.durationPageTransition,
      vsync: vsync,
    );
  }

  static AnimationController createScaleController(TickerProvider vsync) {
    return AnimationController(
      duration: AppAnimations.durationShort,
      vsync: vsync,
    );
  }

  static Animation<double> createPulseAnimation(AnimationController controller) {
    return Tween<double>(
      begin: 1.0,
      end: 1.28,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOut,
    ));
  }

  static Animation<Offset> createSlideAnimation(AnimationController controller) {
    return Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: AppAnimations.curveEmphasized,
    ));
  }

  static Animation<double> createSpeedPulseAnimation(AnimationController controller) {
    return Tween<double>(
      begin: 1.0,
      end: 1.12,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOut,
    ));
  }

  static Animation<double> createFadeAnimation(AnimationController controller) {
    return Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: AppAnimations.curveDecelerate,
    ));
  }

  static Animation<double> createBounceAnimation(AnimationController controller) {
    return Tween<double>(
      begin: 0.92,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: AppAnimations.curveBounce,
    ));
  }

  static Animation<double> createScaleAnimation(AnimationController controller) {
    return Tween<double>(
      begin: 0.94,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: AppAnimations.curveStandard,
    ));
  }

  static AnimationController createPanelSlideController(TickerProvider vsync) {
    return AnimationController(
      duration: AppAnimations.durationPageTransition,
      vsync: vsync,
    );
  }

  static Animation<Offset> createPanelSlideAnimation(AnimationController controller) {
    return Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: AppAnimations.curveEmphasized,
    ));
  }

  static void initializeAnimations({
    required AnimationController pulseController,
    required AnimationController slideController,
    required AnimationController fadeController,
    AnimationController? panelSlideController,
  }) {
    // Pulse only starts when tracking is active (caller starts repeat).
    slideController.forward();
    fadeController.forward();
    panelSlideController?.forward();
  }

  static void disposeAnimations({
    required AnimationController pulseController,
    required AnimationController slideController,
    required AnimationController speedPulseController,
    required AnimationController fadeController,
    required AnimationController bounceController,
    required AnimationController scaleController,
    AnimationController? panelSlideController,
  }) {
    pulseController.dispose();
    slideController.dispose();
    speedPulseController.dispose();
    fadeController.dispose();
    bounceController.dispose();
    scaleController.dispose();
    panelSlideController?.dispose();
  }
}
