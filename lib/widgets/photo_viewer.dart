import 'dart:io';

import 'package:flutter/material.dart';

/// Celoobrazovkový prohlížeč fotek (síť + lokální soubory).
void showPhotoViewer(
  BuildContext context, {
  required List<ImageProvider> images,
  int initialIndex = 0,
}) {
  if (images.isEmpty) return;
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _PhotoViewerPage(
        images: images,
        initialIndex: initialIndex.clamp(0, images.length - 1),
      ),
    ),
  );
}

ImageProvider photoProviderFromUrl(String url) {
  if (url.startsWith('http://') || url.startsWith('https://')) {
    return NetworkImage(url);
  }
  return FileImage(File(url));
}

class PhotoGrid extends StatelessWidget {
  const PhotoGrid({
    super.key,
    required this.urls,
    this.aspectRatio = 1,
    this.crossAxisCount = 2,
  });

  final List<String> urls;
  final double aspectRatio;
  final int crossAxisCount;

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: urls.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: aspectRatio,
      ),
      itemBuilder: (context, index) {
        return PhotoThumb(
          url: urls[index],
          onTap: () => showPhotoViewer(
            context,
            images: urls.map(photoProviderFromUrl).toList(),
            initialIndex: index,
          ),
        );
      },
    );
  }
}

class PhotoThumb extends StatelessWidget {
  const PhotoThumb({
    super.key,
    required this.url,
    this.onTap,
    this.onRemove,
    this.width,
    this.height,
    this.borderRadius = 12,
  });

  final String url;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final double? width;
  final double? height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final isNetwork = url.startsWith('http://') || url.startsWith('https://');
    final image = isNetwork
        ? Image.network(
            url,
            width: width,
            height: height,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                width: width,
                height: height,
                color: const Color(0xFFF0EBE3),
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            },
            errorBuilder: (_, __, ___) => _broken(width, height),
          )
        : Image.file(
            File(url),
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _broken(width, height),
          );

    Widget thumb = GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: image,
          ),
          if (onRemove != null)
            Positioned(
              top: 6,
              right: 6,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.62),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 15),
                ),
              ),
            ),
        ],
      ),
    );

    if (width != null || height != null) {
      thumb = SizedBox(width: width, height: height, child: thumb);
    }
    return thumb;
  }

  Widget _broken(double? w, double? h) {
    return Container(
      width: w,
      height: h,
      color: const Color(0xFFF0EBE3),
      alignment: Alignment.center,
      child: const Icon(Icons.broken_image_outlined, color: Color(0xFF9CA3AF)),
    );
  }
}

class _PhotoViewerPage extends StatefulWidget {
  const _PhotoViewerPage({
    required this.images,
    required this.initialIndex,
  });

  final List<ImageProvider> images;
  final int initialIndex;

  @override
  State<_PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<_PhotoViewerPage> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.images.length > 1
              ? '${_index + 1} / ${widget.images.length}'
              : 'Fotografie',
        ),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) {
          return InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Center(
              child: Image(
                image: widget.images[i],
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white54,
                  size: 48,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
