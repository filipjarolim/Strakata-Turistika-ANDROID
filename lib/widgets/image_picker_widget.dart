import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../config/app_colors.dart';
import '../models/forms/form_image_attachment.dart';
import '../services/auth_service.dart';
import '../widgets/photo_viewer.dart';
import '../widgets/ui/app_toast.dart';

class ImagePickerWidget extends StatefulWidget {
  final void Function(List<FormImageAttachment>) onImagesSelected;
  final List<FormImageAttachment> initialAttachments;
  final int? maxImages;
  final String title;
  final bool allowAdminTestPhoto;
  /// Když je uvnitř [FormSectionCard], vynechá vnější rámeček a duplicitní titulek.
  final bool embedded;

  const ImagePickerWidget({
    Key? key,
    required this.onImagesSelected,
    this.initialAttachments = const [],
    this.maxImages,
    this.title = 'Přidat fotografie',
    this.allowAdminTestPhoto = false,
    this.embedded = false,
  }) : super(key: key);

  @override
  State<ImagePickerWidget> createState() => _ImagePickerWidgetState();
}

class _ImagePickerWidgetState extends State<ImagePickerWidget> {
  List<FormImageAttachment> _items = [];
  late ImagePicker _picker;
  bool _isInitialized = false;
  bool _adminTestLoading = false;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.initialAttachments);
    _initializePicker();
  }

  @override
  void didUpdateWidget(ImagePickerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialAttachments != widget.initialAttachments &&
        widget.initialAttachments.length != _items.length) {
      _items = List.from(widget.initialAttachments);
    }
  }

  Future<void> _initializePicker() async {
    try {
      _picker = ImagePicker();
      setState(() {
        _isInitialized = true;
      });
      return;
    } catch (e) {
      debugPrint('Final initialization attempt failed: $e');
    }

    setState(() {
      _isInitialized = false;
    });

    if (mounted) {
      AppToast.showError(
        context,
        'Nepodařilo se inicializovat obrázkový výběr. Zkuste restartovat aplikaci.',
        actionLabel: 'Zkusit znovu',
        onAction: () => _initializePicker(),
      );
    }
  }

  bool get _isAdmin =>
      widget.allowAdminTestPhoto && (AuthService.currentUser?.role ?? '') == 'ADMIN';

  bool get _atLimit =>
      widget.maxImages != null && _items.length >= widget.maxImages!;

  void _emit() => widget.onImagesSelected(_items);

  Future<void> _addAdminTestPhoto() async {
    if (!_isAdmin || _adminTestLoading) return;
    setState(() => _adminTestLoading = true);
    try {
      final client = http.Client();
      final res = await client.get(Uri.parse('https://picsum.photos/800/600'));
      client.close();
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('HTTP ${res.statusCode}');
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/test-admin-photo-${DateTime.now().millisecondsSinceEpoch}.jpg');
      await file.writeAsBytes(res.bodyBytes, flush: true);
      if (widget.maxImages != null && _items.length >= widget.maxImages!) {
        if (mounted) {
          AppToast.showInfo(context, 'Můžete přidat maximálně ${widget.maxImages} fotografií');
        }
        return;
      }
      setState(() {
        _items = [..._items, FormImageAttachment(file, adminBypassPhotoDate: true)];
      });
      _emit();
    } catch (e) {
      debugPrint('Admin test photo: $e');
      if (mounted) {
        AppToast.showError(context, 'Testovací fotku se nepodařilo stáhnout.');
      }
    } finally {
      if (mounted) setState(() => _adminTestLoading = false);
    }
  }

  Future<void> _pickImages() async {
    if (!_ensureReady()) return;

    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 2560,
        maxHeight: 2560,
        imageQuality: 90,
        requestFullMetadata: false,
      );

      if (images.isEmpty) return;
      _appendFiles(images.map((x) => File(x.path)).toList());
    } catch (e) {
      debugPrint('Image picker error: $e');
      if (mounted) {
        AppToast.showError(
          context,
          'Výběr fotografií selhal. Zkuste to prosím znovu.',
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    if (!_ensureReady()) return;

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 2560,
        maxHeight: 2560,
        imageQuality: 90,
        requestFullMetadata: false,
      );

      if (photo == null) return;
      _appendFiles([File(photo.path)]);
    } catch (e) {
      debugPrint('Camera error: $e');
      if (mounted) {
        AppToast.showError(
          context,
          'Chyba při pořizování fotografie. Zkuste to znovu.',
          actionLabel: 'Zkusit znovu',
          onAction: () => _takePhoto(),
        );
      }
    }
  }

  bool _ensureReady() {
    if (_isInitialized) return true;
    AppToast.showInfo(
      context,
      'Obrázkový výběr se ještě inicializuje. Zkuste to za chvíli znovu.',
    );
    return false;
  }

  void _appendFiles(List<File> files) {
    if (files.isEmpty) return;
    if (widget.maxImages != null && _items.length + files.length > widget.maxImages!) {
      final remaining = widget.maxImages! - _items.length;
      if (remaining <= 0) {
        AppToast.showInfo(context, 'Můžete přidat maximálně ${widget.maxImages} fotografií');
        return;
      }
      files = files.take(remaining).toList();
      AppToast.showInfo(context, 'Přidáno jen $remaining fotek (limit ${widget.maxImages}).');
    }

    setState(() {
      _items = [..._items, ...files.map((f) => FormImageAttachment(f))];
    });
    _emit();
  }

  void _removeImage(int index) {
    setState(() {
      _items.removeAt(index);
    });
    _emit();
  }

  void _openViewer(int index) {
    showPhotoViewer(
      context,
      images: _items.map((e) => FileImage(e.file)).toList(),
      initialIndex: index,
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.embedded) ...[
          Row(
            children: [
              const Icon(Icons.photo_library_outlined, color: Color(0xFF111827), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: GoogleFonts.libreFranklin(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    Text(
                      _items.isEmpty
                          ? 'Galerie nebo fotoaparát'
                          : '${_items.length} ${_photoCountLabel(_items.length)}',
                      style: GoogleFonts.libreFranklin(
                        fontSize: 12,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        _UploadDropzone(
          enabled: _isInitialized && !_atLimit,
          loading: !_isInitialized,
          atLimit: _atLimit,
          maxImages: widget.maxImages,
          onGallery: _pickImages,
          onCamera: _takePhoto,
        ),
        if (_isAdmin) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _adminTestLoading ? null : _addAdminTestPhoto,
              icon: _adminTestLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.science_outlined, size: 18),
              label: Text(_adminTestLoading ? 'Stahuji…' : 'Nahrát testovací fotku (Admin)'),
            ),
          ),
        ],
        if (_items.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            'Nahrané fotografie',
            style: GoogleFonts.libreFranklin(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              final item = _items[index];
              return Stack(
                fit: StackFit.expand,
                children: [
                  PhotoThumb(
                    url: item.file.path,
                    onTap: () => _openViewer(index),
                    onRemove: () => _removeImage(index),
                  ),
                  if (item.adminBypassPhotoDate)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade700.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Admin test',
                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ],
    );

    if (widget.embedded) return body;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: body,
    );
  }

  String _photoCountLabel(int n) {
    if (n == 1) return 'fotografie';
    if (n >= 2 && n <= 4) return 'fotografie';
    return 'fotografií';
  }
}

class _UploadDropzone extends StatelessWidget {
  const _UploadDropzone({
    required this.enabled,
    required this.loading,
    required this.atLimit,
    required this.maxImages,
    required this.onGallery,
    required this.onCamera,
  });

  final bool enabled;
  final bool loading;
  final bool atLimit;
  final int? maxImages;
  final VoidCallback onGallery;
  final VoidCallback onCamera;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F4EE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E4DC), width: 1.4),
      ),
      child: Column(
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 36,
            color: atLimit ? const Color(0xFF9CA3AF) : AppColors.textSecondary,
          ),
          const SizedBox(height: 8),
          Text(
            atLimit
                ? 'Limit ${maxImages ?? 0} fotek je naplněný'
                : 'Přidejte fotky jako důkaz výpravy',
            textAlign: TextAlign.center,
            style: GoogleFonts.libreFranklin(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Klepnutím na náhled je později zvětšíte.',
            textAlign: TextAlign.center,
            style: GoogleFonts.libreFranklin(
              fontSize: 12,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 14),
          if (loading)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: enabled ? onGallery : null,
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('Galerie'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: Color(0xFFD6D0C6)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: enabled ? onCamera : null,
                    icon: const Icon(Icons.photo_camera_outlined, size: 18),
                    label: const Text('Fotoaparát'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
