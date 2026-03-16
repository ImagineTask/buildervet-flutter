class CustomTileModel {
  final String id;
  final String projectId;
  final String name;
  final String tileType; // 'external' | 'internal_project'
  final String? url; // for external links
  final String? linkedProjectId; // for internal project links
  final String iconType; // 'preset' | 'emoji' | 'image'
  final String iconValue;
  final String color;
  final DateTime createdAt;

  CustomTileModel({
    required this.id,
    required this.projectId,
    required this.name,
    required this.tileType,
    this.url,
    this.linkedProjectId,
    required this.iconType,
    required this.iconValue,
    required this.color,
    required this.createdAt,
  });

  factory CustomTileModel.fromMap(String id, Map<String, dynamic> data) {
    return CustomTileModel(
      id: id,
      projectId: data['projectId'] ?? '',
      name: data['name'] ?? '',
      tileType: data['tileType'] ?? 'external',
      url: data['url'],
      linkedProjectId: data['linkedProjectId'],
      iconType: data['iconType'] ?? 'preset',
      iconValue: data['iconValue'] ?? 'language',
      color: data['color'] ?? '#6C63FF',
      createdAt: data['createdAt'] != null
          ? DateTime.parse(data['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'projectId': projectId,
      'name': name,
      'tileType': tileType,
      'url': url,
      'linkedProjectId': linkedProjectId,
      'iconType': iconType,
      'iconValue': iconValue,
      'color': color,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
