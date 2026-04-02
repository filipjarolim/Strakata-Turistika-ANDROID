import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../services/database/database_service.dart';
import '../../widgets/strakata_editorial_background.dart';
import '../../widgets/ui/strakata_primitives.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;

class AdminDashboardTab extends StatefulWidget {
  final VoidCallback? onChangeTab;

  const AdminDashboardTab({super.key, this.onChangeTab});

  @override
  State<AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends State<AdminDashboardTab> {
  bool _isLoading = false;
  String _statusMessage = 'Ready';
  
  // Data State
  bool _isConnected = false;
  int _userCount = 0;
  int _visitCount = 0;
  String _pingLatency = '--';
  final List<String> _errorLogs = []; // internal logs

  @override
  void initState() {
    super.initState();
    _refreshSystemStatus();
  }

  Future<void> _refreshSystemStatus() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _statusMessage = 'Checking connection...';
      _errorLogs.clear();
    });

    try {
      final dbService = DatabaseService();
      
      // 1. Check Connection
      final connected = await dbService.connect();
      if (mounted) setState(() => _isConnected = connected);
      
      if (!connected) {
        throw Exception('Failed to connect to MongoDB');
      }

      // 2. Ping Latency
      if (mounted) setState(() => _statusMessage = 'Pinging database...');
      final stopwatch = Stopwatch()..start();
      await dbService.db?.executeDbCommand(mongo.DbCommand.createPingCommand(dbService.db!));
      stopwatch.stop();
      if (mounted) setState(() => _pingLatency = '${stopwatch.elapsedMilliseconds}ms');

      // 3. Check Users
      if (mounted) setState(() => _statusMessage = 'Counting users...');
      final userCol = await dbService.getCollection('users');
      final uCount = await userCol?.count() ?? 0;
      if (mounted) setState(() => _userCount = uCount);

      // 4. Check Visits (Real Data)
      if (mounted) setState(() => _statusMessage = 'Counting visits...');
      final visitCol = await dbService.getCollection('visits');
      final vCount = await visitCol?.count() ?? 0;
      if (mounted) setState(() => _visitCount = vCount);
      
      if (mounted) setState(() => _statusMessage = 'System Normal');

    } catch (e) {
      if (mounted) {
        setState(() {
           _statusMessage = 'Error detected';
           _errorLogs.add(e.toString());
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const Positioned.fill(child: StrakataEditorialBackground()),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: RefreshIndicator(
            onRefresh: _refreshSystemStatus,
            color: AppColors.brand,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // Header
              const Text(
                'Přehled Systému',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              _buildStatusIndicator(),
              const SizedBox(height: 32),
              
              // stats section
              const Text(
                'Klíčové Statistiky',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(builder: (context, constraints) {
                final w = (constraints.maxWidth - 16) / 2;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildMetricCard('Uživatelé', _userCount.toString(), Icons.people_alt_rounded, Colors.blue[600]!, w),
                    _buildMetricCard('Návštěvy', _visitCount.toString(), Icons.map_rounded, Colors.purple[600]!, w),
                    _buildMetricCard('Připojení', _isConnected ? 'Aktivní' : 'Offline', Icons.link_rounded, _isConnected ? Colors.green[600]! : Colors.red[600]!, w),
                    _buildMetricCard('Odezva', _pingLatency, Icons.speed_rounded, Colors.orange[600]!, w),
                  ],
                );
              }),

              const SizedBox(height: 32),
              
              // Quick Actions
              const Text(
                'Správa a Údržba',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: StrakataSurface.cardDecoration(),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _buildActionItem(
                      icon: Icons.refresh_rounded,
                      title: 'Resetovat připojení',
                      subtitle: 'Znovu zinicializuje spojení s MongoDB Atlas',
                      onTap: _isLoading ? null : () async {
                        await DatabaseService().close();
                        _refreshSystemStatus();
                      },
                    ),
                    _buildDivider(),
                    _buildActionItem(
                      icon: Icons.cleaning_services_rounded,
                      title: 'Vymazat cache databáze',
                      subtitle: 'Odstraní lokálně uložené verze konfigurací',
                      onTap: () {
                         // Placeholder for cache clearing
                      },
                    ),
                  ],
                ),
              ),

              if (_errorLogs.isNotEmpty) ...[
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Detekované Problémy',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFEF4444),
                        letterSpacing: -0.5,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        // copy logic if needed, but keeping it simple
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Kopírovat vše'),
                      style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red[100]!),
                  ),
                  child: SelectableText(
                    _errorLogs.map((e) => '> $e').join('\n'), 
                    style: TextStyle(color: Colors.red[900], fontFamily: 'monospace', fontSize: 13),
                  ),
                )
              ],
              
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
        ),
      ],
    );
  }

  Widget _buildStatusIndicator() {
    final color = _isConnected ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          _isLoading ? 'Aktualizuji systém...' : _statusMessage,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: StrakataSurface.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem({required IconData icon, required String title, required String subtitle, VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF2E7D32), size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF374151),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey[400], size: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, thickness: 1, color: Colors.grey[100], indent: 70);
  }
}
