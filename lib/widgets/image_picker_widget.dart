import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../models/forms/form_image_attachment.dart';
import '../services/auth_service.dart';
import '../widgets/ui/app_toast.dart';

class ImagePickerWidget extends StatefulWidget {
  final void Function(List<FormImageAttachment>) onImagesSelected;
  final List<FormImageAttachment> initialAttachments;
  final int? maxImages;
  final String title;
  final bool allowAdminTestPhoto;

  const ImagePickerWidget({
    Key? key,
    required this.onImagesSelected,
    this.initialAttachments = const [],
    this.maxImages,
    this.title = 'Přidat fotografie',
    this.allowAdminTestPhoto = false,
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
    if (!_isInitialized) {
      AppToast.showInfo(
        context,
        'Obrázkový výběr se ještě inicializuje. Zkuste to za chvíli znovu.',
      );
      return;
    }

    try {
      await Future.delayed(const Duration(milliseconds: 200));
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
        requestFullMetadata: false,
      );

      if (images.isNotEmpty) {
        final newFiles = images.map((x) => FormImageAttachment(File(x.path))).toList();
        if (widget.maxImages != null && _items.length + newFiles.length > widget.maxImages!) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Můžete přidat maximálně ${widget.maxImages} fotografií'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        setState(() {
          _items = [..._items, ...newFiles];
        });
        _emit();
      }
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
    if (!_isInitialized) {
      AppToast.showInfo(
        context,
        'Obrázkový výběr se ještě inicializuje. Zkuste to za chvíli znovu.',
      );
      return;
    }

    try {
      await Future.delayed(const Duration(milliseconds: 200));
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
        requestFullMetadata: false,
      );

      if (photo != null) {
        if (widget.maxImages != null && _items.length >= widget.maxImages!) {
          if (mounted) {
            AppToast.showInfo(
              context,
              'Můžete přidat maximálně ${widget.maxImages} fotografií',
            );
          }
          return;
        }

        setState(() {
          _items = [..._items, FormImageAttachment(File(photo.path))];
        });
        _emit();
      }
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

  void _removeImage(int index) {
    setState(() {
      _items.removeAt(index);
    });
    _emit();
  }

  void _handleAddPhoto() {
    _showImageSourceDialog();
  }

  void _showImageSourceDialog() {
    if (!_isInitialized) {
      AppToast.showInfo(
        context,
        'Obrázkový výběr se inicializuje. Zkuste to za chvíli znovu.',
        actionLabel: 'Zkusit znovu',
        onAction: () {
          _initializePicker();
        },
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Vybrat z galerie'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImages();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Pořídit fotografii'),
                onTap: () {
                  Navigator.pop(context);
                  _takePhoto();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(
                  Icons.photo_library_outlined,
                  color: Color(0xFF111827),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                        ),
                      ),
                      if (_items.isNotEmpty)
                        Text(
                          '${_items.length} fotografií',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _isInitialized ? _handleAddPhoto : null,
                  icon: _isInitialized
                      ? const Icon(
                          Icons.add_photo_alternate_outlined,
                          color: Color(0xFF111827),
                        )
                      : const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                ),
              ],
            ),
          ),
          if (_isAdmin) ...[
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Align(
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
            ),
          ],
          if (_items.isNotEmpty) ...[
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            Container(
              height: 120,
              padding: const EdgeInsets.all(12),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final f = _items[index].file;
                  return Container(
                    margin: const EdgeInsets.only(right: 10),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            f,
                            width: 100,
                            height: 120,
                            fit: BoxFit.cover,
                          ),
                        ),
                        if (_items[index].adminBypassPhotoDate)
                          Positioned(
                            bottom: 4,
                            left: 4,
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
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _removeImage(index),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
