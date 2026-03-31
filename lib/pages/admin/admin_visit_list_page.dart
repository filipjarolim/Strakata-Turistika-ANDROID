import 'package:flutter/material.dart';
import '../../config/admin_theme.dart';
import '../../widgets/admin/admin_page_template.dart';
import '../../widgets/admin/admin_cards.dart';
import '../../widgets/admin/admin_common_widgets.dart';
import '../../models/visit_data.dart';
import '../../repositories/visit_repository.dart';

class AdminVisitListPage extends StatefulWidget {
  const AdminVisitListPage({super.key});

  @override
  State<AdminVisitListPage> createState() => _AdminVisitListPageState();
}

class _AdminVisitListPageState extends State<AdminVisitListPage> {
  final VisitRepository _repository = VisitRepository();
  List<VisitData> _visits = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVisits();
  }

  Future<void> _loadVisits() async {
    setState(() => _isLoading = true);
    try {
      final result = await _repository.getVisits(
        limit: 50, 
        onlyApproved: false,
        states: [VisitState.PENDING_REVIEW],
      );
      if (mounted) {
        setState(() {
          _visits = (result['data'] as List).cast<VisitData>();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba při načítání: $e')),
        );
      }
    }
  }

  Future<void> _updateStatus(String id, VisitState newState) async {
    await _repository.updateVisitState(id, newState);
    _loadVisits();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newState == VisitState.APPROVED ? 'Návštěva schválena' : 'Návštěva zamítnuta'),
          backgroundColor: newState == VisitState.APPROVED ? AdminColors.emerald500 : AdminColors.rose500,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageTemplate(
      title: const Text('NÁVŠTĚVY', style: AdminTextStyles.display),
      subtitle: const Text('Revize a schvalování návštěv', style: AdminTextStyles.body),
      icon: Icon(Icons.map_rounded, color: AdminColors.indigo500),
      actions: [
        IconButton(
          onPressed: () => _loadVisits(),
          icon: const Icon(Icons.refresh_rounded, color: AdminColors.zinc500),
        ),
        const SizedBox(width: AdminSpacing.sm),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AdminSpacing.sm),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Hledat návštěvy...',
                hintStyle: AdminTextStyles.small,
                border: InputBorder.none,
                icon: const Icon(Icons.search, size: 18, color: AdminColors.zinc400),
              ),
            ),
          ),
        ),
      ],
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _visits.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 64, color: AdminColors.zinc300),
                      SizedBox(height: AdminSpacing.lg),
                      Text('Žádné návštěvy ke schválení', style: AdminTextStyles.body),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: AdminSpacing.lg),
                  itemCount: _visits.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AdminSpacing.xl),
                  itemBuilder: (context, index) {
                    final visit = _visits[index];
                    return VisitDataCard(
                      title: visit.displayName ?? 'Neznámý uživatel',
                      subtitle: 'Navštíveno: ${visit.visitDate?.day}. ${visit.visitDate?.month}. ${visit.visitDate?.year} • ${visit.routeTitle ?? "Neznámá trasa"}',
                      map: Container(
                        color: AdminColors.zinc100,
                        child: const Center(
                          child: Icon(Icons.map_outlined, size: 48, color: AdminColors.zinc300),
                        ),
                      ),
                      stats: [
                        StatBox(
                          icon: Icons.stars_rounded,
                          label: 'Body',
                          value: '${visit.points} pts',
                          iconColor: AdminColors.amber500,
                        ),
                        StatBox(
                          icon: Icons.place_rounded,
                          label: 'Místa',
                          value: '${visit.places.length} ks', // Simplified count
                          iconColor: AdminColors.blue500,
                        ),
                        StatBox(
                          icon: Icons.photo_library_rounded,
                          label: 'Fotky',
                          value: '${visit.photos?.length ?? 0}',
                          iconColor: AdminColors.purple500,
                        ),
                        StatBox(
                          icon: visit.dogName != null ? Icons.pets_rounded : Icons.person_rounded,
                          label: 'Pes',
                          value: visit.dogName ?? 'Bez psa',
                          iconColor: AdminColors.emerald500,
                        ),
                      ],
                      images: (visit.photos ?? []).map((p) => p['url'].toString()).toList(),
                      actions: [
                        AppButton(
                          label: 'Schválit',
                          onPressed: () => _updateStatus(visit.id, VisitState.APPROVED),
                          variant: AppButtonVariant.success,
                          size: AppButtonSize.sm,
                          icon: Icons.check,
                        ),
                        const SizedBox(width: AdminSpacing.sm),
                        AppButton(
                          label: 'Zamítnout',
                          onPressed: () => _updateStatus(visit.id, VisitState.REJECTED),
                          variant: AppButtonVariant.destructive,
                          size: AppButtonSize.sm,
                          icon: Icons.close,
                        ),
                      ],
                    );
                  },
                ),
    );
  }
}
