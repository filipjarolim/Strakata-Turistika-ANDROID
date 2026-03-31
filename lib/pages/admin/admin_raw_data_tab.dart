import 'package:flutter/material.dart';
import 'dart:convert';
import '../../services/database/database_service.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;

class AdminRawDataTab extends StatefulWidget {
  const AdminRawDataTab({Key? key}) : super(key: key);

  @override
  State<AdminRawDataTab> createState() => _AdminRawDataTabState();
}

class _AdminRawDataTabState extends State<AdminRawDataTab> {
  final DatabaseService _dbService = DatabaseService();
  List<Map<String, dynamic>> _rawData = [];
  bool _isLoading = true;
  int _page = 1;
  static const int _limit = 20;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadRawData();
  }

  Future<void> _loadRawData({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _page = 1;
        _rawData = [];
        _hasMore = true;
        _isLoading = true;
      });
    }

    try {
      final collection = await _dbService.getCollection('visits');
      if (collection == null) throw Exception('Collection not found');

      final skip = (_page - 1) * _limit;
      final docs = await collection.find(
        mongo.where.sortBy('createdAt', descending: true).skip(skip).limit(_limit)
      ).toList();

      if (mounted) {
        setState(() {
          _rawData.addAll(docs);
          _isLoading = false;
          _hasMore = docs.length == _limit;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba při načítání dat: $e')),
        );
      }
    }
  }

  void _loadMore() {
    if (!_isLoading && _hasMore) {
      setState(() {
        _page++;
        _isLoading = true;
      });
      _loadRawData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: _rawData.isEmpty && _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
          : RefreshIndicator(
              onRefresh: () => _loadRawData(refresh: true),
              color: const Color(0xFF2E7D32),
              child: ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: _rawData.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _rawData.length) {
                    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32))),
                    );
                  }

                  final doc = _rawData[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey[100]!),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _buildRawDocCard(doc),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildRawDocCard(Map<String, dynamic> doc) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        iconColor: const Color(0xFF2E7D32),
        childrenPadding: EdgeInsets.zero,
        title: Text(
          doc['routeTitle']?.toString() ?? doc['title']?.toString() ?? 'Bez názvu',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: Color(0xFF111827),
            letterSpacing: -0.3,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'ID: ${doc['_id']?.toString().substring(doc['_id'].toString().length - 8) ?? 'N/A'}\nUživatel: ${doc['userId'] ?? doc['fullName'] ?? 'Neznámý'}',
            style: TextStyle(fontSize: 12, color: Colors.grey[500], height: 1.4, fontWeight: FontWeight.w500),
          ),
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              border: Border(top: BorderSide(color: Colors.grey[100]!)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.code_rounded, size: 14, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      'RAW DATA (JSON)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey[600],
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SelectableText(
                  _getPrettyJson(doc),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Color(0xFF374151),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getPrettyJson(Map<String, dynamic> doc) {
    try {
      final sanitized = _sanitizeForJson(doc);
      return const JsonEncoder.withIndent('  ').convert(sanitized);
    } catch (e) {
      return 'Chyba při formátování JSON: $e\n\nRaw: $doc';
    }
  }

  dynamic _sanitizeForJson(dynamic value) {
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _sanitizeForJson(v)));
    } else if (value is List) {
      return value.map((e) => _sanitizeForJson(e)).toList();
    } else if (value is DateTime) {
      return value.toIso8601String();
    } else if (value is mongo.ObjectId) {
      return value.toHexString();
    } else if (value.runtimeType.toString().contains('Int64')) {
      // Handle fixnum.Int64 without needing the package import explicitly
      return value.toString();
    } else if (value is num || value is bool || value == null || value is String) {
      return value;
    } else {
      return value.toString();
    }
  }
}
