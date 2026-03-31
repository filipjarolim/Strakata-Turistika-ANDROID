import 'package:flutter/material.dart';
import '../../services/database/database_service.dart';
import '../../widgets/ui/app_button.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;

class SystemOverviewPage extends StatefulWidget {
  const SystemOverviewPage({super.key});

  @override
  State<SystemOverviewPage> createState() => _SystemOverviewPageState();
}

class _SystemOverviewPageState extends State<SystemOverviewPage> {
  bool _isLoading = false;
  String _statusMessage = 'Ready';
  
  // Data State
  bool _isConnected = false;
  int _userCount = 0;
  int _visitCount = 0;
  String _pingLatency = '--';
  List<String> _errorLogs = [];

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
      setState(() => _isConnected = connected);
      
      if (!connected) {
        throw Exception('Failed to connect to MongoDB');
      }

      // 2. Ping Latency
      setState(() => _statusMessage = 'Pinging database...');
      final stopwatch = Stopwatch()..start();
      await dbService.db?.executeDbCommand(mongo.DbCommand.createPingCommand(dbService.db!));
      stopwatch.stop();
      setState(() => _pingLatency = '${stopwatch.elapsedMilliseconds}ms');

      // 3. Check Users
      setState(() => _statusMessage = 'Counting users...');
      final userCol = await dbService.getCollection('users');
      final uCount = await userCol?.count() ?? 0;
      setState(() => _userCount = uCount);

      // 4. Check Visits (Real Data)
      setState(() => _statusMessage = 'Counting visits...');
      final visitCol = await dbService.getCollection('visits');
      final vCount = await visitCol?.count() ?? 0;
      setState(() => _visitCount = vCount);
      
      setState(() => _statusMessage = 'System Normal');

    } catch (e) {
      setState(() {
         _statusMessage = 'Error detected';
         _errorLogs.add(e.toString());
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Admin Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
             icon: const Icon(Icons.refresh), 
             onPressed: _isLoading ? null : _refreshSystemStatus,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Header
            _buildStatusHeader(),
            const SizedBox(height: 24),
            
            // Critical Metrics Grid
            Text(
              'Database metrics'.toUpperCase(), 
              style: TextStyle(
                fontSize: 12, 
                fontWeight: FontWeight.w900, 
                color: Colors.grey[800],
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(builder: (context, constraints) {
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildMetricCard(
                    'Connection', 
                    _isConnected ? 'Active' : 'Offline', 
                    _isConnected ? Colors.green : Colors.red,
                    icon: Icons.link
                  ),
                  _buildMetricCard(
                    'Latency', 
                    _pingLatency, 
                    Colors.orange,
                    icon: Icons.speed
                  ),
                  _buildMetricCard(
                    'Total Users', 
                    _userCount.toString(), 
                    Colors.blue,
                    icon: Icons.people
                  ),
                  _buildMetricCard(
                    'Total Visits', 
                    _visitCount.toString(), 
                    Colors.purple,
                    icon: Icons.map
                  ),
                ],
              );
            }),

            const SizedBox(height: 32),
            
            // Quick Actions
            Text(
              'Quick actions'.toUpperCase(), 
              style: TextStyle(
                fontSize: 12, 
                fontWeight: FontWeight.w900, 
                color: Colors.grey[800],
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                   AppButton(
                     text: 'Force Reconnect',
                     onPressed: _isLoading ? null : () async {
                       await DatabaseService().close();
                       _refreshSystemStatus();
                     },
                     type: AppButtonType.outline,
                   ),
                   const SizedBox(height: 12),
                   const Text('Environment: Production (Atlas)', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Error Logs Console
            if (_errorLogs.isNotEmpty) ...[
               const Text('Debug Console', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
               const SizedBox(height: 8),
               Container(
                 width: double.infinity,
                 padding: const EdgeInsets.all(12),
                 decoration: BoxDecoration(
                   color: Colors.black87,
                   borderRadius: BorderRadius.circular(8),
                 ),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: _errorLogs.map((e) => Text(
                     '> $e', 
                     style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 12)
                   )).toList(),
                 ),
               )
            ],
            
            if (_isLoading)
               Center(child: Padding(
                 padding: const EdgeInsets.all(20.0),
                 child: Text(_statusMessage, style: const TextStyle(color: Colors.grey)),
               )),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.security_rounded, color: Color(0xFF2E7D32), size: 32),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'STAV SYSTÉMU'.toUpperCase(), 
                style: TextStyle(
                  color: Colors.grey[500], 
                  fontSize: 10, 
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _statusMessage, 
                style: const TextStyle(
                  color: Color(0xFF111827), 
                  fontSize: 22, 
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, Color color, {required IconData icon}) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 16),
          Text(
            value, 
            style: const TextStyle(
              fontSize: 22, 
              fontWeight: FontWeight.w900, 
              color: Color(0xFF111827),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title.toUpperCase(), 
            style: TextStyle(
              fontSize: 10, 
              fontWeight: FontWeight.w800, 
              color: Colors.grey[500],
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
