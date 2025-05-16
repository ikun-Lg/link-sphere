import 'package:card_swiper/card_swiper.dart';
import 'package:flutter/material.dart';
import '../models/discover_model.dart';
import '../services/api_service.dart'; // <--- 导入 ApiService
import '../services/user_service.dart'; // <--- 导入 UserService (可能需要检查登录状态) // <--- 导入 CartPage

class ProductDetailPage extends StatefulWidget {
  final DiscoverPost product;

  const ProductDetailPage({super.key, required this.product});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  int _currentImageIndex = 0;
  Map<String, dynamic>? _productInfo;
  final ApiService _apiService = ApiService(); // <--- 实例化 ApiService
  bool _isAddingToCart = false; // <--- 添加加载状态
  bool _isLoading = true; // <--- 添加加载状态 for fetching product info

  @override
  void initState() {
    super.initState();
    _fetchProductInfo();
  }

  Future<void> _fetchProductInfo() async {
    // --- 修改开始: 使用 API 获取数据 ---
    setState(() {
      _isLoading = true; // 开始加载
    });
    try {
      // 假设 DiscoverPost 有 id 字段
      final response = await _apiService.getProductDetail(widget.product.id);
      if (mounted) { // 检查 widget 是否还在树中
        if (response['code'] == 'SUCCESS_0000' && response['data'] != null) {
          setState(() {
            _productInfo = response['data'];
            _isLoading = false; // 加载完成
          });
        } else {
          // 处理 API 返回错误
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('获取商品信息失败: ${response['info'] ?? '未知错误'}')),
          );
          setState(() {
            _isLoading = false; // 加载完成（虽然失败）
          });
        }
      }
    } catch (e) {
      // 处理网络请求或其他异常
      print('获取商品信息异常: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('获取商品信息异常: $e')),
        );
        setState(() {
          _isLoading = false; // 加载完成（虽然失败）
        });
      }
    }
    // --- 修改结束 ---
    // --- 移除模拟数据 ---
    // setState(() {
    //   _productInfo = { ... };
    // });
    // --- 移除结束 ---
  }

  // --- 新增：显示数量选择弹窗 ---
  void _showQuantityDialog() {
    int quantity = 1; // 默认数量
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder( // 圆角
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder( // 使用 StatefulBuilder 来更新弹窗内的状态
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('选择数量', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: quantity > 1 ? () {
                          setModalState(() {
                            quantity--;
                          });
                        } : null, // 数量大于1时才可减
                      ),
                      Text('$quantity', style: const TextStyle(fontSize: 18)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () {
                          // 可以根据库存 _productInfo?['stock'] 进行限制
                          setModalState(() {
                            quantity++;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isAddingToCart ? null : () async {
                        Navigator.pop(context); // 关闭弹窗
                        _handleAddToCart(quantity); // 调用加入购物车逻辑
                      },
                      style: ElevatedButton.styleFrom(
                         backgroundColor: Colors.orange,
                         padding: const EdgeInsets.symmetric(vertical: 12),
                         shape: RoundedRectangleBorder(
                           borderRadius: BorderRadius.circular(20),
                         ),
                      ),
                      child: _isAddingToCart
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('确定'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
  // --- 新增结束 ---

  // --- 新增：处理加入购物车逻辑 ---
  Future<void> _handleAddToCart(int quantity) async {
    // 检查登录状态
    final token = await UserService.getToken();
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先登录')),
      );
      // 可以导航到登录页
      // Navigator.push(context, MaterialPageRoute(builder: (context) => LoginPage()));
      return;
    }

    if (_productInfo == null || _productInfo!['id'] == null) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('商品信息错误')),
      );
      return;
    }

    // 设置加载状态
    setState(() {
      _isAddingToCart = true;
    });

    try {
      // 确保商品 ID 是整数
      final productId = _productInfo!['id'] is int 
        ? _productInfo!['id'] 
        : int.tryParse(_productInfo!['id'].toString()) ?? 0;

      if (productId == 0) {
        throw '无效的商品 ID';
      }

      final response = await _apiService.addToCart(
        productId: productId, // 使用商品 ID
        productNum: quantity,
      );

      // 处理响应
      if (response['code'] == 'SUCCESS_0000') {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('成功加入购物车')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['info'] ?? '加入购物车失败')),
        );
      }
    } catch (e) {
      // 确保 context 仍然可用
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加入购物车出错: $e')),
      );
    } finally {
      // 确保 context 仍然可用
      if (!mounted) return;
      setState(() {
        _isAddingToCart = false;
      });
    }
  }
  // --- 新增结束 ---


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '商品详情',
          style: const TextStyle(color: Colors.black, fontSize: 16),
        ),
      ),
      // --- 修改 body: 处理加载状态 ---
      body: _isLoading
          ? const Center(child: CircularProgressIndicator()) // 显示加载指示器
          : _productInfo == null
              ? const Center(child: Text('无法加载商品信息')) // 处理加载失败或数据为空的情况
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 轮播图部分
                      Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          SizedBox(
                            height: 300,
                            child: Swiper(
                              itemBuilder: (BuildContext context, int index) {
                                // --- 修改: 处理 detailImages 可能不是 List 或为 null 的情况 ---
                                final detailImages = _productInfo!['detailImages'];
                                String imageUrl = '';
                                if (detailImages is String) {
                                  // 如果 detailImages 是单个字符串，尝试分割
                                  // 注意：API 返回的 detailImages 格式需要确认，这里假设是逗号分隔
                                  final imageList = detailImages.split(',');
                                  if (index < imageList.length) {
                                    imageUrl = imageList[index].trim();
                                  }
                                } else if (detailImages is List && index < detailImages.length) {
                                   imageUrl = detailImages[index] as String? ?? '';
                                }

                                // 拼接基础 URL (如果需要)
                                if (imageUrl.isNotEmpty && !imageUrl.startsWith('http')) {
                                   imageUrl = 'http://116.198.239.101:8089$imageUrl'; // 替换为你的基础 URL
                                }

                                return imageUrl.isNotEmpty
                                  ? Image.network(
                                      imageUrl,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return const Center(child: CircularProgressIndicator());
                                      },
                                      errorBuilder: (context, error, stackTrace) {
                                        return Image.network(
                                          'https://vcover-vt-pic.puui.qpic.cn/vcover_vt_pic/0/mzc00200aaogpgh1731229785085/0',
                                          fit: BoxFit.cover,
                                        );
                                      },
                                    )
                                  : const Center(child: Icon(Icons.image_not_supported)); // 占位图
                                // --- 修改结束 ---
                              },
                              onIndexChanged: (index) {
                                setState(() {
                                  _currentImageIndex = index;
                                });
                              },
                              // --- 修改: 动态计算 itemCount ---
                              itemCount: (_productInfo!['detailImages'] is String)
                                  ? (_productInfo!['detailImages'] as String).split(',').length
                                  : (_productInfo!['detailImages'] is List ? (_productInfo!['detailImages'] as List).length : 0),
                              // --- 修改结束 ---
                              pagination: const SwiperPagination(
                                builder: DotSwiperPaginationBuilder(
                                  activeColor: Colors.blue,
                                  color: Colors.white,
                                ),
                              ),
                              autoplay: true,
                            ),
                          ),
                        ],
                      ),
                      // 商品信息部分
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 价格
                            Row(
                              children: [
                                Text(
                                  // --- 修改: 添加 null 和类型检查 ---
                                  '¥${(_productInfo!['price'] as num?)?.toStringAsFixed(2) ?? 'N/A'}',
                                  // --- 修改结束 ---
                                  style: TextStyle(
                                    fontSize: 24,
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  // --- 修改: 添加 null 和类型检查 ---
                                  '¥${(_productInfo!['marketPrice'] as num?)?.toStringAsFixed(2) ?? 'N/A'}',
                                  // --- 修改结束 ---
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // 标题
                            Text(
                              // --- 修改: 添加 null 检查 ---
                              _productInfo!['name'] as String? ?? '商品名称加载失败',
                              // --- 修改结束 ---
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // 描述
                            Text(
                              // --- 修改: 添加 null 检查 ---
                              _productInfo!['description'] as String? ?? '',
                              // --- 修改结束 ---
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 16),
                            // 店铺信息 (假设 widget.product 仍然可用)
                            Row(
                              children: [
                                CircleAvatar(
                                  // --- 修改: 使用 _productInfo 中的店铺信息 (如果 API 返回) ---
                                  // backgroundImage: NetworkImage(_productInfo!['shopAvatar'] ?? ''), // 示例
                                  backgroundColor: Colors.grey[100],
                                  child: Icon(Icons.store, color: Colors.grey[600]),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      // --- 修改: 使用 _productInfo 中的店铺名 (如果 API 返回) ---
                                      // _productInfo!['shopName'] ?? '店铺名称加载失败', // 示例
                                      widget.product.shopName, // 暂时保留 widget.product
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      // --- 修改: 添加 null 和类型检查 ---
                                      '已售${(_productInfo!['sales'] as num?) ?? 0}件',
                                      // --- 修改结束 ---
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // 规格参数
                            // --- 修改: 确保 specs 是 List ---
                            if (_productInfo!['specs'] is List && (_productInfo!['specs'] as List).isNotEmpty)
                              ExpansionTile(
                                title: Text('规格参数'),
                                children: (_productInfo!['specs'] as List).map<Widget>((spec) {
                                  // --- 修改: 添加 null 和类型检查 ---
                                  final attributeName = spec['attributeName'] as String? ?? '未知属性';
                                  final attributeValues = spec['attributeValues'];
                                  String valuesText = '无';
                                  if (attributeValues is List && attributeValues.isNotEmpty) {
                                    valuesText = attributeValues
                                        .map((value) => value['attributeValue'] as String? ?? '')
                                        .where((v) => v.isNotEmpty)
                                        .join(', ');
                                  }
                                  // --- 修改结束 ---
                                  return ListTile(
                                    title: Text(attributeName),
                                    subtitle: Text(valuesText),
                                  );
                                }).toList(),
                              ),
                            // --- 修改结束 ---
                            const SizedBox(height: 16),
                            // 浏览数
                            Text(
                              // --- 修改: 添加 null 和类型检查 ---
                              '${(_productInfo!['views'] as num?) ?? 0}人浏览',
                              // --- 修改结束 ---
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
              // 加入购物车按钮
              Expanded(
                flex: 1,
                child: ElevatedButton(
                  onPressed: _productInfo == null || _isAddingToCart ? null : _showQuantityDialog, // <--- 修改 onPressed
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: _isAddingToCart
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('加入购物车'), // <--- 根据状态显示文本或加载指示器
                ),
              ),
              const SizedBox(width: 12),
              // 立即购买按钮
              Expanded(
                flex: 1,
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: 实现购买逻辑 (类似加入购物车，可能需要先弹窗选数量)
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text('立即购买'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}