import 'package:flutter/material.dart';
import '../../config/admin_theme.dart';
import '../../widgets/admin/admin_page_template.dart';
import '../../widgets/admin/admin_cards.dart';
import '../../widgets/admin/admin_common_widgets.dart';

import '../../models/news_item.dart';
import '../../repositories/news_repository.dart';

class AdminNewsListPage extends StatefulWidget {
  const AdminNewsListPage({super.key});

  @override
  State<AdminNewsListPage> createState() => _AdminNewsListPageState();
}

class _AdminNewsListPageState extends State<AdminNewsListPage> {
  final NewsRepository _repository = NewsRepository();
  List<NewsItem> _news = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadNews();
  }

  Future<void> _loadNews() async {
    setState(() => _isLoading = true);
    final result = await _repository.getNews(searchQuery: _searchQuery);
    if (mounted) {
      setState(() {
        _news = (result['data'] as List).cast<NewsItem>();
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteNews(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Smazat novinku?'),
        content: const Text('Opravdu chcete tuto novinku nenávratně smazat?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Zrušit')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Smazat'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _repository.deleteNews(id);
      _loadNews();
    }
  }

  void _showNewsDialog([NewsItem? item]) {
    final titleController = TextEditingController(text: item?.title);
    final contentController = TextEditingController(text: item?.content);
    final imageController = TextEditingController(text: item?.imageUrl);
    final tagsController = TextEditingController(text: item?.tags.join(', '));
    NewsStatus status = item?.status ?? NewsStatus.DRAFT;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(item == null ? 'Nová novinka' : 'Upravit novinku'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Titulek'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: contentController,
                    decoration: const InputDecoration(labelText: 'Obsah'),
                    maxLines: 5,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: imageController,
                    decoration: const InputDecoration(labelText: 'URL obrázku (volitelné)'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: tagsController,
                    decoration: const InputDecoration(labelText: 'Štítky (oddělené čárkou)'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<NewsStatus>(
                    value: status,
                    decoration: const InputDecoration(labelText: 'Stav'),
                    items: NewsStatus.values.map((s) {
                      return DropdownMenuItem(value: s, child: Text(s.name));
                    }).toList(),
                    onChanged: (val) => setState(() => status = val!),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Zrušit')),
              ElevatedButton(
                onPressed: () async {
                  final tagsList = tagsController.text
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList();

                  final newItem = NewsItem(
                    id: item?.id ?? '',
                    title: titleController.text,
                    content: contentController.text,
                    status: status,
                    createdAt: item?.createdAt ?? DateTime.now(),
                    publishDate: status == NewsStatus.PUBLISHED ? (item?.publishDate ?? DateTime.now()) : null,
                    imageUrl: imageController.text.isNotEmpty ? imageController.text : null,
                    tags: tagsList,
                  );
                  await _repository.saveNews(newItem);
                  if (mounted) Navigator.pop(context);
                  _loadNews();
                },
                child: const Text('Uložit'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageTemplate(
      title: const Text('NOVINKY', style: AdminTextStyles.display),
      subtitle: const Text('Správa aktualit a oznámení', style: AdminTextStyles.body),
      icon: Icon(Icons.article_rounded, color: AdminColors.indigo500),
      // ... actions ... (same as before)
      actions: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AdminSpacing.sm),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Hledat v novinkách...',
                hintStyle: AdminTextStyles.small,
                border: InputBorder.none,
                icon: const Icon(Icons.search, size: 18, color: AdminColors.zinc400),
              ),
              onChanged: (val) {
                _searchQuery = val;
                _loadNews();
              },
            ),
          ),
        ),
        AppButton(
          label: 'Nová novinka',
          onPressed: () => _showNewsDialog(),
          variant: AppButtonVariant.primary,
          size: AppButtonSize.sm,
          icon: Icons.add,
        ),
        const SizedBox(width: AdminSpacing.xs),
      ],
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = constraints.maxWidth < 600 ? 1 : (constraints.maxWidth < 900 ? 2 : 3);
                return GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: AdminSpacing.lg,
                    crossAxisSpacing: AdminSpacing.lg,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: _news.length,
                  itemBuilder: (context, index) {
                    final news = _news[index];
                    return NewsCard(
                      title: news.title,
                      date: news.publishDate != null 
                          ? '${news.publishDate!.day}. ${news.publishDate!.month}. ${news.publishDate!.year}' 
                          : 'Koncept',
                      content: news.content,
                      imageUrl: news.imageUrl,
                      badge: news.status == NewsStatus.PUBLISHED 
                          ? StatusBadge.published() 
                          : StatusBadge.draft(),
                      actions: [
                        AppButton(
                          label: 'Upravit',
                          onPressed: () => _showNewsDialog(news),
                          variant: AppButtonVariant.ghost,
                          size: AppButtonSize.sm,
                          icon: Icons.edit,
                        ),
                        const SizedBox(width: AdminSpacing.sm),
                        AppButton(
                          label: 'Smazat',
                          onPressed: () => _deleteNews(news.id),
                          variant: AppButtonVariant.destructive,
                          size: AppButtonSize.sm,
                          icon: Icons.delete_outline,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }
}
