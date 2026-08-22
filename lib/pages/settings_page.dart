import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/database/database_service.dart';
import 'login_page.dart';
import '../config/app_colors.dart';
import '../config/app_theme.dart';
import '../config/legal_config.dart';
import '../widgets/ui/glass_ui.dart';
import '../widgets/ui/app_button.dart';
import '../widgets/ui/app_toast.dart';
import '../widgets/ui/strakata_primitives.dart';
import '../widgets/ui/web_mobile_section_card.dart';
import '../widgets/ui/web_mobile_patterns.dart';
import '../widgets/legal/legal_actions.dart';
import 'offline_maps_page.dart';
import '../services/app_update_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    return GlassScaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
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
            Expanded(
              child: FutureBuilder<List<String>>(
                future: Future.wait([
                  AppUpdateService.getAppVersionString(),
                  AppUpdateService.getLastUpdateDateString(),
                ]),
                builder: (context, snapshot) {
                  final version = snapshot.data?[0] ?? '…';
                  final lastUpdate = snapshot.data?[1] ?? '…';
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                    children: [
                      _buildProfileCard(user),
                      const SizedBox(height: 28),
                      if (user != null) ...[
                        _buildSettingsSection(
                          title: 'Účet',
                          items: [
                            _buildSettingsItem(
                              icon: Icons.edit_outlined,
                              title: 'Upravit profil',
                              subtitle: 'Změnit jméno a jméno psa',
                              onTap: () => _showEditProfileSheet(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
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
                            icon: Icons.system_update_alt_rounded,
                            title: 'Zkontrolovat aktualizace',
                            subtitle: 'Vyhledat novou verzi na Google Play',
                            onTap: () => AppUpdateService.manualCheckForUpdate(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildSettingsSection(
                        title: 'Právní informace',
                        items: [
                          _buildSettingsItem(
                            icon: Icons.privacy_tip_outlined,
                            title: 'Zásady ochrany osobních údajů',
                            subtitle: 'Jak zpracováváme účet, GPS, fotky a návštěvy',
                            onTap: () => LegalActions.openPrivacyPolicy(context),
                          ),
                          _buildSettingsItem(
                            icon: Icons.gavel_outlined,
                            title: 'Podmínky použití',
                            subtitle: 'Pravidla používání aplikace a účtu',
                            onTap: () => LegalActions.openTermsOfService(context),
                          ),
                          _buildSettingsItem(
                            icon: Icons.description_outlined,
                            title: 'Pravidla soutěže',
                            subtitle: 'Oficiální pravidla Strakaté turistiky',
                            onTap: () => LegalActions.openCompetitionRules(context),
                          ),
                          _buildSettingsItem(
                            icon: Icons.article_outlined,
                            title: 'Open source licence',
                            subtitle: 'Licence použitých knihoven',
                            onTap: () => LegalActions.openLicenses(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildSettingsSection(
                        title: 'O aplikaci',
                        items: [
                          _buildVersionCard(
                            context: context,
                            version: version,
                            lastUpdate: lastUpdate,
                          ),
                          _buildSettingsItem(
                            icon: Icons.support_agent_rounded,
                            title: 'Kontaktovat podporu',
                            subtitle: LegalConfig.supportEmail,
                            onTap: () => LegalActions.contactSupport(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      if (user != null) ...[
                        SizedBox(
                          width: double.infinity,
                          child: AppButton(
                            onPressed: () async {
                              await AuthService.signOut();
                              if (context.mounted) {
                                Navigator.of(context).pushNamedAndRemoveUntil(
                                  '/login',
                                  (route) => false,
                                );
                              }
                            },
                            text: 'Odhlásit se',
                            icon: Icons.logout,
                            type: AppButtonType.destructiveOutline,
                            size: AppButtonSize.large,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: AppButton(
                            onPressed: () => _showDeleteAccountConfirmation(context),
                            text: 'Smazat účet',
                            type: AppButtonType.ghost,
                            size: AppButtonSize.small,
                          ),
                        ),
                      ] else ...[
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
                      ],
                      const SizedBox(height: 28),
                      Text(
                        LegalConfig.legalese,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.libreFranklin(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Verze $version',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.libreFranklin(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textTertiary.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(User? user) {
    return WebMobileSectionCard(
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
    );
  }

  Widget _buildVersionCard({
    required BuildContext context,
    required String version,
    required String lastUpdate,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => LegalActions.showAbout(context),
          borderRadius: BorderRadius.circular(24),
          child: WebMobileSectionCard(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.hiking_rounded, color: AppColors.brand, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        LegalConfig.appName,
                        style: GoogleFonts.libreFranklin(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Verze $version',
                        style: GoogleFonts.libreFranklin(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Aktualizováno $lastUpdate · ${LegalConfig.publisherName}',
                        style: GoogleFonts.libreFranklin(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.textTertiary.withValues(alpha: 0.6),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
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
      await DatabaseService().updateOne('users', {'_id': userId}, {
        '\$set': {
          'name': name,
          'updatedAt': DateTime.now(),
        }
      });
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
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_session', jsonEncode(updated.toMap()));
        print('✅ Updated display name in session');
      }
    } catch (e) {
      print('❌ Failed to update user name: $e');
    }
  }

  void _showDeleteAccountConfirmation(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Smazat účet'),
        content: const Text(
          'Smazáním účtu trvale odstraníte svůj profil, návštěvy a související data. Tuto akci nelze vrátit.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Zrušit'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(c);
              await _deleteAccount(context);
            },
            child: const Text(
              'SMAZAT',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context) async {
    try {
      final u = AuthService.currentUser;
      if (u == null) return;
      await DatabaseService().deleteOne('users', {'_id': u.id});
      await DatabaseService().deleteMany('visits', {'userId': u.id});
      await AuthService.signOut();
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.showError(context, 'Chyba: $e');
      }
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
}
