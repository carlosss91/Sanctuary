class RepoLinkModel {
  final int? id;
  final String title;
  final String url;
  final String description;
  final String category;
  final String iconName;

  const RepoLinkModel({
    this.id,
    required this.title,
    required this.url,
    this.description = '',
    this.category = 'General',
    this.iconName = 'code',
  });

  factory RepoLinkModel.fromJson(Map<String, dynamic> json) {
    return RepoLinkModel(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? ''),
      title: json['title'] as String? ?? '',
      url: json['url'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'General',
      iconName: json['icon_name'] as String? ?? 'code',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'url': url,
      'description': description,
      'category': category,
      'icon_name': iconName,
    };
  }
}
