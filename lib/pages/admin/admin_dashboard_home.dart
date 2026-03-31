import 'package:flutter/material.dart';
import '../../config/admin_theme.dart';
import '../../widgets/admin/admin_page_template.dart';
import '../../widgets/admin/admin_cards.dart';

import '../../services/admin_service.dart';

class AdminDashboardHome extends StatefulWidget {
  const AdminDashboardHome({super.key});

  @override
  State<AdminDashboardHome> createState() => _AdminDashboardHomeState();
}

class _AdminDashboardHomeState extends State<AdminDashboardHome> {
  final AdminService _adminService = AdminService();
  Map<String, dynamic> _stats = {
    'pendingVisits': 0,
    'activeNews': 0,
    'totalUsers': 0,
  };
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    final stats = await _adminService.getDashboardStats();
    if (mounted) {
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageTemplate(
      title: const Text(
        'ADMIN PANEL',
        style: AdminTextStyles.display,
      ),
      subtitle: const Text(
        'Vítejte v administraci Strakaté Turistiky',
        style: AdminTextStyles.body,
      ),
      icon: Icon(Icons.admin_panel_settings_rounded, color: AdminColors.indigo500),
      child: LayoutBuilder(
        builder: (context, constraints) {
          int crossAxisCount = constraints.maxWidth < 600 ? 2 : 4;
          return GridView.count(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: AdminSpacing.lg,
            crossAxisSpacing: AdminSpacing.lg,
            children: [
              HubDashboardCard(
                icon: Icons.article_rounded,
                title: 'Novinky',
                count: _isLoading ? '...' : '${_stats['activeNews']} aktivních',
                onTap: () {
                  Navigator.pushNamed(context, '/admin-news').then((_) => _loadStats());
                },
              ),
              HubDashboardCard(
                icon: Icons.map_rounded,
                title: 'Návštěvy',
                count: _isLoading ? '...' : '${_stats['pendingVisits']} k revizi',
                onTap: () {
                  Navigator.pushNamed(context, '/admin-visits').then((_) => _loadStats());
                },
              ),
              HubDashboardCard(
                icon: Icons.people_rounded,
                title: 'Uživatelé',
                count: _isLoading ? '...' : '${_stats['totalUsers']} celkem',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Správa uživatelů bude dostupná brzy.')),
                  );
                },
              ),
              HubDashboardCard(
                icon: Icons.settings_rounded,
                title: 'Nastavení',
                count: 'Systém OK',
                onTap: () {
                   ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nastavení systému bude dostupné brzy.')),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
