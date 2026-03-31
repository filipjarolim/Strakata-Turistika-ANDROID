import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/database/database_service.dart';
import 'login_page.dart';
import '../services/vector_tile_provider.dart';
import '../services/mapy_cz_download_service.dart';
import 'package:latlong2/latlong.dart';
import '../services/offline_ui_bridge.dart';
import '../widgets/ui/glass_ui.dart';
import '../widgets/ui/app_button.dart';
import '../widgets/ui/app_toast.dart';
import '../widgets/ui/strakata_primitives.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    return GlassScaffold(
      body: Column(
        children: [
          // Header with Back Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 16),
                const StrakataSectionTitle(
                  'Nastavení',
                  fontSize: 24,
                  color: Color(0xFF1A1A1A),
                ),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                children: [
                  // User profile section
                  GlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                          backgroundImage: user?.image != null ? NetworkImage(user!.image!) : null,
                          child: user?.image == null
                              ? const Icon(Icons.person, color: Color(0xFF4CAF50), size: 40)
                              : null,
                        ),
                        const SizedBox(height: 16),
                        if (user != null) ...[
                          Text(
                            user.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.email,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ] else ...[
                          const Text(
                            'Nepřihlášen',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Přihlaste se pro přístup ke všem funkcím',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Settings options
                  if (user != null) ...[
                    _buildSettingsSection(
                      title: 'Účet',
                      items: [
                        _buildSettingsItem(
                          icon: Icons.edit,
                          title: 'Upravit profil',
                          subtitle: 'Změnit jméno a jméno psa',
                          onTap: () {
                            _showEditProfileSheet(context);
                          },
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    _buildSettingsSection(
                      title: 'Aplikace',
                      items: [
                        _buildSettingsItem(
                          icon: Icons.storage_rounded,
                          title: 'Offline mapy',
                          subtitle: 'Správa cache, pokrytí, stažení oblastí',
                          onTap: () {
                            _showOfflineMapsSheet(context);
                          },
                        ),
                        _buildSettingsItem(
                          icon: Icons.info,
                          title: 'O aplikaci',
                          subtitle: 'Verze aplikace a informace',
                          onTap: () {
                            showAboutDialog(
                              context: context,
                              applicationName: 'Strakatá Turistika',
                              applicationVersion: '1.1.0',
                              applicationIcon: const Icon(Icons.hiking),
                            );
                          },
                        ),
                      ],
                    ),
                    
                    if (user.role == 'ADMIN') ...[
                      const SizedBox(height: 32),
                      _buildSettingsSection(
                        title: 'Admin Zóna',
                        items: [
                          _buildSettingsItem(
                            icon: Icons.delete_forever,
                            title: 'Resetovat aplikaci',
                            subtitle: 'Vymaže všechna data a odhlásí se',
                            onTap: () async {
                               // Show confirmation
                               final confirm = await showDialog<bool>(
                                 context: context,
                                 builder: (ctx) => AlertDialog(
                                   title: const Text('Resetovat aplikaci?'),
                                   content: const Text(
                                     'Opravdu chcete vymazat všechna lokální data a nastavení? '
                                     'Aplikace se uvede do stavu po instalaci a budete odhlášeni.'
                                   ),
                                   actions: [
                                     TextButton(
                                       onPressed: () => Navigator.pop(ctx, false),
                                       child: const Text('Zrušit'),
                                     ),
                                     TextButton(
                                       onPressed: () => Navigator.pop(ctx, true),
                                       style: TextButton.styleFrom(foregroundColor: Colors.red),
                                       child: const Text('Resetovat'),
                                     ),
                                   ],
                                 ),
                               );

                               if (confirm == true && context.mounted) {
                                 // Clear everything
                                 final prefs = await SharedPreferences.getInstance();
                                 await prefs.clear();
                                 
                                 // Sign out
                                 await AuthService.signOut();
                                 
                                 if (context.mounted) {
                                   Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                                 }
                               }
                            },
                          ),
                        ],
                      ),
                    ],
                    
                    const SizedBox(height: 32),
                    
                    // Sign out button
                    SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        onPressed: () async {
                          await AuthService.signOut();
                          if (context.mounted) {
                            Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                          }
                        },
                        text: 'Odhlásit se',
                        icon: Icons.logout,
                        type: AppButtonType.destructiveOutline,
                        size: AppButtonSize.large,
                      ),
                    ),
                  ] else ...[
                    // Sign in button for non-authenticated users
                    SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginPage()),
                          );
                        },
                        text: 'Přihlásit se',
                        icon: Icons.login,
                        type: AppButtonType.primary,
                        size: AppButtonSize.large,
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    const SizedBox(height: 24),
                    
                    _buildSettingsSection(
                      title: 'Aplikace',
                      items: [
                        _buildSettingsItem(
                          icon: Icons.info,
                          title: 'O aplikaci',
                          subtitle: 'Verze aplikace a informace',
                          onTap: () {
                            showAboutDialog(
                              context: context,
                              applicationName: 'Strakatá Turistika',
                              applicationVersion: '1.1.0',
                              applicationIcon: const Icon(Icons.hiking),
                            );
                          },
                        ),
                      ],
                    ),


                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showOfflineMapsSheet(BuildContext context) {
    showStrakataModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        // consume external open requests
        OfflineUiBridge.consumeOpenManager();
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StrakataSheetHandle(),
              const SizedBox(height: 12),
              const StrakataSheetTitle('Offline mapy', fontSize: 18),
              const SizedBox(height: 12),
              FutureBuilder<Map<String, dynamic>>(
                future: VectorTileProvider.getDetailedStats(),
                builder: (context, snap) {
                  final stats = snap.data ?? {};
                  final total = stats['totalTiles'] ?? 0;
                  final bytes = stats['totalCompressedBytes'] ?? 0;
                  final mb = (bytes is int) ? (bytes / 1024 / 1024).toStringAsFixed(1) : '0.0';
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dlaždice v cache: $total'),
                      const SizedBox(height: 4),
                      Text('Velikost: $mb MB'),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              const Text('Rychlé stažení oblastí', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                   Expanded(
                    child: AppButton(
                      onPressed: () async {
                        // Czech Republic center band sample preset
                        final sw = const LatLng(48.9, 12.3);
                        final ne = const LatLng(50.6, 16.0);
                        await MapyCzDownloadService.downloadBounds(
                          southwest: sw,
                          northeast: ne,
                          minZoom: 8,
                          maxZoom: 12,
                          concurrency: 24,
                          batchSize: 800,
                        );
                        if (context.mounted) Navigator.of(ctx).pop();
                      },
                      icon: Icons.download,
                      text: 'Střed ČR (z8–12)',
                      type: AppButtonType.outline,
                    ),
                  ),
                   Expanded(
                    child: AppButton(
                      onPressed: () async {
                        // Prague area preset
                        final sw = const LatLng(49.95, 14.15);
                        final ne = const LatLng(50.25, 14.75);
                        await MapyCzDownloadService.downloadBounds(
                          southwest: sw,
                          northeast: ne,
                          minZoom: 10,
                          maxZoom: 15,
                          concurrency: 24,
                          batchSize: 800,
                        );
                        if (context.mounted) Navigator.of(ctx).pop();
                      },
                      icon: Icons.download,
                      text: 'Praha (z10–15)',
                      type: AppButtonType.outline,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      onPressed: () async {
                        await MapyCzDownloadService.clearCache();
                        if (context.mounted) Navigator.of(ctx).pop();
                      },
                      icon: Icons.cleaning_services_outlined,
                      text: 'Vyčistit',
                      type: AppButtonType.secondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      text: 'Zavřít',
                      type: AppButtonType.ghost,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditProfileSheet(BuildContext context) {
    final user = AuthService.currentUser;
    final nameController = TextEditingController(text: user?.name ?? '');
    final dogNameController = TextEditingController(text: user?.dogName ?? '');
    showStrakataModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StrakataSheetHandle(),
              const SizedBox(height: 12),
              const StrakataSheetTitle('Upravit profil', fontSize: 18),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Jméno',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dogNameController,
                decoration: const InputDecoration(
                  labelText: 'Jméno psa',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  AppButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    text: 'Zrušit',
                    type: AppButtonType.ghost,
                  ),
                  const Spacer(),
                  AppButton(
                    onPressed: () async {
                      final u = AuthService.currentUser;
                      if (u == null) {
                        Navigator.of(ctx).pop();
                        return;
                      }
                      final newName = nameController.text.trim();
                      final newDogName = dogNameController.text.trim();
                      bool ok = true;
                      try {
                        await _updateUserName(u.id, newName.isEmpty ? u.name : newName);
                        await AuthService.updateUserDogName(u.id, newDogName);
                      } catch (_) {
                        ok = false;
                      }
                      if (context.mounted) {
                        Navigator.of(ctx).pop();
                        if (ok) {
                          AppToast.showSuccess(context, 'Profil uložen');
                        } else {
                          AppToast.showError(context, 'Nepodařilo se uložit profil');
                        }
                      }
                    },
                    text: 'Uložit',
                    type: AppButtonType.primary,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _updateUserName(String userId, String name) async {
    try {
      final users = await DatabaseService().getCollection('users');
      if (users != null) {
        await users.updateOne({'_id': userId}, {
          '\$set': {
            'name': name,
            'updatedAt': DateTime.now().toIso8601String(),
          }
        });
      }
      // update in-memory user
      final u = AuthService.currentUser;
      if (u != null) {
        final updated = User(
          id: u.id,
          email: u.email,
          name: name,
          image: u.image,
          isOAuth: u.isOAuth,
          provider: u.provider,
          providerAccountId: u.providerAccountId,
          role: u.role,
          isTwoFactorEnabled: u.isTwoFactorEnabled,
          dogName: u.dogName,
        );
        // Persist via session helper
        // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
        // Store back using same mechanism
        // This mirrors AuthService._saveSessionToStorage but we cannot call it here directly
        // so we re-use public sign-in persistence by setting the static field and calling saver
        // Note: this relies on current structure of AuthService
        // ignore: invalid_use_of_visible_for_testing_member
        // Assign
        // Dart has no access modifier, but we avoid importing private helpers
        // Instead update SharedPreferences directly
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_session', jsonEncode(updated.toMap()));
        // ignore: avoid_print
        print('✅ Updated display name in session');
      }
    } catch (e) {
      // ignore: avoid_print
      print('❌ Failed to update user name: $e');
    }
  }

  Widget _buildSettingsSection({
    required String title,
    required List<Widget> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StrakataSectionTitle(
          title,
          fontSize: 18,
          color: const Color(0xFF333333),
          letterSpacing: 0,
        ),
        const SizedBox(height: 16),
        ...items,
      ],
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF4CAF50),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Color(0xFF9CA3AF),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

}