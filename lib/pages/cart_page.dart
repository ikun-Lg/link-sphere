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
  List<CartItem> _cartItems = [];
  List<bool> _selectedItems = []; // 新增：记录选中的商品
  bool _isLoading = false;
  String? _errorMessage;
  final ApiService _apiService = ApiService();

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
      print('Get Cart List Response: $response'); // 添加调试日志
      if (mounted) { // 检查 widget 是否还在树中
        if (response['code'] == 'SUCCESS_0000') {
          // 确保 data 是 Map，并且 list 是 List
          final Map<String, dynamic> data = response['data'] is Map ? response['data'] : {};
          final List<dynamic> dataList = data['list'] is List ? data['list'] : [];
          
          setState(() {
            _cartItems = dataList.map((json) {
              // 确保 json 是 Map，并且添加更强的类型检查
              if (json is! Map<String, dynamic>) {
                print('Invalid cart item data: $json');
                return null;
              }
              return CartItem.fromJson(json);
            }).whereType<CartItem>().toList(); // 过滤掉 null 值
            
            // 初始化选中状态，默认全部未选中
            _selectedItems = List.filled(_cartItems.length, false);
            
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
      // 确保 cartId 是字符串
      final String safeCartId = cartId.toString();
      final response = await _apiService.deleteCartItem(safeCartId);
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
  // 新增：切换商品选中状态
  void _toggleItemSelection(int index) {
    setState(() {
      bool isCurrentlySelected = _selectedItems[index];
      // 先将所有项目取消选中
      for (int i = 0; i < _selectedItems.length; i++) {
        _selectedItems[i] = false;
      }
      // 如果之前未选中该项目，则选中它
      // (如果之前已选中，则在上面的循环中已被取消选中，实现了点击已选中的项即取消选中的效果)
      if (!isCurrentlySelected) {
        _selectedItems[index] = true;
      }
    });
  }

  // 新增：全选/取消全选
  void _toggleSelectAll(bool? value) {
    setState(() {
      _selectedItems = List.filled(_cartItems.length, value ?? false);
    });
  }

  // 新增：获取选中商品的总价
  double _calculateSelectedTotalPrice() {
    return _cartItems.where((item) {
      final index = _cartItems.indexOf(item);
      return _selectedItems[index];
    }).fold<double>(0, (sum, item) => sum + (item.price * item.quantity));
  }

  // 新增：获取选中的商品列表
  List<CartItem> _getSelectedItems() {
    return _cartItems.where((item) {
      final index = _cartItems.indexOf(item);
      return _selectedItems[index];
    }).toList();
  }

  // 新增：选择性支付方法
  Future<void> _paySelectedItems(List<CartItem> selectedItems) async {
    // 如果没有选中商品，不进行支付
    if (selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择要结算的商品')),
      );
      return;
    }

    // 开始支付处理
    setState(() {
      _isLoading = true;
    });

    // 存储支付失败的商品
    List<String> failedProducts = [];

    // 创建一个可修改的列表副本
    List<CartItem> remainingItems = List.from(_cartItems);
    List<bool> remainingSelectedItems = List.from(_selectedItems);

    try {
      for (var item in selectedItems) {
        print('商品ID: ${item.productId}, 数量: ${item.quantity}');
        try {
          final response = await _apiService.createPayOrder(item.productId);
          if (response['code'] == 'SUCCESS_0000') {
            print('商品${item.productId}支付成功，准备显示二维码');
            final String? qrCodeUrl = response['data'] as String?;

            if (qrCodeUrl != null && qrCodeUrl.isNotEmpty) {
              // 显示二维码弹窗并等待其关闭
              await _showQrCodeDialog(context, qrCodeUrl, item.productName);
            } else {
              print('商品${item.productId}支付成功，但未收到有效的二维码URL。');
              // 可以选择向用户显示一个不同的消息，或者将此视为一个失败场景
              failedProducts.add('商品${item.productName}: 支付成功但二维码获取失败');
              // 跳过此商品的移除，因为它可能未完全处理
              continue; // 继续下一个商品
            }
            
            // 支付成功且二维码显示(或尝试显示)后，标记商品以便后续移除
            final indexInOriginalCart = _cartItems.indexWhere((cartItem) => cartItem.id == item.id);
            if (indexInOriginalCart != -1) {
                 // 我们将在循环结束后根据成功支付的ID列表来更新UI
            } else {
                 // 理论上不应该发生，因为item来自selectedItems，而selectedItems源于_cartItems
            }

          } else {
            print('商品${item.productId}支付失败: ${response['info']}');
            failedProducts.add('商品${item.productName}: ${response['info'] ?? '未知错误'}');
          }
        } catch (itemError) {
          print('商品${item.productId}支付出错: $itemError');
          failedProducts.add('商品${item.productName}: $itemError');
        }
      }

      // 循环结束后，根据处理结果更新UI
      // 筛选出未成功支付或未显示二维码的商品保留在购物车中
      List<CartItem> updatedCartItems = [];
      List<bool> updatedSelectedItemsStatus = [];

      for (int i = 0; i < _cartItems.length; i++) {
        final currentCartItem = _cartItems[i];
        bool wasSuccessfullyPaidAndQrShown = selectedItems.any((paidItem) => 
            paidItem.id == currentCartItem.id && 
            !failedProducts.any((failedMsg) => failedMsg.startsWith('商品${paidItem.productName}:'))
        );

        if (!wasSuccessfullyPaidAndQrShown) {
          updatedCartItems.add(currentCartItem);
          updatedSelectedItemsStatus.add(_selectedItems[i]); // 保留其原始选中状态，或设为false
        }
      }

      setState(() {
        _cartItems = updatedCartItems;
        _selectedItems = updatedSelectedItemsStatus;
        _isLoading = false;
      });

      if (failedProducts.isEmpty && selectedItems.isNotEmpty) {
        // 全部支付成功
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('选中商品支付成功')),
        );
      } else {
        // 部分商品支付失败
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('支付结果'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('以下商品支付失败:'),
                ...failedProducts.map((product) => Text(product, style: const TextStyle(color: Colors.red))),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('确定'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // 处理全局错误
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('下单出错: $e')),
      );
    }
  }
  // --- 下单结束 ---

  // --- 新增：显示二维码弹窗 ---
  Future<void> _showQrCodeDialog(BuildContext context, String qrCodeUrl, String productName) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // 用户必须点击按钮关闭
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('商品支付'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('请扫描下方二维码完成对商品 "$productName" 的支付：'),
                const SizedBox(height: 16),
                Center(
                  child: Image.network(
                    qrCodeUrl,
                    height: 200,
                    width: 200,
                    fit: BoxFit.contain,
                    loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                      return const Center(child: Text('二维码加载失败'));
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('完成支付'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }
  // --- 新增结束 ---

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
                            // 切换商品选中状态
                            _toggleItemSelection(index);
                          },
                          child: Card(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            color: _selectedItems[index] ? Colors.blue.shade50 : Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // 添加复选框
                                  Checkbox(
                                    value: _selectedItems[index],
                                    onChanged: (bool? value) {
                                      _toggleItemSelection(index);
                                    },
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.productName,
                                          style: const TextStyle(fontSize: 16),
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
              Text(
                '¥${_calculateSelectedTotalPrice().toStringAsFixed(2)}', // 修改为显示选中商品的总价
                style: TextStyle(
                  fontSize: 20,
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 16),
              // 结算按钮
              Expanded(
                child: ElevatedButton(
                  // --- 修改：购物车为空时禁用按钮 ---
                  onPressed: _cartItems.isEmpty ? null : () {
                    // 使用选择性支付方法
                    final selectedItems = _getSelectedItems();
                    if (selectedItems.isNotEmpty) {
                      _paySelectedItems(selectedItems);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请选择要结算的商品')),
                      );
                    }
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