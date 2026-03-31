enum NewsStatus {
  DRAFT,
  PUBLISHED,
  ARCHIVED,
}

class NewsItem {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? publishDate;
  final NewsStatus status;
  final String? authorId;
  final String? imageUrl;
  final List<String> tags;

  const NewsItem({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    this.updatedAt,
    this.publishDate,
    this.status = NewsStatus.DRAFT,
    this.authorId,
    this.imageUrl,
    this.tags = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      '_id': id,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'publishDate': publishDate?.toIso8601String(),
      'status': status.name,
      'authorId': authorId,
      'imageUrl': imageUrl,
      'tags': tags,
    };
  }

  factory NewsItem.fromMap(Map<String, dynamic> map) {
    try {
      return NewsItem(
        id: map['_id'] != null ? map['_id'].toString() : (map['id']?.toString() ?? ''),
        title: map['title']?.toString() ?? 'Bez názvu',
        content: map['content']?.toString() ?? '',
        createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
        updatedAt: map['updatedAt'] != null ? DateTime.tryParse(map['updatedAt'].toString()) : null,
        publishDate: map['publishDate'] != null ? DateTime.tryParse(map['publishDate'].toString()) : null,
        status: NewsStatus.values.firstWhere(
          (e) => e.name == map['status'],
          orElse: () => NewsStatus.DRAFT,
        ),
        authorId: map['authorId']?.toString(),
        imageUrl: map['imageUrl']?.toString(),
        tags: (map['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      );
    } catch (e) {
      print('❌ Error parsing NewsItem: $e');
      return NewsItem(
        id: map['_id']?.toString() ?? 'error',
        title: 'Error parsing news',
        content: '',
        createdAt: DateTime.now(),
      );
    }
  }

  NewsItem copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? publishDate,
    NewsStatus? status,
    String? authorId,
    String? imageUrl,
    List<String>? tags,
  }) {
    return NewsItem(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      publishDate: publishDate ?? this.publishDate,
      status: status ?? this.status,
      authorId: authorId ?? this.authorId,
      imageUrl: imageUrl ?? this.imageUrl,
      tags: tags ?? this.tags,
    );
  }
}
