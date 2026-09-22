class UserModel {
  final int? id;
  final String username;
  final String role;
  final String? fullName;
  final String? email;
  final String? avatarUrl;
  final String? bio;
  final String? createdAt;

  const UserModel({
    this.id,
    required this.username,
    this.role = 'admin',
    this.fullName,
    this.email,
    this.avatarUrl,
    this.bio,
    this.createdAt,
  });

  UserModel copyWith({
    int? id,
    String? username,
    String? role,
    String? fullName,
    String? email,
    String? avatarUrl,
    String? bio,
    String? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      role: role ?? this.role,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? ''),
      username: json['username'] as String? ?? 'admin',
      role: json['role'] as String? ?? 'admin',
      fullName: json['full_name'] as String? ?? json['fullName'] as String?,
      email: json['email'] as String?,
      avatarUrl: json['avatar_url'] as String? ?? json['avatarUrl'] as String?,
      bio: json['bio'] as String?,
      createdAt: json['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'role': role,
      'full_name': fullName,
      'email': email,
      'avatar_url': avatarUrl,
      'bio': bio,
      'created_at': createdAt,
    };
  }
}
