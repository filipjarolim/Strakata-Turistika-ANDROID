import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../config/app_colors.dart';
import '../config/app_theme.dart';
import '../models/exception_request.dart';
import '../repositories/exception_request_repository.dart';
import '../services/auth_service.dart';
import '../widgets/ui/glass_ui.dart';
import '../widgets/ui/app_button.dart';
import '../widgets/ui/web_mobile_section_card.dart';

class ExceptionRequestPage extends StatefulWidget {
  const ExceptionRequestPage({Key? key}) : super(key: key);

  @override
  State<ExceptionRequestPage> createState() => _ExceptionRequestPageState();
}

class _ExceptionRequestPageState extends State<ExceptionRequestPage> {
  final ExceptionRequestRepository _repository = ExceptionRequestRepository();
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  
  double _requestedMinKm = 1.5;
  bool _isLoading = true;
  bool _isSubmitting = false;
  List<ExceptionRequest> _requests = [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    final user = AuthService.currentUser;
    if (user == null) return;
    
    setState(() => _isLoading = true);
    try {
      final list = await _repository.getExceptionRequests(user.id);
      setState(() {
        _requests = list;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading requests: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    final user = AuthService.currentUser;
    if (user == null) return;

    setState(() => _isSubmitting = true);
    try {
      final success = await _repository.createRequest(
        user.id,
        _reasonController.text.trim(),
        _requestedMinKm,
      );
      
      if (success) {
        _reasonController.clear();
        _requestedMinKm = 1.5;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Žádost byla úspěšně odeslána k posouzení.')),
          );
        }
        await _loadRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPending = _requests.any((r) => r.status == ExceptionStatus.pending);

    return GlassScaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Row(
              children: [
                Material(
                  color: Colors.white.withOpacity(0.9),
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
                    'Žádost o výjimku',
                    style: AppTheme.editorialHeadline(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),

          // Scrollable Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                    children: [
                      // Subtitle card
                      WebMobileSectionCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Výjimky z pravidel',
                              style: GoogleFonts.libreFranklin(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Mezi výlety musí být aspoň 3 km. Když vás to zdravotně nebo jinak limituje, požádejte o nižší číslo. Administrátor vaši žádost posoudí.',
                              style: GoogleFonts.libreFranklin(
                                fontSize: 13,
                                color: AppColors.textTertiary,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Form to request new exception (only if user does not have a pending one)
                      if (!hasPending) ...[
                        WebMobileSectionCard(
                          padding: const EdgeInsets.all(18),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Nová žádost',
                                  style: GoogleFonts.libreFranklin(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Reason Field
                                TextFormField(
                                  controller: _reasonController,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                    labelText: 'Důvod žádosti o výjimku',
                                    hintText: 'Popište, proč potřebujete výjimku (např. zdravotní omezení)...',
                                    alignLabelWithHint: true,
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Důvod je povinné pole';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Requested min distance slider/value
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Požadovaná minimální délka:',
                                      style: GoogleFonts.libreFranklin(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '${_requestedMinKm.toStringAsFixed(1)} km',
                                      style: GoogleFonts.libreFranklin(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.brand,
                                      ),
                                    ),
                                  ],
                                ),
                                Slider(
                                  value: _requestedMinKm,
                                  min: 0.5,
                                  max: 2.9,
                                  divisions: 24,
                                  activeColor: AppColors.brand,
                                  inactiveColor: AppColors.brand.withOpacity(0.2),
                                  label: '${_requestedMinKm.toStringAsFixed(1)} km',
                                  onChanged: (val) {
                                    setState(() {
                                      _requestedMinKm = val;
                                    });
                                  },
                                ),
                                Text(
                                  'Standardní limit je 3,0 km.',
                                  style: GoogleFonts.libreFranklin(
                                    fontSize: 11,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Submit Button
                                SizedBox(
                                  width: double.infinity,
                                  child: AppButton(
                                    onPressed: _isSubmitting ? null : _submitRequest,
                                    text: _isSubmitting ? 'Odesílání...' : 'Odeslat žádost',
                                    icon: Icons.send_rounded,
                                    type: AppButtonType.primary,
                                    size: AppButtonSize.medium,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ] else ...[
                        WebMobileSectionCard(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Máte aktivní nevyřízenou žádost. Před odesláním nové vyčkejte na rozhodnutí administrátora.',
                                  style: GoogleFonts.libreFranklin(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.orange[800],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // History header
                      if (_requests.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 8),
                          child: Text(
                            'Historie žádostí',
                            style: GoogleFonts.libreFranklin(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),

                        // Request list
                        ..._requests.map((req) => _buildRequestCard(req)),
                      ] else
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Text(
                              'Zatím jste nepožádali o žádnou výjimku.',
                              style: GoogleFonts.libreFranklin(
                                fontSize: 13,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildRequestCard(ExceptionRequest req) {
    Color statusColor = Colors.orange;
    String statusText = 'Čeká na vyřízení';
    IconData statusIcon = Icons.hourglass_empty_rounded;

    if (req.status == ExceptionStatus.approved) {
      statusColor = Colors.green;
      statusText = 'Schváleno';
      statusIcon = Icons.check_circle_outline_rounded;
    } else if (req.status == ExceptionStatus.rejected) {
      statusColor = Colors.red;
      statusText = 'Zamítnuto';
      statusIcon = Icons.highlight_off_rounded;
    }

    final dateStr = DateFormat('d. M. yyyy HH:mm').format(req.createdAt);

    return WebMobileSectionCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: statusColor.withOpacity(0.24)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: GoogleFonts.libreFranklin(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                dateStr,
                style: GoogleFonts.libreFranklin(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          RichText(
            text: TextSpan(
              style: GoogleFonts.libreFranklin(color: AppColors.textPrimary, fontSize: 13),
              children: [
                const TextSpan(text: 'Požadovaný limit: ', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: '${req.requestedMinKm.toStringAsFixed(1)} km', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          
          Text(
            req.reason,
            style: GoogleFonts.libreFranklin(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),

          if (req.adminResponse != null && req.adminResponse!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vyjádření administrátora:',
                    style: GoogleFonts.libreFranklin(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    req.adminResponse!,
                    style: GoogleFonts.libreFranklin(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
