class Post {
  final int id;
  final int authorId;
  final String authorName;
  final String authorAvatar;
  final String title;
  final String content;
  final String images;
  final int likesCount;
  final int collectCount;
  final int commentsCount;
  final int sharesCount;
  final int viewsCount;
  final int isSticky;
  final bool liked; // 添加 liked 字段

  Post({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    required this.title,
    required this.content,
    required this.images,
    required this.likesCount,
    required this.collectCount,
    required this.commentsCount,
    required this.sharesCount,
    required this.viewsCount,
    required this.isSticky,
    required this.liked, // 添加 liked 到构造函数
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: int.parse(json['id'].toString()),
      authorId: int.parse(json['authorId'].toString()),
      authorName: json['authorName'] ?? '',
      authorAvatar: json['authorAvatar'] ?? '',
      title: json['title'] ?? '',
      content: json['text'] ?? json['content'] ?? '',  // 处理两种可能的字段名
      images: json['images'] ?? '',
      likesCount: int.parse((json['likesCount'] ?? 0).toString()),
      collectCount: int.parse((json['collectCount'] ?? 0).toString()),
      commentsCount: int.parse((json['commentsCount'] ?? 0).toString()),
      sharesCount: int.parse((json['sharesCount'] ?? 0).toString()),
      viewsCount: int.parse((json['viewsCount'] ?? 0).toString()),
      isSticky: int.parse((json['isSticky'] ?? 0).toString()),
      liked: json['liked'] ?? false, // 解析 liked 字段，默认为 false
    );
  }
}