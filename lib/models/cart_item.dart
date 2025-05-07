class CartItem {
  final int id; // 购物车项 ID
  final int productId;
  final int quantity;
  final double price;
  final String image;
  final String productName;
  final String desc;

  CartItem({
    required this.id,
    required this.productId,
    required this.quantity,
    required this.price,
    required this.image,
    required this.productName,
    required this.desc,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'] ?? 0,
      productId: json['productId'] ?? 0,
      quantity: json['quantity'] ?? 0,
      // 价格可能是 int 或 double，进行转换
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      image: json['image'] ?? '',
      productName: json['productName'] ?? '',
      desc: json['desc'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productId': productId,
      'quantity': quantity,
      'price': price,
      'image': image,
      'productName': productName,
      'desc': desc,
    };
  }
}