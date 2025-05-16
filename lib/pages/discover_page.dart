import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:link_sphere/pages/cart_page.dart';
import 'package:link_sphere/pages/product_detail_page.dart';
import 'package:link_sphere/pages/search_product_result_page.dart';
import 'package:link_sphere/pages/search_result_page.dart';
import 'package:link_sphere/services/api_service.dart';
import '../models/discover_model.dart';
import '../models/category_node.dart'; // 导入分类模型
import 'category_products_page.dart'; // 导入将要创建的分类商品页


class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late TabController _tabController; // Declaration is here
  // --- Add declaration for _selectedTabIndex ---
  int _selectedTabIndex = 0; // Track the selected tab index
  // --- Declaration added ---
  List<DiscoverPost> posts = [];
  bool isLoading = false;
  bool hasMore = true;
  String? error;
  int currentPage = 1;

  // --- 修改：使用 API 数据替换硬编码分类 ---
  List<CategoryNode> topLevelCategories = []; // 用于存储顶层分类
  List<CategoryNode> allCategories = []; // 用于存储所有拍平后的分类
  bool categoriesLoading = true; // 分类加载状态
  String? categoryError; // 分类加载错误信息
  // final List<Map<String, String>> categories = [ ... ]; // 移除硬编码列表
  // --- 修改结束 ---


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _scrollController.addListener(_onScroll);
    _fetchCategories(); // 获取分类数据
    _fetchPosts(); // 初始加载第一个 Tab 的商品数据
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection); // 移除监听器
    _tabController.dispose(); // 释放 TabController
    _scrollController.dispose();
    super.dispose();
  }

  void _onProductTap(int productId) async {
    try {
      await _apiService.createViewOrder(productId);
      // 跳转到商品详情页或其他操作
    } catch (e) {
      // 处理错误，例如显示提示信息
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('记录浏览失败: $e')));
    }
  }

  // Tab 切换监听器
  void _handleTabSelection() {
    if (_tabController.indexIsChanging) return; // 确保动画完成后再处理

    // 检查索引是否真的改变了，避免不必要的加载
    if (_selectedTabIndex != _tabController.index) {
       setState(() {
         _selectedTabIndex = _tabController.index;
         // 清空当前列表，重置状态，然后加载新 Tab 的数据
         posts = [];
         currentPage = 1;
         hasMore = true;
         error = null;
       });
       _fetchPosts(); // 加载新 Tab 的数据
    }
  }


  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;

    // 当滚动到最底部时触发加载
    if (currentScroll >= maxScroll && !isLoading && hasMore) {
      _fetchPosts(isLoadMore: true);
    }
  }

  final ApiService _apiService = ApiService(); // 创建 ApiService 实例

  // --- 修改：递归函数来拍平分类树并计算深度 ---
  List<CategoryNode> _flattenCategoryTree(List<CategoryNode> nodes, {int depth = 0}) { // <--- 添加 depth 参数
    List<CategoryNode> flattenedList = [];
    for (var node in nodes) {
      node.depth = depth; // <--- 设置当前节点的深度
      flattenedList.add(node); // 添加当前节点
      if (node.children.isNotEmpty) {
        // 如果有子节点，递归拍平子节点并添加到结果列表，深度加 1
        flattenedList.addAll(_flattenCategoryTree(node.children, depth: depth + 1)); // <--- 传递 depth + 1
      }
    }
    return flattenedList;
  }
  // --- 修改结束 ---

  // --- 修改：获取分类数据的方法，调用修改后的拍平函数 ---
  Future<void> _fetchCategories() async {
    setState(() {
      categoriesLoading = true;
      categoryError = null;
      allCategories = []; // 清空旧数据
    });
    try {
      final fetchedCategories = await _apiService.getCategoryTree();
      // --- 调用拍平函数，从深度 0 开始 ---
      final flattened = _flattenCategoryTree(fetchedCategories, depth: 0);
      // --- 调用结束 ---
      setState(() {
        topLevelCategories = fetchedCategories; // 仍然可以保留原始树结构
        allCategories = flattened; // <--- 更新包含深度的拍平后列表状态
        categoriesLoading = false;
      });
    } catch (e) {
      setState(() {
        categoryError = '加载分类失败: $e';
        categoriesLoading = false;
      });
      print('Error fetching categories: $e');
    }
  }
  // --- 修改结束 ---


  // 修改 fetchPosts 以区分不同 Tab
  Future<void> _fetchPosts({bool isLoadMore = false}) async {
    // --- 修改：热门和推荐 Tab 都不支持加载更多 ---
    if (isLoading || isLoadMore) { // 简化判断，因为两个 API 都不分页
       // 如果是加载更多操作，则直接返回
       if (isLoadMore) {
         setState(() {
           hasMore = false; // 标记没有更多数据
         });
       }
       return;
    }
    // --- 修改结束 ---

    setState(() {
      isLoading = true;
      if (!isLoadMore) error = null;
      // --- 修改：两个 Tab 都不分页，直接设置 hasMore 为 false ---
      hasMore = false; // 假设数据一次性加载完
      // --- 修改结束 ---
    });

    print('Fetching posts for tab: $_selectedTabIndex, page: $currentPage, isLoadMore: $isLoadMore');

    try {
      List<DiscoverPost> fetchedPosts = [];
      bool reachedEnd = true; // 标记是否到达末尾，因为不分页，总是 true

      // --- 根据 Tab 调用不同 API ---
      if (_selectedTabIndex == 0) { // 热门 Tab
        // --- 调用热门商品 API ---
        final response = await _apiService.getHotProducts();
        print('Hot Products Response: $response'); // 添加调试日志
        if (response['code'] == 'SUCCESS_0000' && response['data'] is Map && response['data']['list'] is List) {
          final List<dynamic> productList = response['data']['list'];
          fetchedPosts = productList.map((json) {
            // --- 将 API 返回的商品数据映射到 DiscoverPost 模型 ---
            return DiscoverPost(
              id: json is Map<String, dynamic> ? (json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0) : 0,
              title: json is Map<String, dynamic> ? (json['name'] ?? '无标题') : '无标题',
              description: json is Map<String, dynamic> ? (json['description'] ?? '') : '',
              imageUrl: json is Map<String, dynamic> ? (json['mainImage'] ?? 'https://via.placeholder.com/300') : 'https://via.placeholder.com/300',
              price: json is Map<String, dynamic> ? ((json['price'] is num) ? (json['price'] as num).toDouble() : double.tryParse(json['price'].toString()) ?? 0.0) : 0.0,
              shopName: '精选店铺', // API 暂无店铺名
              sales: json is Map<String, dynamic> ? ((json['sales'] is int) ? json['sales'] : int.tryParse(json['sales'].toString()) ?? 0) : 0,
              likes: 0, // API 暂无
              comments: 0, // API 暂无
            );
            // --- 映射结束 ---
          }).toList();
        } else {
          throw response['info'] ?? '加载热门商品失败';
        }
        // --- 热门 API 调用结束 ---
      } else if (_selectedTabIndex == 1) { // 推荐 Tab
        // --- 调用推荐商品 API ---
        final response = await _apiService.getRecommendedProducts();
        print('Recommended Products Response: $response'); // 添加调试日志
        if (response['code'] == 'SUCCESS_0000' && response['data']?['list'] != null) {
          final List<dynamic> productList = response['data']['list'];
          fetchedPosts = productList.map((json) {
            // --- 将 API 返回的商品数据映射到 DiscoverPost 模型 ---
            return DiscoverPost(
              id: json is Map<String, dynamic> ? (json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0) : 0,
              title: json is Map<String, dynamic> ? (json['name'] ?? '无标题') : '无标题',
              description: json is Map<String, dynamic> ? (json['description'] ?? '') : '',
              imageUrl: json is Map<String, dynamic> ? (json['mainImage'] ?? 'https://via.placeholder.com/300') : 'https://via.placeholder.com/300',
              price: json is Map<String, dynamic> ? ((json['price'] is num) ? (json['price'] as num).toDouble() : double.tryParse(json['price'].toString()) ?? 0.0) : 0.0,
              shopName: '推荐好店', // 可以给推荐商品不同的默认店铺名
              sales: json is Map<String, dynamic> ? ((json['sales'] is int) ? json['sales'] : int.tryParse(json['sales'].toString()) ?? 0) : 0,
              likes: 0, // API 暂无
              comments: 0, // API 暂无
            );
            // --- 映射结束 ---
          }).toList();
        } else {
          // 如果是未登录导致的错误，可以特殊处理
          if (response['info'] == '用户未登录，无法获取推荐商品') {
             // 可以选择显示提示信息，或者显示空列表
             print('User not logged in, cannot fetch recommendations.');
             // fetchedPosts 保持为空列表
             error = '请先登录以查看推荐内容'; // 设置错误信息让用户知道
          } else {
            throw response['info'] ?? '加载推荐商品失败';
          }
        }
        // --- 推荐 API 调用结束 ---
      }
      // --- API 调用结束 ---


      setState(() {
        // 因为不分页，总是直接替换列表
        posts = fetchedPosts;
        // --- 修改：移除分页逻辑 ---
        // if (_selectedTabIndex != 0 && fetchedPosts.isNotEmpty && !reachedEnd) {
        //   currentPage += 1;
        // }
        // --- 修改结束 ---
        // hasMore 的状态在各自的逻辑块中已经更新 (或在开头统一设置为 false)
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching posts: $e'); // 打印更详细的错误
      setState(() {
        isLoading = false;
        // 只有在非加载更多时才清除错误信息 (虽然这里已经没有加载更多了)
        // if (!isLoadMore) {
        //    error = '数据加载失败: $e'; // 显示具体的错误信息
        // }
        // 直接设置错误信息
        // 避免覆盖上面处理的 "请先登录" 提示
        error ??= '数据加载失败: $e';
      });
      // debugPrint('Error fetching posts: $e'); // debugPrint 仅在 debug 模式下输出
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        titleSpacing: 0,
        // 移除返回按钮
        automaticallyImplyLeading: false,
        title: Container( // The Container is now the direct child of title
          height: 36,
          margin: const EdgeInsets.only(left: 16),
          child: TextField(
            readOnly: true, // 设置为只读，点击时跳转
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SearchProductResultPage(keyword: '')),
              );
            },
            decoration: InputDecoration(
              hintText: '搜索商品',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              prefixIcon: Icon(Icons.search, color: Colors.grey[400], size: 20),
              filled: true,
              fillColor: Colors.grey[100],
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        // --- Expanded removed ---
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CartPage()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      backgroundColor: Colors.white,
   
      body: SafeArea(
        child: Column(
          children: [
            // --- 分类区域 ---
            Container(
              height: 90, // 高度可能需要调整以容纳更多分类，或者保持滚动
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: categoriesLoading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : categoryError != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text(categoryError!, style: TextStyle(color: Colors.red)),
                          )
                        )
                      // --- 修改：判断 allCategories 是否为空 ---
                      : allCategories.isEmpty // <--- Use allCategories for empty check
                          ? const Center(child: Text('暂无分类'))
                          // --- 修改：使用 allCategories 构建列表 ---
                          : ListView.builder( // 使用获取到的分类数据
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              itemCount: allCategories.length,
                              itemBuilder: (context, index) {
                                final category = allCategories[index];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0), // 设置左右间距相同
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => CategoryProductsPage(
                                            categoryId: category.id,
                                            categoryName: category.name,
                                          ),
                                        ),
                                      );
                                      print('Tapped category: ${category.name} (ID: ${category.id}, Depth: ${category.depth})');
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // --- 移除图标，因为 API 没有提供 ---
                                        // Container( ... icon container ... ),
                                        // const SizedBox(height: 4),
                                        // --- 直接显示分类名称 ---
                                        Container( // 添加背景容器模拟原图标位置
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: Colors.primaries[index % Colors.primaries.length].withOpacity(0.1), // 使用不同颜色区分
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text( // 显示名称首字母或固定图标
                                              category.name.isNotEmpty ? category.name[0] : '?',
                                              style: TextStyle(fontSize: 20, color: Colors.primaries[index % Colors.primaries.length]),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          category.name, // 显示 API 返回的名称
                                          style: const TextStyle(
                                            fontSize: 12,
                                            height: 1.2,
                                          ),
                                          textAlign: TextAlign.center, // 居中显示
                                          maxLines: 1, // 最多显示一行
                                          overflow: TextOverflow.ellipsis, // 超出部分省略
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
              // --- 加载状态处理结束 ---
            ),
            // --- 修改结束 ---

            // --- TabBar ---
            Container(
              // ... TabBar remains the same ...
            ),

            // 商品列表
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _fetchPosts(), // 下拉刷新当前 Tab
                child: error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(error!),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _fetchPosts,
                              child: const Text('重试'),
                            ),
                          ],
                        ),
                      )
                    // --- 修改：使用 IndexedStack 或类似方式根据 Tab 显示内容 ---
                    // 如果不同 Tab 的列表结构完全一样，可以直接用 MasonryGridView
                    // 如果结构不同，或希望保留每个 Tab 的滚动位置，可以用 IndexedStack
                    // 这里我们假设结构相同，直接更新 MasonryGridView 的数据源即可
                    : MasonryGridView.count(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(8),
                        crossAxisCount: 2,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        itemCount: posts.length + (hasMore || isLoading ? 1 : 0), // 动态计算 itemCount
                        itemBuilder: (context, index) {
                          // --- 修改：调整底部指示器的逻辑 ---
                          if (index == posts.length) {
                            if (isLoading) {
                              // --- Call the method from within the class ---
                              return _buildLoadingIndicator();
                            } else if (!hasMore && posts.isNotEmpty) { // 仅在有数据且无更多时显示
                              // --- Call the method from within the class ---
                              return _buildNoMoreIndicator();
                            } else {
                              return const SizedBox.shrink(); // 其他情况（如加载完成但还有更多）不显示
                            }
                          }
                          // --- 修改结束 ---
                          // --- Modification Start: Handle image loading ---
                          final post = posts[index];
                          return GestureDetector(
                            onTap: () {
                              _onProductTap(post.id) ;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProductDetailPage(product: post),
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
                                  // --- Add errorBuilder to Image.network ---
                                  Image.network(
                                    post.imageUrl,
                                    fit: BoxFit.cover,
                                    // Add a loading builder for better UX (optional)
                                    loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                                      if (loadingProgress == null) return child; // Image loaded
                                      return Center( // Show a progress indicator while loading
                                        child: Padding(
                                          padding: const EdgeInsets.all(20.0), // Add some padding
                                          child: CircularProgressIndicator(
                                            value: loadingProgress.expectedTotalBytes != null
                                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                                : null,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      );
                                    },
                                    // Add an error builder to handle loading failures
                                    errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                                      print('Error loading image: ${post.imageUrl}, Error: $error'); // Log the error
                                      // Return a placeholder widget
                                      return Container(
                                        height: 150, // Give the placeholder a reasonable height
                                        color: Colors.grey[200],
                                        child: Icon(
                                          Icons.broken_image,
                                          color: Colors.grey[400],
                                          size: 40,
                                        ),
                                      );
                                    },
                                  ),
                                  // --- errorBuilder added ---
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          post.title,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '¥${post.price.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Theme.of(context).primaryColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${post.shopName} · ${post.sales}人付款',
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
                          );
                          // --- Modification End ---
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 在商品列表的底部添加加载指示器
Widget _buildLoadingIndicator() {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.blue, // 使用固定颜色替代，因为这是一个独立的widget方法无法访问context
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '加载中...',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    ),
  );
}

// 在商品列表的底部添加没有更多数据的提示
Widget _buildNoMoreIndicator() {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Text(
      '没有更多数据了',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 14,
        color: Colors.grey[600],
      ),
    ));
  }
