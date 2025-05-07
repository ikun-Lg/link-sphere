import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:link_sphere/models/discover_model.dart'; // 复用 DiscoverPost 模型
import 'package:link_sphere/pages/product_detail_page.dart';
import 'package:link_sphere/services/api_service.dart';

class CategoryProductsPage extends StatefulWidget {
  final int categoryId;
  final String categoryName;

  const CategoryProductsPage({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<CategoryProductsPage> createState() => _CategoryProductsPageState();
}

class _CategoryProductsPageState extends State<CategoryProductsPage> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();

  List<DiscoverPost> _products = [];
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;
  int? _lastId; // 用于分页

  @override
  void initState() {
    super.initState();
    print('Loading products for category: ${widget.categoryName} (ID: ${widget.categoryId})');
    _scrollController.addListener(_onScroll);
    _fetchCategoryProducts(isRefresh: true); // 初始加载
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;

    // 滚动到底部附近时触发加载更多
    if (currentScroll >= maxScroll * 0.9 && !_isLoading && _hasMore) {
      _fetchCategoryProducts();
    }
  }

  Future<void> _fetchCategoryProducts({bool isRefresh = false}) async {
    if (_isLoading) return; // 防止重复加载

    setState(() {
      _isLoading = true;
      if (isRefresh) {
        _error = null; // 刷新时清除错误
        _lastId = null; // 刷新时重置 lastId
        _hasMore = true; // 刷新时重置 hasMore
      }
    });

    try {
      final response = await _apiService.getProductsByCategory(
        categoryId: widget.categoryId,
        lastId: isRefresh ? null : _lastId, // 刷新时不传 lastId
        size: 20, // 或其他你希望的每页数量
      );

      if (response['code'] == 'SUCCESS_0000' && response['data']?['list'] != null) {
        final List<dynamic> productListJson = response['data']['list'];
        final List<DiscoverPost> fetchedProducts = productListJson.map((json) {
          // --- 将 API 返回的商品数据映射到 DiscoverPost 模型 ---
          return DiscoverPost(
            // API 返回的 id 是 int，模型需要 String，进行转换
            id: json['id'] ?? 0,
            title: json['name'] ?? '无标题',
            description: json['description'] ?? '',
            imageUrl: json['mainImage'] ?? 'https://via.placeholder.com/300',
            price: (json['price'] as num?)?.toDouble() ?? 0.0,
            shopName: '分类好店', // API 暂无店铺名，给个默认值
            sales: (json['sales'] as num?)?.toInt() ?? 0,
            likes: 0, // API 暂无
            comments: 0, // API 暂无
          );
          // --- 映射结束 ---
        }).toList();

        setState(() {
          if (isRefresh) {
            _products = fetchedProducts; // 刷新，直接替换
          } else {
            _products.addAll(fetchedProducts); // 加载更多，追加
          }

          // 更新 lastId 和 hasMore 状态
          if (fetchedProducts.isNotEmpty) {
            // API 返回的 id 是 int
            _lastId = productListJson.last['id'] as int?;
          }
          // 如果返回的列表为空或小于请求的大小，认为没有更多数据了
          _hasMore = fetchedProducts.isNotEmpty && fetchedProducts.length == 20; // 假设 size 是 20

          _isLoading = false;
        });
      } else {
        throw response['info'] ?? '加载商品失败';
      }
    } catch (e) {
      print('Error fetching category products: $e');
      setState(() {
        _isLoading = false;
        // 只有在首次加载或刷新失败时才显示错误，加载更多失败可以静默处理或只更新 hasMore
        if (isRefresh || _products.isEmpty) {
           _error = '加载失败: $e';
        }
        _hasMore = false; // 出错时也认为没有更多了
      });
    }
  }

  // --- 构建加载指示器 ---
  Widget _buildLoadingIndicator() {
    return const SliverToBoxAdapter( // 用于 StaggeredGrid
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
    );
  }

  // --- 构建无更多数据指示器 ---
  Widget _buildNoMoreIndicator() {
    return const SliverToBoxAdapter( // 用于 StaggeredGrid
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: Text('没有更多商品了')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryName),
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchCategoryProducts(isRefresh: true),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _products.isEmpty && _error == null) {
      // 初始加载状态
      return const Center(child: CircularProgressIndicator());
    } else if (_error != null && _products.isEmpty) {
      // 初始加载错误状态
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _fetchCategoryProducts(isRefresh: true),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    } else if (_products.isEmpty && !_isLoading) {
       // 加载完成但列表为空
       return const Center(child: Text('该分类下暂无商品'));
    } else {
      // 显示商品列表
      // 使用 CustomScrollView 结合 SliverStaggeredGrid 和 SliverToBoxAdapter
      return CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(8.0),
            sliver: SliverMasonryGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childCount: _products.length,
              itemBuilder: (context, index) {
                final product = _products[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        // 注意：这里传递的是 DiscoverPost 对象
                        builder: (context) => ProductDetailPage(product: product),
                      ),
                    );
                  },
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Image.network(
                          product.imageUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: CircularProgressIndicator(
                                  value: progress.expectedTotalBytes != null
                                      ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                      : null,
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 150,
                              color: Colors.grey[200],
                              child: Icon(Icons.broken_image, color: Colors.grey[400], size: 40),
                            );
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.title,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '¥${product.price.toStringAsFixed(2)}',
                                style: TextStyle(fontSize: 16, color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${product.shopName} · ${product.sales}人付款',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // --- 在底部显示加载或无更多数据指示器 ---
          if (_isLoading && _products.isNotEmpty) _buildLoadingIndicator(),
          if (!_hasMore && _products.isNotEmpty) _buildNoMoreIndicator(),
        ],
      );
    }
  }
}