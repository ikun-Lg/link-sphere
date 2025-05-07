class User {
  final int id; // Dart 模型中使用 id
  final String username;
  final String token;
  final int age;
  final String bio;
  final String avatarUrl;
  final int followerCount;
  final int followCount;
  final int favoriteCount;

  User({
    required this.id,
    required this.username,
    required this.token,
    required this.age,
    required this.bio,
    required this.avatarUrl,
    required this.followerCount,
    required this.followCount,
    required this.favoriteCount,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      // 从 JSON 解析时，将 'userId' 映射到模型的 'id'
      id: json['userId'] as int? ?? 0,
      username: json['username'] as String? ?? '',
      token: json['token'] as String? ?? '',
      age: json['age'] as int? ?? 0,
      bio: json['bio'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String? ?? '',
      followerCount: json['followerCount'] as int? ?? 0,
      followCount: json['followCount'] as int? ?? 0,
      favoriteCount: json['favoriteCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      // 序列化为 JSON 时，将模型的 'id' 映射回 'userId'
      'userId': id,
      'username': username,
      'token': token,
      'age': age,
      'bio': bio,
      'avatarUrl': avatarUrl,
      'followerCount': followerCount,
      'followCount': followCount,
      'favoriteCount': favoriteCount,
    };
  }
}