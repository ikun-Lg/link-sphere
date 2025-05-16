class SearchUser {
  final String id;
  final String username;
  final String email;
  final String phone;
  final String lastLoginTimi;
  final int followCount;
  final int followerCount;
  final int favoriteCount;
  final int age;
  final String bio;
  final String avatarUrl;
  final bool follow;

  SearchUser({
    required this.id,
    required this.username,
    required this.email,
    required this.phone,
    required this.lastLoginTimi,
    required this.followCount,
    required this.followerCount,
    required this.favoriteCount,
    required this.age,
    required this.bio,
    required this.avatarUrl,
    required this.follow,
  });

  factory SearchUser.fromJson(Map<String, dynamic> json) {
    return SearchUser(
      id: json['id']?.toString() ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      lastLoginTimi: json['lastLoginTimi'] ?? '',
      followCount: json['followCount'] is int ? json['followCount'] : int.tryParse(json['followCount']?.toString() ?? '0') ?? 0,
      followerCount: json['followerCount'] is int ? json['followerCount'] : int.tryParse(json['followerCount']?.toString() ?? '0') ?? 0,
      favoriteCount: json['favoriteCount'] is int ? json['favoriteCount'] : int.tryParse(json['favoriteCount']?.toString() ?? '0') ?? 0,
      age: json['age'] is int ? json['age'] : int.tryParse(json['age']?.toString() ?? '0') ?? 0,
      bio: json['bio'] ?? '',
      avatarUrl: json['avatarUrl']?.toString().replaceAll('`', '').trim() ?? '',
      follow: json['follow'] is bool ? json['follow'] : json['follow'] == 'true' || json['follow'] == 1,
    );
  }
}