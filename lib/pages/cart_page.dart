import 'package:flutter/material.dart';
import '../models/cart_item.dart'; // <--- 导入 CartItem 模型
import '../services/api_service.dart'; // <--- 导入 ApiService
// import 'product_detail_page.dart'; // 暂时注释掉，因为 ProductDetailPage 需要 DiscoverPost

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  // --- 修改：使用状态变量存储购物车数据 ---
  List<CartItem> _cartItems = [];
  bool _isLoading = true;
  String? _errorMessage;
  final ApiService _apiService = ApiService();
  // --- 修改结束 ---

  // --- 新增：获取购物车数据的方法 ---
  @override
  void initState() {
    super.initState();
    _fetchCartItems();
  }

  Future<void> _fetchCartItems() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _apiService.getCartList();
      if (mounted) { // 检查 widget 是否还在树中
        if (response['code'] == 'SUCCESS_0000') {
          final List<dynamic> dataList = response['data']['list'];
          setState(() {
            _cartItems = dataList.map((json) => CartItem.fromJson(json)).toList();
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = response['info'] ?? '加载购物车失败';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
       if (mounted) {
         setState(() {
           _errorMessage = e.toString();
           _isLoading = false;
         });
       }
    }
  }
  // --- 新增结束 ---

  // --- 新增：计算总价的方法 ---
  double _calculateTotalPrice() {
    return _cartItems.fold<double>(0, (sum, item) => sum + (item.price * item.quantity));
  }
  // --- 新增结束 ---

  // --- 新增：删除购物车商品的方法 ---
  Future<void> _deleteItem(String cartId, int index) async {
    try {
      final response = await _apiService.deleteCartItem(cartId);
      if (mounted) {
        if (response['code'] == 'SUCCESS_0000') {
          setState(() {
            _cartItems.removeAt(index);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('商品已从购物车移除'), duration: Duration(seconds: 1)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: ${response['info']}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除出错: $e')),
        );
      }
    }
  }
  // --- 新增结束 ---

    // --- 新增：计算购物车商品的方法 ---
  Future<void> _payCart() async {
    int count = _cartItems.length;
    try {
      for (var item in _cartItems) {
        print('商品ID: ${item.productId}, 数量: ${item.quantity}');
        final response = await _apiService.createPayOrder(item.productId);
        if (response['code'] == 'SUCCESS_0000') {
          print('商品${item.productId}支付成功');
          count--;
          if (count == 0) {
            print('所有商品支付成功');
            _fetchCartItems();
          }
        } else {
          print('商品${item.productId}支付失败: ${response['info']}');
        }
      }
    } catch (e) {
      print('支付出错: $e');
    }
  }
  // --- 结算结束 ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          '购物车',
          style: TextStyle(color: Colors.black, fontSize: 16),
        ),
        // --- 新增：刷新按钮 ---
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black54),
            onPressed: _fetchCartItems,
          ),
        ],
        // --- 新增结束 ---
      ),
      // --- 修改：根据加载和错误状态显示不同内容 ---
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text('错误: $_errorMessage'))
              : _cartItems.isEmpty
                  ? const Center(child: Text('购物车是空的'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _cartItems.length,
                      itemBuilder: (context, index) {
                        final item = _cartItems[index];
                        return GestureDetector(
                          onTap: () {
                            // TODO: 导航到商品详情页
                            // 需要将 CartItem 转换为 ProductDetailPage 需要的格式
                            // 或者修改 ProductDetailPage 以接受 productId
                            print('跳转到商品详情页: ${item.productId}');
                            // Navigator.push(
                            //   context,
                            //   MaterialPageRoute(
                            //     builder: (context) => ProductDetailPage(product: /* 需要转换或传递 productId */),
                            //   ),
                            // );
                          },
                          child: Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 商品图片
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      item.image, // <--- 使用 CartItem 的 image
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          Container(width: 100, height: 100, color: Colors.grey[200], child: Icon(Icons.broken_image, color: Colors.grey[400])),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // 商品信息
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.productName, // <--- 使用 CartItem 的 productName
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          item.desc, // <--- 使用 CartItem 的 desc
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                          ),
                                           maxLines: 1,
                                           overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        Row( // <--- 显示价格和数量
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '¥${item.price.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontSize: 18,
                                                color: Theme.of(context).primaryColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                             Text(
                                              'x ${item.quantity}', // <--- 显示数量
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  // 删除按钮
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    color: Colors.grey[400],
                                    onPressed: () {
                                      // --- 修改：调用 API 删除购物车商品 --- 
                                      final itemToDelete = _cartItems[index];
                                      _deleteItem(itemToDelete.id.toString(), index); // 假设 CartItem 的 id 是 String 或可以转为 String
                                      // --- 修改结束 ---
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
      // --- 修改结束 ---
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                offset: const Offset(0, -2),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            children: [
              // 总价
              Text(
                '总计: ',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              // --- 修改：使用计算后的总价 ---
              Text(
                '¥${_calculateTotalPrice().toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 20,
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // --- 修改结束 ---
              const SizedBox(width: 16),
              // 结算按钮
              Expanded(
                child: ElevatedButton(
                  // --- 修改：购物车为空时禁用按钮 ---
                  onPressed: _cartItems.isEmpty ? null : () {
                    // TODO: 实现结算功能
                    _payCart();
                  },
                  // --- 修改结束 ---
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text('结算'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}