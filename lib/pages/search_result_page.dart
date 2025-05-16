import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:link_sphere/models/search_user.dart';
import 'package:link_sphere/services/api_service.dart';
import 'package:link_sphere/pages/user_profile_page.dart';
import 'post_detail_page.dart';
import 'package:link_sphere/widgets/error_view.dart';
import 'package:link_sphere/utils/network_utils.dart';

class SearchResultPage extends StatefulWidget {
  final String keyword;

  const SearchResultPage({
    super.key,
    required this.keyword,
  });

  @override
  State<SearchResultPage> createState() => _SearchResultPageState();
}

class _SearchResultPageState extends State<SearchResultPage> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> postResults = [];
  List<SearchUser> userResults = [];
  List<Map<String, dynamic>> productResults = [];
  bool isLoading = false;
  
  // 错误状态分别保存
  bool hasUserError = false;
  bool hasPostError = false;
  bool hasProductError = false;
  String userErrorMessage = '';
  String postErrorMessage = '';
  String productErrorMessage = '';
  
  // 分页相关参数
  int _currentPage = 1;
  final int _pageSize = 20;
  bool _hasMoreUsers = true;
  bool _isLoadingMore = false;

  // 商品分页相关
  int _currentProductPage = 1;
  final int _productPageSize = 10; // 商品每页数量可以不同
  bool _hasMoreProducts = true;
  bool _isLoadingMoreProducts = false;

  List<Map<String, dynamic>> recommendedPostResults = [];
  List<Map<String, dynamic>> latestPostResults = [];
  final bool _showRecommendedPosts = false; // 新增状态，用于控制是否显示推荐帖子

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.keyword;
    _tabController = TabController(length: 3, vsync: this); // Fix: set length to 3
    _tabController.addListener(_handleTabChange);
    _scrollController.addListener(_onScroll);
    _performSearch();
  }
  
  void _handleTabChange() {
    // 当切换标签时，确保动画完成且非全局加载中
    if (!_tabController.indexIsChanging && !isLoading) {
      bool shouldLoadData = false;
      int currentIndex = _tabController.index;

      // 只有在搜索框有内容时才因切换标签而加载数据
      if (_searchController.text.isEmpty) {
        return;
      }

      // 判断当前激活的标签页是否需要加载数据
      if (currentIndex == 0 && userResults.isEmpty && !hasUserError) {
        shouldLoadData = true;
      } else if (currentIndex == 1 && latestPostResults.isEmpty && recommendedPostResults.isEmpty && !hasPostError) {
        shouldLoadData = true;
      } else if (currentIndex == 2 && productResults.isEmpty && !hasProductError) {
        shouldLoadData = true;
      }

      if (shouldLoadData) {
        _performSearch(); // _performSearch 会为当前激活的标签页加载数据
      }
    }
  }
  
  void _onScroll() {
    // 只有在用户标签页且有更多数据时才处理滚动事件
    if (_tabController.index == 0 && _hasMoreUsers && !isLoading && !_isLoadingMore) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.offset;
      if (currentScroll >= maxScroll * 0.9) {
        _loadMoreUsers();
      }
    } 
    // 在商品标签页且有更多数据时处理滚动事件
    else if (_tabController.index == 2 && _hasMoreProducts && !isLoading && !_isLoadingMoreProducts) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.offset;
      if (currentScroll >= maxScroll * 0.9) {
        _loadMoreProducts();
      }
    }
  }

  Future<void> _loadMoreUsers() async {
    if (!_hasMoreUsers || isLoading || _isLoadingMore) return;
    
    setState(() {
      _isLoadingMore = true;
    });
    
    try {
      final response = await ApiService().searchUsers(
        keywords: _searchController.text,
        page: _currentPage + 1,
        size: _pageSize,
      );
      
      if (response['code'] == 'SUCCESS_0000') {
        final responseDataMap = response['data'];
        if (responseDataMap is Map) {
          final List<dynamic> userListRaw = (responseDataMap['list'] as List<dynamic>?) ?? [];
          final int totalPages = (responseDataMap['pages'] as int?) ?? 1;
          
          final List<SearchUser> newUsers = userListRaw
              .map((json) {
                try {
                  return SearchUser.fromJson(json as Map<String, dynamic>);
                } catch (e) {
                  return null;
                }
              })
              .whereType<SearchUser>()
              .toList();
          
          // 更新页码和检查是否还有更多数据
          final int nextPage = _currentPage + 1;
          final bool hasMore = nextPage < totalPages;
          
          if (mounted) {
            setState(() {
              userResults.addAll(newUsers);
              _currentPage = nextPage;
              _hasMoreUsers = hasMore;
              _isLoadingMore = false;
            });
          }
        } else {
          throw '加载更多用户响应格式不正确';
        }
      } else {
        throw response['info'] ?? '加载更多用户失败';
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          
          // 设置用户错误但不清空现有结果
          hasUserError = true;
          userErrorMessage = NetworkUtils.handleApiError(e);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('加载更多用户失败: ${NetworkUtils.handleApiError(e)}')),
          );
        });
      }
    }
  }

  Future<void> _loadMoreProducts() async {
    if (!_hasMoreProducts || isLoading || _isLoadingMoreProducts) return;

    setState(() {
      _isLoadingMoreProducts = true;
    });

    try {
      final nextPage = _currentProductPage + 1;
      final response = await ApiService().searchProducts(
        keywords: _searchController.text,
        page: nextPage,
        size: _productPageSize,
      );

      final Map<String, dynamic>? dataMap = response['data'] as Map<String, dynamic>?;
      if (dataMap != null && dataMap['list'] is List) {
        final List<dynamic> newProductListRaw = dataMap['list'] as List;
        final int totalPages = (dataMap['pages'] as int?) ?? 1;

        if (mounted) {
          setState(() {
            productResults.addAll(newProductListRaw.cast<Map<String, dynamic>>());
            _currentProductPage = nextPage;
            _hasMoreProducts = _currentProductPage < totalPages;
            _isLoadingMoreProducts = false;
          });
        }
      } else {
        throw '加载更多商品响应格式不正确';
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMoreProducts = false;
          // Optionally show a snackbar or a small error message at the bottom
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('加载更多商品失败: ${NetworkUtils.handleApiError(e)}')),
          );
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    // 添加超时保护，15秒后无论如何都关闭loading
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted && isLoading) {
        setState(() {
          isLoading = false;
        });
      }
    });
    
    setState(() {
      isLoading = true;
      // 重置所有错误标志和消息。具体的搜索方法会在出错时设置它们。
      hasUserError = false;
      userErrorMessage = '';
      hasPostError = false;
      postErrorMessage = '';
      hasProductError = false;
      productErrorMessage = '';

      // 根据当前活动的标签页，清空其结果并重置分页状态
      if (_tabController.index == 0) { // 用户标签页
        userResults = [];
        _currentPage = 1;
        _hasMoreUsers = true;
      } else if (_tabController.index == 1) { // 帖子标签页
        latestPostResults = [];
        recommendedPostResults = [];
        // _searchPosts 内部会处理 _showRecommendedPosts 等状态
      } else if (_tabController.index == 2) { // 商品标签页
        productResults = [];
        _currentProductPage = 1;
        _hasMoreProducts = true;
      }
    });

    try {
      // 根据当前活动的标签页执行相应的搜索操作
      if (_tabController.index == 0) { // 用户
        await _searchUsers();
      } else if (_tabController.index == 1) { // 帖子
        await _searchPosts();
      } else if (_tabController.index == 2) { // 商品
        await _searchProducts();
      }
    } catch (e) {
      // 各个搜索方法内部已处理其特定的错误状态设置。
      // 此处的 catch 块作为安全网，捕获未被处理的异常。
      print("Error during _performSearch for tab ${_tabController.index}: $e");
    } finally {
      // 确保无论如何都关闭loading
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }
  
  // 将用户搜索逻辑拆分为独立方法
  Future<void> _searchUsers() async {
    try {
      final response = await ApiService().searchUsers(
        keywords: _searchController.text,
        page: _currentPage,
        size: _pageSize,
      );

      if (response['code'] == 'SUCCESS_0000') {
        final responseDataMap = response['data'];
        if (responseDataMap is Map) {
          final List<dynamic> userListRaw = (responseDataMap['list'] as List<dynamic>?) ?? [];
          final int totalUsers = (responseDataMap['total'] as int?) ?? 0;
          final int totalPages = (responseDataMap['pages'] as int?) ?? 1;

          final List<SearchUser> users = userListRaw
              .map((json) {
                try {
                  return SearchUser.fromJson(json as Map<String, dynamic>);
                } catch (e) {
                  return null; 
                }
              })
              .whereType<SearchUser>() // 过滤掉解析失败的null项
              .toList();
            
          // 判断是否还有更多数据
          // _currentPage 从1开始计数
          final bool hasMore = _currentPage < totalPages;

          if (mounted) {
            setState(() {
              userResults = users;
              _hasMoreUsers = hasMore;
            });
          }
        } else {
          throw '搜索用户响应格式不正确: "data"字段无效或缺失';
        }
      } else {
        throw response['info'] ?? '获取用户列表失败';
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          hasUserError = true;
          userErrorMessage = NetworkUtils.handleApiError(e);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('搜索用户失败: ${NetworkUtils.handleApiError(e)}')),
        );
      }
      // 重新抛出异常，以便Future.catchError能捕获
      rethrow;
    }
  }

  Future<void> _searchProducts() async {
    try {
      final response = await ApiService().searchProducts(
        keywords: _searchController.text,
        page: _currentProductPage, // 使用 _currentProductPage for initial load
        size: _productPageSize, 
      );

      final Map<String, dynamic>? dataMap = response['data'] as Map<String, dynamic>?;
      if (dataMap != null && dataMap['list'] is List) {
          final List<dynamic> productListRaw = dataMap['list'] as List;
          final int totalPages = (dataMap['pages'] as int?) ?? 1;

          if (mounted) {
            setState(() {
              productResults = productListRaw.cast<Map<String, dynamic>>();
              _hasMoreProducts = _currentProductPage < totalPages;
              hasProductError = false; 
            });
          }
      } else {
        throw '搜索商品响应格式不正确: "list"字段无效或缺失';
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          hasProductError = true;
          productErrorMessage = NetworkUtils.handleApiError(e);
          productResults = []; 
        });
      }
      rethrow; 
    }
  }

  Future<void> _searchPosts() async {
    hasPostError = false; 
    postErrorMessage = '';
    // 清空现有数据，因为我们要同时获取最新的和推荐的
    latestPostResults = [];
    recommendedPostResults = [];

    try {
      // 并行获取最新帖子和推荐帖子
      final latestFuture = ApiService().getLatestPosts(
        keywords: _searchController.text,
        page: 1, 
        size: 20, 
      ).catchError((e) {
        // 如果获取最新帖子失败，打印错误并返回一个表示失败的特定Map
        print('获取最新帖子失败: $e');
        return {'error': true, 'message': NetworkUtils.handleApiError(e)};
      });

      final recommendedFuture = ApiService().getRecommendedPosts(
        keywords: _searchController.text,
        topN: 10,
      ).catchError((e) {
        // 如果获取推荐帖子失败，打印错误并返回一个表示失败的特定Map
        print('获取推荐帖子失败: $e');
        return {'error': true, 'message': NetworkUtils.handleApiError(e)};
      });

      final results = await Future.wait([latestFuture, recommendedFuture]);

      final latestResponse = results[0];
      final recommendedResponse = results[1];
      
      bool anyError = false;
      String combinedErrorMessage = "";

      // 处理最新帖子结果
      if (latestResponse.containsKey('error')) {
        anyError = true;
        combinedErrorMessage += "最新帖子加载失败: ${latestResponse['message']}\n";
      } else if (latestResponse['code'] == 'SUCCESS_0000') {
        final List<dynamic> latestListRaw = safeGetList(latestResponse['data']?['list']);
        if (mounted) {
          setState(() {
            latestPostResults = latestListRaw.cast<Map<String, dynamic>>();
          });
        }
      } else {
        anyError = true;
        combinedErrorMessage += "最新帖子: ${latestResponse['info'] ?? '未知错误'}\n";
      }

      // 处理推荐帖子结果
      if (recommendedResponse.containsKey('error')) {
        anyError = true;
        combinedErrorMessage += "推荐帖子加载失败: ${recommendedResponse['message']}";
      } else if (recommendedResponse['code'] == 'SUCCESS_0000') {
        final List<dynamic> recommendedListRaw = safeGetList(recommendedResponse['data']); // 推荐API直接返回list在data下
        if (mounted) {
          setState(() {
            recommendedPostResults = recommendedListRaw.cast<Map<String, dynamic>>();
          });
        }
      } else {
        anyError = true;
        combinedErrorMessage += "推荐帖子: ${recommendedResponse['info'] ?? '未知错误'}";
      }

      if (anyError) {
        throw combinedErrorMessage.trim();
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          hasPostError = true;
          postErrorMessage = e.toString();
          // 即使部分成功，如果另一部分失败，也可能需要清空
          // 根据需求决定是否在出错时清空已成功加载的数据
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        titleSpacing: 0,
        title: Container(
          height: 40,
          margin: const EdgeInsets.only(right: 16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              filled: true,
              fillColor: Colors.grey[200], // 修改为浅灰色背景
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              hintText: '搜索',
              hintStyle: TextStyle(color: Colors.grey[600]), // 修改提示文字颜色
              suffixIcon: IconButton(
                icon: Icon(Icons.search, color: Colors.grey[600]), // 修改搜索图标颜色
                onPressed: _searchButtonPressed,
              ),
            ),
            style: TextStyle(color: Colors.grey[800]), // 修改输入文字颜色
            onSubmitted: (_) => _searchButtonPressed(),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '用户'),
            Tab(text: '帖子'),
            Tab(text: '商品'),
          ],
          indicatorColor: Theme.of(context).primaryColor,
          labelColor: Colors.black87, // 修改选中标签颜色
          unselectedLabelColor: Colors.grey[600], // 修改未选中标签颜色
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildUserTabContent(),
                _buildPostTabs(),
                _buildProductGrid(),
              ],
            ),
    );
  }

  Widget _buildPostTabs() {
    if (isLoading && (_tabController.index == 1)) {
      return const Center(child: CircularProgressIndicator());
    }
    if (hasPostError && (_tabController.index == 1)) {
      return ErrorView(
        title: '加载帖子失败',
        message: postErrorMessage,
        onRetry: _searchPosts,
      );
    }

    List<Widget> children = [];

    // 首先显示推荐帖子，如果数据不为空
    if (recommendedPostResults.isNotEmpty) {
      children.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
          child: Text('推荐帖子', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        )
      );
      children.add(
        _buildRecommendedPostListHorizontal(), // 调用横向列表构建方法
      );
      children.add(const SizedBox(height: 16)); // 添加一些间距
    }

    // 然后显示最新帖子，如果数据不为空
    if (latestPostResults.isNotEmpty) {
      children.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
          child: Text('最新帖子', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        )
      );
      children.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: _buildLatestPostListVertical(),
      ));
    }

    // 如果最新和推荐帖子都为空，并且没有错误，显示"暂无相关帖子"
    if (latestPostResults.isEmpty && recommendedPostResults.isEmpty && !hasPostError && !isLoading) {
        children.add(
           Center(
             child: Padding(
               padding: const EdgeInsets.all(20.0),
               child: Text('暂无相关帖子', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
             ),
           )
        );
    }
  
    return ListView(
      padding: const EdgeInsets.only(bottom: 20), // 为底部可能出现的推荐列表留出空间
      children: children,
    );
  }

  // 构建横向滚动的推荐帖子列表
  Widget _buildRecommendedPostListHorizontal() {
    if (recommendedPostResults.isEmpty) {
      return const SizedBox.shrink(); 
    }

    return SizedBox(
      height: 230, // 稍微增加整体高度
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: recommendedPostResults.length,
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0), // 增加一点垂直padding
        itemBuilder: (context, index) {
          final post = recommendedPostResults[index];
          final String title = post['title'] as String? ?? '无标题';
          final String imageUrl = post['images'] as String? ?? ''; // 假设 images 是单个 URL
          final String authorName = post['authorName'] as String? ?? '匿名用户';
          final String authorAvatar = post['authorAvatar'] as String? ?? '';

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PostDetailPage(
                    postId: post['id'].toString(),
                  ),
                ),
              );
            },
            child: SizedBox(
              width: 160, // 每个卡片的宽度
              child: Card(
                margin: const EdgeInsets.only(right: 8.0, bottom: 4.0), // 卡片间的右边距, 并增加底部外边距
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 100, // 图片高度
                      width: double.infinity,
                      child: _buildImage(imageUrl), // 使用已有的_buildImage方法
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14, // 字体略小
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 10, // 头像略小
                            backgroundImage: authorAvatar.isNotEmpty
                                ? NetworkImage(authorAvatar)
                                : null,
                            backgroundColor: Colors.grey[200],
                            onBackgroundImageError: (_, __) {},
                            child: authorAvatar.isEmpty ? const Icon(Icons.person, size: 12) : null,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              authorName,
                              style: TextStyle(
                                fontSize: 11, // 字体略小
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(), // 把作者信息推到底部，如果内容不足的话
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // 修改：构建垂直的最新帖子列表 (之前是 _buildLatestPostList)
  Widget _buildLatestPostListVertical() {
    if (latestPostResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Text('暂无最新内容', style: TextStyle(color: Colors.grey[400])),
        ),
      );
    }

    return Column(
      children: latestPostResults.map((post) {
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PostDetailPage(
                  postId: post['id'].toString(),
                ),
              ),
            );
          },
          child: Card(
            margin: const EdgeInsets.symmetric(vertical: 4.0), // 卡片之间的垂直间距
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox( // 给图片一个合适的比例或者固定高度
                  height: 180,
                  width: double.infinity,
                  child: _buildImage(post['images'] as String? ?? ''), // 确保调用正确的方法名
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0), // 增加内边距
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post['title'] as String? ?? '无标题',
                        style: const TextStyle(
                          fontSize: 15, // 调整字体大小
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8), // 增加间距
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundImage: NetworkImage(
                              post['authorAvatar'] as String? ?? 'https://via.placeholder.com/50',
                            ),
                            backgroundColor: Colors.grey[200],
                            onBackgroundImageError: (_, __) {},
                          ),
                          const SizedBox(width: 8), // 增加间距
                          Expanded(
                            child: Text(
                              post['authorName'] as String? ?? '匿名用户',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // 图片构建辅助方法
  Widget _buildImage(String imageUrl) {
    if (imageUrl.isEmpty) {
      return Container(
        height: 150, // 和横向列表中的图片高度保持一致或根据需要调整
        width: double.infinity,
        color: Colors.grey[200],
        child: Icon(Icons.image_not_supported, color: Colors.grey[400], size: 48),
      );
    }
    
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      height: double.infinity, // 让图片填充SizedBox的高度
      width: double.infinity,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          height: 150, // 和横向列表中的图片高度保持一致或根据需要调整
          width: double.infinity,
          color: Colors.grey[200],
          child: Icon(Icons.broken_image, color: Colors.grey[400], size: 48),
        );
      },
    );
  }

  Widget _buildUserTabContent() {
    if (hasUserError && _tabController.index == 0) {
      return _buildErrorView();
    }
    
    return _buildUserList();
  }

  Widget _buildUserList() {
    if (userResults.isEmpty) {
      return _buildEmptyView();
    }
    
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      itemCount: userResults.length + (_hasMoreUsers ? 1 : 0),
      itemBuilder: (context, index) {
        // 如果是最后一项且有更多数据，显示加载指示器
        if (index == userResults.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Center(child: SizedBox(height: 100,)),
          );
        }
        
        final user = userResults[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: user.avatarUrl.isNotEmpty
                  ? NetworkImage(user.avatarUrl)
                  : null,
              backgroundColor: Theme.of(context).primaryColor,
              child: user.avatarUrl.isEmpty
                  ? const Icon(Icons.person, color: Colors.white)
                  : null,
            ),
            title: Text(user.username),
            subtitle: Text(user.bio.isNotEmpty ? user.bio : '暂无简介'),
            trailing: Text('${user.followerCount}关注'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UserProfilePage(authorId: user.id),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPostGrid() {
    if (postResults.isEmpty) {
      return _buildEmptyView();
    }
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: MasonryGridView.count(
        controller: _tabController.index == 1 ? _scrollController : null,
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        itemCount: postResults.length,
        itemBuilder: (context, index) {
          final post = postResults[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PostDetailPage(
                    postId: post['id'].toString(),
                  ),
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
                    post['imageUrl'] as String,
                    fit: BoxFit.cover,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post['title'] as String,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundImage: NetworkImage(
                                'https://picsum.photos/50/50?random=${post['id']}',
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                post['author'] as String,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[400],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
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
    );
  }

  Widget _buildProductGrid() {
    // 如果有商品错误且当前是商品标签页，显示错误视图
    if (hasProductError && _tabController.index == 2) {
      return ErrorView(
        title: '加载商品失败',
        message: productErrorMessage,
        onRetry: _searchProducts, // Retry only product search
      );
    }
    
    if (productResults.isEmpty && !isLoading && !hasProductError && _tabController.index == 2) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text('暂无相关商品', style: TextStyle(color: Colors.grey, fontSize: 16)),
        )
      );
    }
    
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      itemCount: productResults.length + (_hasMoreProducts && _isLoadingMoreProducts ? 1 : 0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65, // Adjusted for better layout with price
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        if (index == productResults.length && _hasMoreProducts && _isLoadingMoreProducts) {
          return const Center(child: CircularProgressIndicator());
        }

        final product = productResults[index];
        final String productName = product['name'] as String? ?? '商品名称';
        final String mainImage = product['mainImage'] as String? ?? '';
        final double price = (product['price'] as num?)?.toDouble() ?? 0.0;

        return Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3, // Image takes more space
                child: AspectRatio(
                  aspectRatio: 1, // Square image, adjust if needed
                  child: mainImage.isNotEmpty
                      ? Image.network(
                          mainImage,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => 
                            Container(
                              color: Colors.grey[200],
                              alignment: Alignment.center,
                              child: const Icon(Icons.broken_image, color: Colors.grey, size: 40),
                            ),
                        )
                      : Container(
                          color: Colors.grey[200],
                          alignment: Alignment.center,
                          child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 40),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '¥${price.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    // No likes, views, or authorName as per requirement
                  ],
                )
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '未找到相关内容',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildErrorView() {
    return ErrorView(
      title: '加载失败',
      message: '搜索用户时遇到问题',
      details: userErrorMessage,
      onRetry: _performSearch,
    );
  }

  // 安全获取数据的辅助方法
  T? safeGet<T>(dynamic map, String key) {
    if (map is Map && map.containsKey(key)) {
      final value = map[key];
      if (value is T) {
        return value;
      }
    }
    return null;
  }
  
  // 安全获取列表的辅助方法
  List<Map<String, dynamic>> safeGetList(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
          .toList();
    }
    return [];
  }

  // 搜索按钮点击事件
  void _searchButtonPressed() {
    _performSearch().catchError((error) {
      // 确保即使在异常情况下也能关闭loading
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    });
  }
}