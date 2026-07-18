import 'dart:io';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

/// Service pro správu aktualizací aplikace z Google Play Store a sledování verzí
class AppUpdateService {
  static bool _isCheckingForUpdate = false;
  
  /// Inicializuje sledování verzí. Porovná aktuální verzi s naposledy uloženou.
  /// Pokud se verze liší, zaznamená čas aktualizace do SharedPreferences.
  static Future<void> initializeVersionTracking() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final packageInfo = await PackageInfo.fromPlatform();
      
      final currentVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
      final lastSavedVersion = prefs.getString('last_run_version');
      
      if (lastSavedVersion == null) {
        // První spuštění aplikace na tomto zařízení
        await prefs.setString('last_run_version', currentVersion);
        await prefs.setString('app_install_date', DateTime.now().toIso8601String());
        await prefs.setString('app_last_update_date', DateTime.now().toIso8601String());
      } else if (lastSavedVersion != currentVersion) {
        // Aplikace byla aktualizována
        await prefs.setString('last_run_version', currentVersion);
        await prefs.setString('app_last_update_date', DateTime.now().toIso8601String());
        print('🎉 Aplikace byla aktualizována na verzi $currentVersion!');
      }
    } catch (e) {
      print('❌ Chyba při inicializaci sledování verzí: $e');
    }
  }

  /// Získá formátovaný řetězec s aktuální verzí (např. "1.1.17 (51)")
  static Future<String> getAppVersionString() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return '${packageInfo.version} (${packageInfo.buildNumber})';
    } catch (_) {
      return 'Neznámá verze';
    }
  }

  /// Získá datum poslední aktualizace / instalace aplikace
  static Future<String> getLastUpdateDateString() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dateStr = prefs.getString('app_last_update_date');
      if (dateStr == null) {
        await initializeVersionTracking();
        final reRead = prefs.getString('app_last_update_date');
        if (reRead != null) {
          final date = DateTime.parse(reRead);
          return DateFormat('d. M. yyyy').format(date);
        }
        return 'Neznámé';
      }
      final date = DateTime.parse(dateStr);
      return DateFormat('d. M. yyyy').format(date);
    } catch (_) {
      return 'Neznámé';
    }
  }

  /// Zkontroluje dostupnost aktualizace a zobrazí dialog pokud je k dispozici
  static Future<void> checkForUpdate(
    BuildContext context, {
    bool forceImmediate = false,
  }) async {
    // Inicializovat / aktualizovat informace o verzi
    await initializeVersionTracking();

    // In-app update funguje pouze na Android
    if (!Platform.isAndroid) {
      return;
    }
    
    // Zabránění duplicitním kontrolám
    if (_isCheckingForUpdate) {
      return;
    }
    
    _isCheckingForUpdate = true;
    
    try {
      // Zkontroluj dostupnost aktualizace
      final AppUpdateInfo updateInfo = await InAppUpdate.checkForUpdate();
      
      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        if (forceImmediate || updateInfo.immediateUpdateAllowed) {
          // Okamžitá aktualizace - uživatel musí aktualizovat hned
          await _performImmediateUpdate(context, updateInfo);
        } else if (updateInfo.flexibleUpdateAllowed) {
          // Flexibilní aktualizace - uživatel může pokračovat v používání aplikace
          await _showFlexibleUpdateDialog(context);
        }
      }
    } catch (e) {
      final errorStr = e.toString();
      if (!errorStr.contains('ERROR_APP_NOT_OWNED')) {
        debugPrint('Chyba při kontrole aktualizace: $e');
      }
    } finally {
      _isCheckingForUpdate = false;
    }
  }

  /// Provede manuální kontrolu aktualizací se zobrazením loading dialogu a toastů
  static Future<void> manualCheckForUpdate(BuildContext context) async {
    // Zobrazit loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Kontrola aktualizací...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      if (!Platform.isAndroid) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kontrola aktualizací je podporována pouze na systému Android.')),
        );
        return;
      }

      final AppUpdateInfo updateInfo = await InAppUpdate.checkForUpdate();
      
      if (context.mounted) {
        Navigator.pop(context); // Skrýt loading dialog
      }

      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        if (updateInfo.immediateUpdateAllowed) {
          await _performImmediateUpdate(context, updateInfo);
        } else if (updateInfo.flexibleUpdateAllowed) {
          await _showFlexibleUpdateDialog(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nová verze je k dispozici v Google Play Store.')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Máte nainstalovanou nejnovější verzi aplikace.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Skrýt loading dialog
      }
      
      final errorStr = e.toString();
      if (errorStr.contains('ERROR_APP_NOT_OWNED')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tato aplikace nebyla nainstalována přes Google Play Store.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba při kontrole aktualizace: $e')),
        );
      }
    }
  }
  
  /// Provede okamžitou aktualizaci (blocking)
  static Future<void> _performImmediateUpdate(
    BuildContext context,
    AppUpdateInfo updateInfo,
  ) async {
    try {
      await InAppUpdate.performImmediateUpdate();
    } catch (e) {
      debugPrint('Chyba při okamžité aktualizaci: $e');
      if (context.mounted) {
        _showUpdateErrorDialog(context);
      }
    }
  }
  
  /// Zobrazí dialog s možností flexibilní aktualizace
  static Future<void> _showFlexibleUpdateDialog(BuildContext context) async {
    if (!context.mounted) return;
    
    final bool? shouldUpdate = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Aktualizace k dispozici'),
          content: const Text(
            'Je k dispozici nová verze aplikace Strakatá turistika. '
            'Doporučujeme aktualizovat pro získání nových funkcí a vylepšení.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Později'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Aktualizovat'),
            ),
          ],
        );
      },
    );
    
    if (shouldUpdate == true) {
      await _startFlexibleUpdate(context);
    }
  }
  
  /// Spustí flexibilní aktualizaci na pozadí
  static Future<void> _startFlexibleUpdate(BuildContext context) async {
    try {
      await InAppUpdate.startFlexibleUpdate();
      await InAppUpdate.completeFlexibleUpdate();
      
      if (context.mounted) {
        _showUpdateCompletedDialog(context);
      }
    } catch (e) {
      debugPrint('Chyba při flexibilní aktualizaci: $e');
      if (context.mounted) {
        _showUpdateErrorDialog(context);
      }
    }
  }
  
  /// Zobrazí dialog po úspěšném dokončení aktualizace
  static void _showUpdateCompletedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Aktualizace dokončena'),
          content: const Text(
            'Aplikace byla úspěšně aktualizována. '
            'Pro aplikování změn bude aplikace restartována.',
          ),
          actions: <Widget>[
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
  
  /// Zobrazí dialog v případě chyby při aktualizaci
  static void _showUpdateErrorDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Chyba aktualizace'),
          content: const Text(
            'Při aktualizaci aplikace došlo k chybě. '
            'Zkuste to prosím později nebo aktualizujte manuálně z Google Play Store.',
          ),
          actions: <Widget>[
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
  
  /// Provede tichou kontrolu aktualizace (bez dialogu, pouze v pozadí)
  static Future<bool> silentCheckForUpdate() async {
    if (!Platform.isAndroid) {
      return false;
    }
    
    try {
      final AppUpdateInfo updateInfo = await InAppUpdate.checkForUpdate();
      return updateInfo.updateAvailability == UpdateAvailability.updateAvailable;
    } catch (e) {
      final errorStr = e.toString();
      if (!errorStr.contains('ERROR_APP_NOT_OWNED')) {
        debugPrint('Chyba při tiché kontrole aktualizace: $e');
      }
      return false;
    }
  }
}
