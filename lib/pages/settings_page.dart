import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/database/database_service.dart';
import 'login_page.dart';
import '../services/vector_tile_provider.dart';
import '../services/mapy_cz_download_service.dart';
import 'package:latlong2/latlong.dart';
import '../services/offline_ui_bridge.dart';
import '../config/app_colors.dart';
import '../config/app_theme.dart';
import '../widgets/ui/glass_ui.dart';
import '../widgets/ui/app_button.dart';
import '../widgets/ui/app_toast.dart';
import '../widgets/ui/strakata_primitives.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/ui/web_mobile_section_card.dart';
import '../widgets/ui/web_mobile_patterns.dart';
import 'offline_maps_page.dart';

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
                Material(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary, size: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Nastavení',
                    style: AppTheme.editorialHeadline(
                      color: AppColors.textPrimary,
                      fontSize: 26,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
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
                  WebMobileSectionCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: AppColors.brand.withValues(alpha: 0.12),
                          backgroundImage: user?.image != null ? NetworkImage(user!.image!) : null,
                          child: user?.image == null
                              ? Icon(Icons.person_rounded, color: AppColors.brand, size: 40)
                              : null,
                        ),
                        const SizedBox(height: 16),
                        if (user != null) ...[
                          Text(
                            user.name,
                            style: AppTheme.editorialHeadline(
                              color: AppColors.textPrimary,
                              fontSize: 22,
                            ).copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.email,
                            style: GoogleFonts.libreFranklin(
                              fontSize: 14,
                              color: AppColors.textTertiary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0EBE3),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              'Účet aktivní',
                              style: GoogleFonts.libreFranklin(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ] else ...[
                          Text(
                            'Nepřihlášen',
                            style: AppTheme.editorialHeadline(
                              color: AppColors.textPrimary,
                              fontSize: 22,
                            ).copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Přihlaste se pro přístup ke všem funkcím',
                            style: GoogleFonts.libreFranklin(
                              fontSize: 14,
                              color: AppColors.textTertiary,
                              fontWeight: FontWeight.w500,
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
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const OfflineMapsPage(),
                              ),
                            );
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
                        _buildSettingsItem(
                          icon: Icons.description_outlined,
                          title: 'Pravidla soutěže',
                          subtitle: 'Otevřít oficiální pravidla na webu',
                          onTap: _openRulesWeb,
                        ),
                      ],
                    ),
                    
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
                        _buildSettingsItem(
                          icon: Icons.description_outlined,
                          title: 'Pravidla soutěže',
                          subtitle: 'Otevřít oficiální pravidla na webu',
                          onTap: _openRulesWeb,
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
        WebMobileSectionTitle(title),
        const SizedBox(height: 12),
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
      child: WebMobileListItem(
        icon: icon,
        title: title,
        subtitle: subtitle,
        onTap: onTap,
      ),
    );
  }

  Future<void> _openRulesWeb() async {
    final url = Uri.parse('https://www.strakata.cz/pravidla');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

}