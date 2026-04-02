import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../ui/app_button.dart';
import '../ui/strakata_primitives.dart';

class TrackingOnboardingSheet extends StatefulWidget {
  final VoidCallback? onComplete;
  final bool showSkipButton;

  const TrackingOnboardingSheet({
    super.key,
    this.onComplete,
    this.showSkipButton = true,
  });

  @override
  State<TrackingOnboardingSheet> createState() => _TrackingOnboardingSheetState();
}

class _TrackingOnboardingSheetState extends State<TrackingOnboardingSheet> with WidgetsBindingObserver {
  bool _locationGranted = false;
  bool _backgroundGranted = false;
  bool _batteryOptimized = true; // True means optimization is ON (bad for us)
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

  Future<void> _checkPermissions() async {
    final locStatus = await Permission.location.status;
    final bgStatus = await Permission.locationAlways.status;
    final batteryStatus = await Permission.ignoreBatteryOptimizations.status;

    if (mounted) {
      setState(() {
        _locationGranted = locStatus.isGranted;
        _backgroundGranted = bgStatus.isGranted;
        _batteryOptimized = !batteryStatus.isGranted;
      });

      // Auto-close if everything is good
      if (_locationGranted && _backgroundGranted && !_batteryOptimized) {
        if (_isCompleting) return; // Prevent multiple triggers
        _isCompleting = true;
        
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            if (widget.onComplete != null) {
              widget.onComplete!();
            } else {
              Navigator.of(context).pop(true);
            }
          }
        });
      }
    }
  }

  Future<void> _requestLocation() async {
    await Permission.location.request();
    await _checkPermissions();
  }

  Future<void> _requestBackground() async {
    // Show instruction first if needed, as per Android guidelines
    // But since this IS the instruction screen, we can just request/open settings
    if (await Permission.locationAlways.isPermanentlyDenied) {
      await openAppSettings();
    } else {
      await Permission.locationAlways.request();
    }
    await _checkPermissions();
  }

  Future<void> _requestBattery() async {
    await Permission.ignoreBatteryOptimizations.request();
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
          const Text(
            'Pro spolehlivý záznam trasy i při vypnuté obrazovce potřebujeme následující oprávnění.',
            style: TextStyle(
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
            description: 'Umožní aplikaci běžet při zamčeném telefonu. Vyberte "Vždy povolit" / "Allow all the time".',
            isDone: _backgroundGranted,
            onAction: _requestBackground,
            buttonText: 'Povolit "Vždy"',
            isEnabled: _locationGranted, // Can't ask background before foreground
          ),
          
          const SizedBox(height: 20),
          
          _buildStep(
            title: 'Vypnout úsporu baterie',
            description: 'Zabrání systému ukončit aplikaci během výletu.',
            isDone: !_batteryOptimized,
            onAction: _requestBattery,
            buttonText: 'Vypnout omezení',
            isEnabled: _locationGranted,
          ),
          
          const SizedBox(height: 32),
          
          SizedBox(
            width: double.infinity,
            child: AppButton(
              onPressed: allDone 
                  ? () {
                      if (_isCompleting) return;
                      _isCompleting = true;
                      
                      if (widget.onComplete != null) {
                        widget.onComplete!();
                      } else {
                        Navigator.of(context).pop(true);
                      }
                    }
                  : (widget.showSkipButton 
                      ? () => Navigator.of(context).pop(false)
                      : null), // Disable if skip is not allowed
              text: allDone ? 'Hotovo, spustit aplikaci' : (widget.showSkipButton ? 'Nastavit později' : 'Dokončete nastavení'),
              type: allDone ? AppButtonType.primary : AppButtonType.ghost,
              size: AppButtonSize.large,
              // If not done and skip is hidden, disable the button
              // AppButton doesn't have "disabled" property exposed directly in the example used, assuming standard behavior or handling via onPressed null
            ),
          ),
        ],
      ),
    );
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
          // Check/Number Icon
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: isDone ? const Color(0xFF4CAF50) : (isEnabled ? const Color(0xFFE5E7EB) : const Color(0xFFF3F4F6)),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isDone ? Icons.check : Icons.circle_outlined,
              color: isDone ? Colors.white : Colors.grey[500],
              size: 18,
            ),
          ),
          const SizedBox(width: 16),
          
          // Content
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
