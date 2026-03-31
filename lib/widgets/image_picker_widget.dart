import 'package:flutter/material.dart';

import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../widgets/ui/app_toast.dart';

class ImagePickerWidget extends StatefulWidget {
  final Function(List<File>) onImagesSelected;
  final List<File> initialImages;
  final int? maxImages; // null = unlimited
  final String title;

  const ImagePickerWidget({
    Key? key,
    required this.onImagesSelected,
    this.initialImages = const [],
    this.maxImages,
    this.title = 'Přidat fotografie',
  }) : super(key: key);

  @override
  State<ImagePickerWidget> createState() => _ImagePickerWidgetState();
}

class _ImagePickerWidgetState extends State<ImagePickerWidget> {
  List<File> _selectedImages = [];
  late ImagePicker _picker;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _selectedImages = List.from(widget.initialImages);
    _initializePicker();
  }

  Future<void> _initializePicker() async {
    int retryCount = 0;
    const maxRetries = 5;
    
    while (retryCount < maxRetries) {
      try {
        _picker = ImagePicker();
        
        // Test the picker with a simple operation
        await Future.delayed(const Duration(milliseconds: 300));
        
        // Try to access the picker to ensure it's properly initialized
        try {
          // This is a test call to ensure the platform channel is working
          await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1, maxHeight: 1);
        } catch (e) {
          // This is expected to fail, but it tests the channel connection
          // debugPrint('Channel test completed');
        }
        
        setState(() {
          _isInitialized = true;
        });
        return;
      } catch (e) {
        debugPrint('Failed to initialize image picker (attempt ${retryCount + 1}): $e');
        retryCount++;
        if (retryCount < maxRetries) {
          await Future.delayed(Duration(milliseconds: 1000 * retryCount));
        }
      }
    }
    
    // If all retries failed, try a simpler approach
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

  // Check if running on emulator - logic removed but method kept if needed later, or remove entirely.
  // Method _isEmulator removed as it was unused.

  Future<void> _handleAddPhoto() async {
    _showImageSourceDialog();
  }
  
  // Method _reinitializePicker removed as it was unused.

  Future<void> _pickImages() async {
    if (!_isInitialized) {
      AppToast.showInfo(context, 'Obrázkový výběr se ještě inicializuje. Zkuste to za chvíli znovu.');
      return;
    }

    try {
      // Add a longer delay to ensure the platform channel is ready
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Try multiple images directly first
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        final List<File> newImages = images.map((xFile) => File(xFile.path)).toList();
        
        // If a max is set, enforce it; otherwise allow unlimited
        if (widget.maxImages != null && _selectedImages.length + newImages.length > widget.maxImages!) {
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
          _selectedImages.addAll(newImages);
        });
        
        widget.onImagesSelected(_selectedImages);
      }
    } catch (e) {
      debugPrint('Image picker error: $e');
      
      // If multi-image fails, try single image as fallback
      try {
        final XFile? singleImage = await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 85,
        );

        if (singleImage != null) {
          if (widget.maxImages != null && _selectedImages.length >= widget.maxImages!) {
            if (mounted) {
              AppToast.showInfo(context, 'Můžete přidat maximálně ${widget.maxImages} fotografií');
            }
            return;
          }

          setState(() {
            _selectedImages.add(File(singleImage.path));
          });
          
          widget.onImagesSelected(_selectedImages);
          
          if (mounted) {
            AppToast.showInfo(context, 'Přidána jedna fotografie. Pro více fotek zkuste znovu.');
          }
        }
      } catch (fallbackError) {
        debugPrint('Fallback image picker also failed: $fallbackError');
        
        // Final fallback: Show manual file picker dialog
        if (mounted) {
          _showManualFilePicker();
        }
      }
    }
  }

  // Manual file picker as ultimate fallback
  void _showManualFilePicker() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Problém s výběrem obrázků'),
          content: const Text(
            'Image picker nefunguje na tomto emulátoru. '
            'Zkuste:\n\n'
            '1. Restartovat emulátor\n'
            '2. Použít fyzické zařízení\n'
            '3. Použít jiný emulátor\n\n'
            'Pro testování můžete pokračovat bez fotek.'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Dobře'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _takePhoto() async {
    if (!_isInitialized) {
      AppToast.showInfo(context, 'Obrázkový výběr se ještě inicializuje. Zkuste to za chvíli znovu.');
      return;
    }

    try {
      // Add a longer delay to ensure the platform channel is ready
      await Future.delayed(const Duration(milliseconds: 500));
      
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (photo != null) {
        if (widget.maxImages != null && _selectedImages.length >= widget.maxImages!) {
            if (mounted) {
              AppToast.showInfo(context, 'Můžete přidat maximálně ${widget.maxImages} fotografií');
            }
          return;
        }

        setState(() {
          _selectedImages.add(File(photo.path));
        });
        
        widget.onImagesSelected(_selectedImages);
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
      _selectedImages.removeAt(index);
    });
    widget.onImagesSelected(_selectedImages);
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
                onTap: () { Navigator.pop(context); _pickImages(); },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Pořídit fotografii'),
                onTap: () { Navigator.pop(context); _takePhoto(); },
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
                const Icon(Icons.photo_library_outlined, color: Color(0xFF111827), size: 20),
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
                      if (_selectedImages.isNotEmpty)
                        Text(
                          '${_selectedImages.length} fotografií',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _isInitialized ? _handleAddPhoto : null,
                  icon: _isInitialized
                      ? const Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF111827))
                      : const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              ],
            ),
          ),
          if (_selectedImages.isNotEmpty) ...[
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            Container(
              height: 120,
              padding: const EdgeInsets.all(12),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedImages.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.only(right: 10),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            _selectedImages[index],
                            width: 100,
                            height: 120,
                            fit: BoxFit.cover,
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