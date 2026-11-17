import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strakataturistikaandroidapp/main.dart';
import 'package:strakataturistikaandroidapp/pages/exception_request_page.dart';
import 'package:strakataturistikaandroidapp/pages/explore_tab.dart';
import 'package:strakataturistikaandroidapp/pages/login_page.dart';
import 'package:strakataturistikaandroidapp/pages/offline_maps_page.dart';
import 'package:strakataturistikaandroidapp/pages/onboarding/permission_onboarding_page.dart';
import 'package:strakataturistikaandroidapp/models/leaderboard_entry.dart';
import 'package:strakataturistikaandroidapp/pages/results_page.dart';
import 'package:strakataturistikaandroidapp/pages/settings_page.dart';
import 'package:strakataturistikaandroidapp/pages/user_profile_page.dart';
import 'package:strakataturistikaandroidapp/services/auth_service.dart';
import 'package:strakataturistikaandroidapp/widgets/legal/legal_actions.dart';
import 'package:strakataturistikaandroidapp/widgets/tab_switch.dart';

/// Pumps every main screen at the lite emulator size (720x1280 @ 320dpi = 360x640)
/// and records yellow/black RenderFlex overflow stripes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const phone = Size(360, 640);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
    AuthService.updateCurrentUser(
      User(
        id: 'overflow-user',
        email: 'walker@example.com',
        name: 'Filip Walker',
        isOAuth: true,
        provider: 'google',
        providerAccountId: 'google-sub',
        dogName: 'Rex',
      ),
    );
  });

  testWidgets('audit screens for RenderFlex overflows', (tester) async {
    final hits = <String>[];

    Future<void> watch(Future<void> Function() body) async {
      final previous = FlutterError.onError;
      FlutterError.onError = (details) {
        final message = details.exceptionAsString();
        if (message.contains('overflowed')) {
          final summary = details.toString().split('\n').take(8).join('\n');
          hits.add(summary);
          return;
        }
        previous?.call(details);
      };
      try {
        await body();
      } finally {
        FlutterError.onError = previous;
      }
    }

    Future<void> pumpScreen(String name, Widget child) async {
      await watch(() async {
        await tester.binding.setSurfaceSize(phone);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = phone;
        await tester.pumpWidget(
          MaterialApp(locale: const Locale('cs', 'CZ'), home: child),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      });
      // Tag the most recent untagged hits with the screen name by prefixing
      // only messages that do not already start with a screen label.
    }

    final screens = <String, Widget>{
      'LoginPage': const LoginPage(),
      'ExploreTab': TabSwitch(switchTo: (_) {}, child: const ExploreTab()),
      'ResultsPage': const ResultsPage(),
      'LeaderboardTile': Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          children: [
            LeaderboardTile(
              rank: 1,
              entry: LeaderboardEntry(
                userId: '1',
                userName: 'Anna Nováková',
                totalPoints: 150,
                visitsCount: 4,
                dogName: 'Alík',
              ),
            ),
            LeaderboardTile(
              rank: 2,
              entry: LeaderboardEntry(
                userId: '2',
                userName: 'Němec s velmi dlouhým jménem účastníka',
                totalPoints: 115,
                visitsCount: 2,
                dogName: 'Bernardýn Maxmilián',
              ),
            ),
          ],
        ),
      ),
      'UserProfilePage': const UserProfilePage(),
      'SettingsPage': const SettingsPage(),
      'OfflineMapsPage': const OfflineMapsPage(),
      'ExceptionRequestPage': const ExceptionRequestPage(),
      'PermissionOnboardingPage': const PermissionOnboardingPage(),
    };

    for (final entry in screens.entries) {
      final before = hits.length;
      try {
        await pumpScreen(entry.key, entry.value);
      } catch (e) {
        hits.add('${entry.key}: failed to build ($e)');
      }
      if (hits.length == before) {
        // ignore: avoid_print
        print('OK  ${entry.key}');
      } else {
        for (var i = before; i < hits.length; i++) {
          hits[i] = '${entry.key}\n${hits[i]}';
        }
      }
    }

    final homeBefore = hits.length;
    try {
      await watch(() async {
        await tester.binding.setSurfaceSize(phone);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = phone;
        await tester.pumpWidget(
          const MaterialApp(locale: Locale('cs', 'CZ'), home: MyHomePage()),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      });
      await watch(() async {
        await tester.tap(find.byIcon(Icons.person_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      });
      await watch(() async {
        final about = find.text('O aplikaci');
        if (about.evaluate().isNotEmpty) {
          await tester.tap(about);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
        }
      });
    } catch (e) {
      hits.add('MyHomePage profile sheet: failed to build ($e)');
    }
    for (var i = homeBefore; i < hits.length; i++) {
      if (!hits[i].startsWith('MyHomePage')) {
        hits[i] = 'MyHomePage / profile sheet\n${hits[i]}';
      }
    }

    final aboutBefore = hits.length;
    try {
      await watch(() async {
        await tester.binding.setSurfaceSize(phone);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = phone;
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('cs', 'CZ'),
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: TextButton(
                      onPressed: () => LegalActions.showAbout(context),
                      child: const Text('open-about'),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.tap(find.text('open-about'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      });
    } catch (e) {
      hits.add('About sheet: failed to build ($e)');
    }
    for (var i = aboutBefore; i < hits.length; i++) {
      if (!hits[i].startsWith('About')) {
        hits[i] = 'About sheet\n${hits[i]}';
      }
    }

    addTearDown(() async {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      await tester.binding.setSurfaceSize(null);
    });

    expect(
      hits,
      isEmpty,
      reason: 'RenderFlex overflows:\n\n${hits.join('\n---\n')}',
    );
  });
}
