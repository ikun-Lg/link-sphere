class CartItem {
  final String id; // 修改：购物车项 ID 为 String 类型
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
    // 对每个字段进行严格的类型检查和转换
    return CartItem(
      // id 修改：直接使用 String 类型
      id: (json['id'] is String) ? json['id'] : (json['id']?.toString() ?? '0'),
      // productId 转换
      productId: _convertToInt(json['productId'], 0),
      // quantity 转换
      quantity: _convertToInt(json['quantity'], 0),
      // price 转换
      price: _convertToDouble(json['price'], 0.0),
      // 字符串字段
      image: json['image'] is String ? json['image'] : '',
      productName: json['productName'] is String ? json['productName'] : '',
      desc: json['desc'] is String ? json['desc'] : '',
    );
  }

  // 辅助方法：将值转换为整数
  static int _convertToInt(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value) ?? defaultValue;
    }
    if (value is num) return value.toInt();
    return defaultValue;
  }

  // 辅助方法：将值转换为浮点数
  static double _convertToDouble(dynamic value, double defaultValue) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is String) {
      return double.tryParse(value) ?? defaultValue;
    }
    if (value is num) return value.toDouble();
    return defaultValue;
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