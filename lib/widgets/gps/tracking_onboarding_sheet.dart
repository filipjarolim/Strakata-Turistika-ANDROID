import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../ui/app_button.dart';
import '../ui/strakata_primitives.dart';

class TrackingOnboardingSheet extends StatefulWidget {
  final VoidCallback? onComplete;
  final bool showSkipButton;

  /// When true (GPS tracking flow), all three steps must be completed.
  /// When false (app entry), foreground location is enough to continue.
  final bool requireAllForComplete;

  const TrackingOnboardingSheet({
    super.key,
    this.onComplete,
    this.showSkipButton = true,
    this.requireAllForComplete = true,
  });

  @override
  State<TrackingOnboardingSheet> createState() => _TrackingOnboardingSheetState();
}

class _TrackingOnboardingSheetState extends State<TrackingOnboardingSheet>
    with WidgetsBindingObserver {
  bool _locationGranted = false;
  bool _backgroundGranted = false;
  bool _batteryOptimized = true;
  bool _isCompleting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  bool get _canContinue {
    if (widget.requireAllForComplete) {
      return _locationGranted && _backgroundGranted && !_batteryOptimized;
    }
    return _locationGranted;
  }

  Future<void> _checkPermissions() async {
    final locStatus = await Permission.location.status;
    final bgStatus = await Permission.locationAlways.status;
    final batteryStatus = await Permission.ignoreBatteryOptimizations.status;

    if (!mounted) return;

    setState(() {
      _locationGranted = locStatus.isGranted;
      _backgroundGranted = bgStatus.isGranted;
      _batteryOptimized = !batteryStatus.isGranted;
    });

    if (_canContinue && !_isCompleting) {
      _isCompleting = true;
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        _finish();
      });
    }
  }

  void _finish() {
    if (widget.onComplete != null) {
      widget.onComplete!();
    } else {
      Navigator.of(context).pop(_canContinue);
    }
  }

  Future<void> _requestLocation() async {
    await Permission.location.request();
    await _checkPermissions();
  }

  Future<void> _showBackgroundInstructions() async {
    if (!mounted) return;
    final open = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nastavení polohy na pozadí'),
        content: const Text(
          'V nastavení telefonu otevřete sekci Oprávnění → Poloha '
          'a zvolte „Povolit vždy“ (ne „Pouze při používání“).\n\n'
          'Sekce Baterie není totéž — tu nastavíte až v dalším kroku.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Zrušit'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Otevřít nastavení'),
          ),
        ],
      ),
    );
    if (open != true) return;
    if (await Permission.locationAlways.isPermanentlyDenied) {
      await openAppSettings();
    } else {
      await Permission.locationAlways.request();
      if (!await Permission.locationAlways.isGranted && Platform.isAndroid) {
        await openAppSettings();
      }
    }
    await _checkPermissions();
  }

  Future<void> _requestBackground() async {
    await _showBackgroundInstructions();
  }

  Future<void> _requestBattery() async {
    if (!mounted) return;
    final open = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Úspora baterie'),
        content: const Text(
          'V nastavení aplikace otevřete sekci Baterie a zvolte '
          '„Bez omezení“ nebo „Neomezeno“.\n\n'
          'Na některých telefonech (Samsung, Xiaomi…) může být volba '
          'pod jiným názvem — hledejte vypnutí úspory baterie pro tuto aplikaci.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Zrušit'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Otevřít nastavení'),
          ),
        ],
      ),
    );
    if (open != true) return;
    await Permission.ignoreBatteryOptimizations.request();
    if (!await Permission.ignoreBatteryOptimizations.isGranted) {
      await openAppSettings();
    }
    await _checkPermissions();
  }

  @override
  Widget build(BuildContext context) {
    final allDone = _locationGranted && _backgroundGranted && !_batteryOptimized;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF7),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: const Color(0xFFE8E4DC)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(child: StrakataSheetHandle()),
          const SizedBox(height: 24),
          const Text(
            'Nastavení sledování',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.requireAllForComplete
                ? 'Pro spolehlivý záznam trasy i při vypnuté obrazovce potřebujeme následující oprávnění.'
                : 'Pro základní používání stačí přístup k poloze. Doporučujeme dokončit i další kroky před výletem s GPS.',
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF4B5563),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          _buildStep(
            title: 'Přístup k poloze',
            description: 'Základní oprávnění pro GPS.',
            isDone: _locationGranted,
            onAction: _requestLocation,
            buttonText: 'Povolit',
          ),
          const SizedBox(height: 20),
          _buildStep(
            title: 'Sledování na pozadí',
            description:
                'V nastavení zvolte „Povolit vždy“. Jinak se GPS při zamčeném telefonu vypne.',
            isDone: _backgroundGranted,
            onAction: _requestBackground,
            buttonText: 'Nastavit „Vždy“',
            isEnabled: _locationGranted,
          ),
          const SizedBox(height: 20),
          _buildStep(
            title: 'Vypnout úsporu baterie',
            description: 'Samostatný krok v sekci Baterie — zabrání ukončení aplikace během výletu.',
            isDone: !_batteryOptimized,
            onAction: _requestBattery,
            buttonText: 'Nastavit baterii',
            isEnabled: _locationGranted,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _checkPermissions,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Zkontrolovat nastavení znovu'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4B5563),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              onPressed: _canContinue
                  ? () {
                      if (_isCompleting) return;
                      _isCompleting = true;
                      _finish();
                    }
                  : (widget.showSkipButton ? () => Navigator.of(context).pop(false) : null),
              text: _primaryButtonLabel(allDone),
              type: _canContinue ? AppButtonType.primary : AppButtonType.ghost,
              size: AppButtonSize.large,
            ),
          ),
        ],
      ),
    );
  }

  String _primaryButtonLabel(bool allDone) {
    if (_canContinue) {
      return widget.requireAllForComplete
          ? 'Hotovo, spustit sledování'
          : 'Pokračovat do aplikace';
    }
    if (widget.showSkipButton) return 'Nastavit později';
    return 'Nejdřív povolte přístup k poloze';
  }

  Widget _buildStep({
    required String title,
    required String description,
    required bool isDone,
    required VoidCallback onAction,
    required String buttonText,
    bool isEnabled = true,
  }) {
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: isDone
                  ? const Color(0xFF4CAF50)
                  : (isEnabled ? const Color(0xFFE5E7EB) : const Color(0xFFF3F4F6)),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isDone ? Icons.check : Icons.circle_outlined,
              color: isDone ? Colors.white : Colors.grey[500],
              size: 18,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDone ? const Color(0xFF4CAF50) : const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
                if (!isDone && isEnabled) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 36,
                    child: ElevatedButton(
                      onPressed: onAction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF3F4F6),
                        foregroundColor: const Color(0xFF1F2937),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: Text(
                        buttonText,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
