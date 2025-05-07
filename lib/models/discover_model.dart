class DiscoverPost {
  final int id;
  final String title;
  final String description;
  final String imageUrl;
  final double price;
  final String shopName;
  final int sales;
  final int likes;
  final int comments;

  DiscoverPost({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.price,
    required this.shopName,
    required this.sales,
    required this.likes,
    required this.comments,
  });

  factory DiscoverPost.fromJson(Map<String, dynamic> json) {
    return DiscoverPost(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String,
      imageUrl: json['imageUrl'] as String,
      price: (json['price'] as num).toDouble(),
      shopName: json['shopName'] as String,
      sales: json['sales'] as int,
      likes: json['likes'] as int,
      comments: json['comments'] as int,
    );
  }
}