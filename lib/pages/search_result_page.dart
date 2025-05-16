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

  List<Map<String, dynamic>> recommendedPostResults = [];
  List<Map<String, dynamic>> latestPostResults = [];

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
    // 当切换标签时，重置分页状态
    if (_tabController.indexIsChanging) {
      setState(() {
        _currentPage = 1;
        _hasMoreUsers = true;
      });
    }
  }
  
  Future<void> _loadMoreUsers() async {
    if (!_hasMoreUsers || isLoading || _isLoadingMore) return;
    
    print('加载更多用户，页码: ${_currentPage + 1}');
    
    setState(() {
      _isLoadingMore = true;
    });
    
    try {
      final response = await ApiService().searchUsers(
        keywords: _searchController.text,
        page: _currentPage + 1,
        size: _pageSize,
      );
      
      print('加载更多用户结果: ${response['code']}, ${response['info']}');
      
      if (response['code'] == 'SUCCESS_0000') {
        final responseDataMap = response['data'];
        if (responseDataMap is Map) {
          final List<dynamic> userListRaw = (responseDataMap['list'] as List<dynamic>?) ?? [];
          final int totalPages = (responseDataMap['pages'] as int?) ?? 1;
          
          print('加载到更多用户: ${userListRaw.length}个');
          
          final List<SearchUser> newUsers = userListRaw
              .map((json) {
                try {
                  return SearchUser.fromJson(json as Map<String, dynamic>);
                } catch (e) {
                  print('解析更多用户数据错误: $e, 数据: $json');
                  return null;
                }
              })
              .whereType<SearchUser>()
              .toList();
          
          // 更新页码和检查是否还有更多数据
          final int nextPage = _currentPage + 1;
          final bool hasMore = nextPage < totalPages;
          
          print('下一页: $nextPage, 是否还有更多: $hasMore');
          
          if (mounted) {
            setState(() {
              userResults.addAll(newUsers);
              _currentPage = nextPage;
              _hasMoreUsers = hasMore;
              _isLoadingMore = false;
            });
          }
        } else {
          print('加载更多用户时响应数据不是Map类型: $responseDataMap');
          throw '加载更多用户响应格式不正确';
        }
      } else {
        print('加载更多用户响应码不是SUCCESS_0000: ${response['code']}');
        throw response['info'] ?? '加载更多用户失败';
      }
    } catch (e) {
      print('加载更多用户出错: $e');
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
  
  void _onScroll() {
    // 只有在用户标签页且有更多数据时才处理滚动事件
    if (_tabController.index != 0 || !_hasMoreUsers || isLoading) {
      return;
    }
    
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    
    // 当滚动到底部90%位置时，加载更多数据
    if (currentScroll >= maxScroll * 0.9) {
      _loadMoreUsers();
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
    print('开始搜索: ${_searchController.text}, 页码: $_currentPage');
    
    // 添加超时保护，15秒后无论如何都关闭loading
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted && isLoading) {
        print('搜索超时，强制关闭loading状态');
        setState(() {
          isLoading = false;
        });
      }
    });
    
    setState(() {
      isLoading = true;
      hasUserError = false;
      hasPostError = false;
      hasProductError = false;
      userErrorMessage = '';
      postErrorMessage = '';
      productErrorMessage = '';
      _currentPage = 1; // 重置页码
      _hasMoreUsers = true; // 重置是否有更多数据
      userResults = []; // 清空之前的用户搜索结果
      recommendedPostResults = []; // 清空帖子结果
      latestPostResults = []; // 清空帖子结果
      productResults = []; // 清空商品结果
    });

    try {
      // 并行执行所有搜索任务
      print('并行执行搜索任务');
      
      // 构建三个搜索任务
      final userFuture = _searchUsers();
      final postFuture = _searchPosts();
      final productFuture = _searchProducts();
      
      // 等待所有任务完成（无论成功或失败）
      await Future.wait([
        userFuture.catchError((e) => print('用户搜索任务失败: $e')),
        postFuture.catchError((e) => print('帖子搜索任务失败: $e')),
        productFuture.catchError((e) => print('商品搜索任务失败: $e')),
      ]);
      
      print('所有搜索任务已完成');
    } catch (e) {
      print('_performSearch中捕获到异常: $e');
    } finally {
      // 确保无论如何都关闭loading
      if (mounted) {
        print('搜索流程完成，关闭loading状态');
        setState(() {
          isLoading = false;
        });
      }
    }
  }
  
  // 将用户搜索逻辑拆分为独立方法
  Future<void> _searchUsers() async {
    try {
      print('正在搜索用户...');
      final response = await ApiService().searchUsers(
        keywords: _searchController.text,
        page: _currentPage,
        size: _pageSize,
      );

      print('用户搜索成功，结果: ${response['code']}, ${response['info']}');

      if (response['code'] == 'SUCCESS_0000') {
        final responseDataMap = response['data'];
        if (responseDataMap is Map) {
          final List<dynamic> userListRaw = (responseDataMap['list'] as List<dynamic>?) ?? [];
          final int totalUsers = (responseDataMap['total'] as int?) ?? 0;
          final int totalPages = (responseDataMap['pages'] as int?) ?? 1;

          print('用户列表长度: ${userListRaw.length}, 总用户数: $totalUsers, 总页数: $totalPages');

          final List<SearchUser> users = userListRaw
              .map((json) {
                try {
                  return SearchUser.fromJson(json as Map<String, dynamic>);
                } catch (e) {
                  print('解析用户数据错误: $e, 数据: $json');
                  return null; 
                }
              })
              .whereType<SearchUser>() // 过滤掉解析失败的null项
              .toList();
          
          print('解析后的用户列表长度: ${users.length}');
            
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
          print('响应数据不是Map类型: $responseDataMap');
          throw '搜索用户响应格式不正确: "data"字段无效或缺失';
        }
      } else {
        print('响应码不是SUCCESS_0000: ${response['code']}');
        throw response['info'] ?? '获取用户列表失败';
      }
    } catch (e) {
      print('搜索用户出错: $e');
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
    print('开始搜索商品...');
    try {
      final response = await ApiService().searchProducts(
        keywords: _searchController.text,
        page: 1,
        size: 10,
      );
      
      print('商品搜索结果: ${response['code']}, ${response['info']}');
      
      if (response['code'] == 'SUCCESS_0000') {
        final List<dynamic> productList = response['data']['list'];
        if (mounted) {
          setState(() {
            productResults = productList.cast<Map<String, dynamic>>();
          });
        }
      } else {
        throw response['info'] ?? '获取商品失败';
      }
    } catch (e) {
      print('搜索商品出错: $e');
      if (mounted) {
        setState(() {
          hasProductError = true;
          productErrorMessage = NetworkUtils.handleApiError(e);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('搜索商品失败: ${NetworkUtils.handleApiError(e)}')),
        );
      }
    }
    // 无论成功或失败，确保返回完成的Future
    print('商品搜索完成');
  }

  Future<void> _searchPosts() async {
    print('开始搜索帖子...');

    try {
      // 获取最新帖子
      final latestResponse = await ApiService().getLatestPosts(
        keywords: _searchController.text,
        page: 1,
        size: 10,
      );

      print('最新帖子搜索结果: ${latestResponse['code']}, ${latestResponse['info']}');

      if (latestResponse['code'] == 'SUCCESS_0000') {
        final List<dynamic> latestList = latestResponse['data']['list'];
        if (mounted) {
          setState(() {
            latestPostResults = latestList.cast<Map<String, dynamic>>();
          });
        }
      } else {
        throw latestResponse['info'] ?? '获取最新帖子失败';
      }

      // 尝试获取推荐帖子，但即使失败也不影响整体功能
      try {
        final recommendedResponse = await ApiService().getRecommendedPosts(
          keywords: _searchController.text,
          topN: 10,
        );

        print('推荐帖子搜索结果: ${recommendedResponse['code']}, ${recommendedResponse['info']}');

        if (recommendedResponse['code'] == 'SUCCESS_0000') {
          final List<dynamic> recommendedList = recommendedResponse['data'];
          if (mounted) {
            setState(() {
              recommendedPostResults = recommendedList.cast<Map<String, dynamic>>();
            });
          }
        } else {
          print('推荐帖子获取失败，但不会阻止其他功能: ${recommendedResponse['info']}');
          // 推荐帖子失败时不抛出异常，使用空列表
          if (mounted) {
            setState(() {
              recommendedPostResults = [];
            });
          }
        }
      } catch (e) {
        print('推荐帖子搜索出错，但不会阻止其他功能: $e');
        // 推荐帖子错误时不抛出异常，使用空列表
        if (mounted) {
          setState(() {
            recommendedPostResults = [];
          });
        }
      }
    } catch (e) {
      print('搜索帖子出错: $e');
      if (mounted) {
        setState(() {
          hasPostError = true;
          postErrorMessage = NetworkUtils.handleApiError(e);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('搜索帖子失败: ${NetworkUtils.handleApiError(e)}')),
        );
      }
    } 
    // 无论成功或失败，确保返回完成的Future
    print('帖子搜索完成');
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
    // 如果有帖子错误且当前是帖子标签页，显示错误视图
    if (hasPostError && _tabController.index == 1) {
      return ErrorView(
        title: '加载失败',
        message: '搜索帖子时遇到问题',
        details: postErrorMessage,
        onRetry: _performSearch,
      );
    }
    
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          bottom: TabBar(
            tabs: [
              Tab(text: '推荐'),
              Tab(text: '最新'),
            ],
            indicatorColor: Theme.of(context).primaryColor,
            labelColor: Colors.black87,
            unselectedLabelColor: Colors.grey[600],
          ),
        ),
        body: TabBarView(
          children: [
            _buildRecommendedPostList(),
            _buildLatestPostList(),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendedPostList() {
    if (recommendedPostResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '暂无推荐内容',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: recommendedPostResults.length,
      itemBuilder: (context, index) {
        final post = recommendedPostResults[index];
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
                _buildPostImage(post['images'] as String? ?? ''),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post['title'] as String? ?? '无标题',
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
                              post['authorAvatar'] as String? ?? 'https://via.placeholder.com/50',
                            ),
                            backgroundColor: Colors.grey[200],
                            onBackgroundImageError: (_, __) {},
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              post['authorName'] as String? ?? '匿名用户',
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
    );
  }
  
  // 添加图片构建辅助方法，处理可能为空的情况
  Widget _buildPostImage(String imageUrl) {
    if (imageUrl.isEmpty) {
      return Container(
        height: 150,
        color: Colors.grey[200],
        child: Icon(Icons.image_not_supported, color: Colors.grey[400]),
      );
    }
    
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      height: 150,
      width: double.infinity,
      errorBuilder: (context, error, stackTrace) {
        print('图片加载错误: $error');
        return Container(
          height: 150,
          color: Colors.grey[200],
          child: Icon(Icons.broken_image, color: Colors.grey[400]),
        );
      },
    );
  }

  Widget _buildLatestPostList() {
    if (latestPostResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '暂无最新内容',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: latestPostResults.length,
      itemBuilder: (context, index) {
        final post = latestPostResults[index];
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
                _buildPostImage(post['images'] as String? ?? ''),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post['title'] as String? ?? '无标题',
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
                              post['authorAvatar'] as String? ?? 'https://via.placeholder.com/50',
                            ),
                            backgroundColor: Colors.grey[200],
                            onBackgroundImageError: (_, __) {},
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              post['authorName'] as String? ?? '匿名用户',
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
    
    // 调试信息，帮助定位问题
    print('构建用户列表: 用户数=${userResults.length}, 是否有更多=$_hasMoreUsers, 是否加载更多中=$_isLoadingMore, 当前页=$_currentPage');
    
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      itemCount: userResults.length + (_hasMoreUsers ? 1 : 0),
      itemBuilder: (context, index) {
        // 如果是最后一项且有更多数据，显示加载指示器
        if (index == userResults.length) {
          print('显示加载更多指示器: 加载中=$_isLoadingMore');
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Center(
              child: _isLoadingMore
                  ? const CircularProgressIndicator() // 正在加载更多时显示加载指示器
                  : ElevatedButton(
                      onPressed: _loadMoreUsers, // 不在加载中时显示加载更多按钮
                      child: const Text('加载更多'),
                    ),
            ),
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
        title: '加载失败',
        message: '搜索商品时遇到问题',
        details: productErrorMessage,
        onRetry: _performSearch,
      );
    }
    
    if (productResults.isEmpty) {
      return const Center(child: Text('暂无商品'));
    }
    
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: productResults.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        final product = productResults[index];
        return Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1.5,
                child: Image.network(
                  product['images']?.split(',').first.replaceAll('`', '').trim() ?? '',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  product['title'] ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  product['authorName'] ?? '',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
              // 不显示点赞数、浏览数
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
    print('搜索按钮被点击');
    _performSearch().catchError((error) {
      print('搜索过程中发生错误: $error');
      // 确保即使在异常情况下也能关闭loading
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    });
  }
}