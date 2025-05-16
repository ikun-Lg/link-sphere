import 'package:flutter/material.dart';
import 'package:link_sphere/models/post.dart';
import 'package:link_sphere/pages/edit_profile_page.dart';
import 'package:link_sphere/pages/post_detail_page.dart';
import 'package:link_sphere/services/api_service.dart';
import 'package:link_sphere/services/user_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController(); // 添加 ScrollController
  // 粉丝数
  int _followerCount = 0;
  // 关注数
  int _followingCount = 0;
  // 收藏数
  int _favoriteCount = 0;
  // 年龄
  int _age = 0;
  // 简介
  String _bio = '';
  // 头像url
  String _avatarUrl = '';
  // 用户名
  String _username = '';
  List<Post> _posts = []; // 用户发布的帖子 ("笔记")
  bool _isLoading = false; // "笔记" 标签页的加载状态
  List<Post> _collectedPosts = []; // 用户收藏的帖子
  bool _isCollectedLoading = false; // "收藏" 标签页的加载状态
  List<Post> _likedPosts = []; // 用户点赞的帖子
  bool _isLikedLoading = false; // "赞过" 标签页的加载状态

  // --- Add pagination state variables for "笔记" ---
  int _currentPage = 1; // 当前笔记页码
  bool _hasMorePosts = true; // 是否还有更多笔记
  bool _isLoadingMorePosts = false; // 是否正在加载更多笔记
  // --- Add pagination state variables end ---

  // --- Add pagination state variables for "收藏" ---
  int _currentCollectedPage = 1; // 当前收藏页码
  bool _hasMoreCollected = true; // 是否还有更多收藏
  bool _isLoadingMoreCollected = false; // 是否正在加载更多收藏
  // --- Add pagination state variables end ---

  // 可以为收藏和点赞也添加分页状态，但这里仅为笔记添加
  // int _currentLikedPage = 1;
  // bool _hasMoreLiked = true;
  // bool _isLoadingMoreLiked = false;


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserInfo();
    _loadPosts(); // 初始加载 "笔记"

    _tabController.addListener(_handleTabSelection);
    _scrollController.addListener(_onScroll); // 添加滚动监听
    // 监听页面返回时刷新（如从编辑资料页返回）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ModalRoute.of(context)?.addScopedWillPopCallback(() async {
        await _loadUserInfo();
        return true;
      });
    });
  }

  // --- 添加滚动监听方法 ---
  void _onScroll() {
    // 只在"笔记"标签页且未在加载更多且还有更多数据时触发
    if (_tabController.index == 0 &&
        !_isLoadingMorePosts &&
        _hasMorePosts &&
        _scrollController.position.extentAfter < 300) { // 距离底部 300 时开始加载
      _loadPosts(loadMore: true);
    }
    // 可以为其他 Tab 添加类似逻辑
    // else if (_tabController.index == 1 && !_isLoadingMoreCollected && _hasMoreCollected && ...) {
    //   _loadCollectedPosts(loadMore: true);
    // }
    // else if (_tabController.index == 2 && !_isLoadingMoreLiked && _hasMoreLiked && ...) {
    //   _loadLikedPosts(loadMore: true);
    // }
  }
  // --- 滚动监听方法结束 ---


  Future<void> _loadUserInfo() async {
    final user = await UserService.getUser();
    if (user != null) { // 添加 null 检查
      print('用户信息：');
      print(user.toJson());
      setState(() { // 在 setState 中更新状态
        _username = user.username;
        _age = user.age;
        _bio = user.bio;
        _avatarUrl = user.avatarUrl;
        _followerCount = user.followerCount;
        _followingCount = user.followCount;
        _favoriteCount = user.favoriteCount;
      });
    } else {
      // 处理获取用户信息失败的情况，例如显示错误提示或默认值
      print('获取用户信息失败');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法加载用户信息')),
        );
      }
    }
  }


  // --- 修改：_loadPosts 方法以支持分页 ---
  Future<void> _loadPosts({bool loadMore = false}) async {
    // 如果是加载更多，但已经在加载或没有更多数据了，则直接返回
    if (loadMore && (_isLoadingMorePosts || !_hasMorePosts)) return;
    // 如果是初始加载，但已经在加载，则直接返回
    if (!loadMore && _isLoading) return;

    setState(() {
      if (loadMore) {
        _isLoadingMorePosts = true; // 设置加载更多状态
      } else {
        _isLoading = true; // 设置初始加载状态
        _currentPage = 1; // 重置页码
        _posts = []; // 清空列表
        _hasMorePosts = true; // 重置是否有更多
      }
    });

    try {
      final apiService = ApiService();
      // 传递当前页码
      final response = await apiService.getAuthorPosts(page: _currentPage);
      print('Posts Response (Page $_currentPage): $response');

      // --- 修改：处理分页数据 ---
      // --- 修改：检查 response['data'] 是否为 Map 且包含 'list' ---
      if (response['code'] == 'SUCCESS_0000' && response['data'] is Map && response['data']['list'] is List) {
        // --- 修改：从 response['data']['list'] 获取列表 ---
        final List<dynamic> postListJson = response['data']['list'] ?? [];
        // --- 修改结束 ---
        final List<Post> newPosts = postListJson.map((json) => Post.fromJson(json)).toList();

        setState(() {
          _posts.addAll(newPosts); // 追加新数据
          _currentPage++; // 页码增加
          // 判断是否还有更多数据（例如，返回的数据量小于请求的 size）
          // 假设每页大小为 10 (与 ApiService 默认值一致)
          if (newPosts.length < 10) {
            _hasMorePosts = false;
          }
        });
        print('加载帖子成功: ${_posts.length} 条帖子, HasMore: $_hasMorePosts');
      } else {
        // --- 修改：处理 data 不是预期 Map 或 list 不存在的情况 ---
        String errorInfo = response['info'] ?? '未知错误';
        if (response['data'] == null || response['data']['list'] == null) {
          errorInfo = '返回数据格式不正确';
          // 如果是因为数据为空导致 list 不存在，可以认为没有更多数据了
          if (response['data'] is Map && response['data']['list'] == null) {
             _hasMorePosts = false;
          }
        }
        print('加载笔记失败: $errorInfo');
        // --- 修改结束 ---
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('加载笔记失败: $errorInfo')),
           );
         }
         // 加载失败时，可以考虑设置 _hasMorePosts = false 避免无限重试
         setState(() {
           _hasMorePosts = false;
         });
      }
      // --- 修改结束 ---
    } catch (e) {
      print('加载笔记失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载笔记失败: $e')));
      }
      // 异常时也设置 _hasMorePosts = false
      setState(() {
         _hasMorePosts = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          if (loadMore) {
            _isLoadingMorePosts = false; // 结束加载更多状态
          } else {
            _isLoading = false; // 结束初始加载状态
          }
        });
      }
    }
  }
  // --- 修改结束 ---

  // --- 可以类似地修改 _loadCollectedPosts 和 _loadLikedPosts 以支持分页 ---
  Future<void> _loadCollectedPosts({bool loadMore = false}) async {
    // 如果是加载更多，但已经在加载或没有更多数据了，则直接返回
    if (loadMore && (_isLoadingMoreCollected || !_hasMoreCollected)) return;
    // 如果是初始加载，但已经在加载，则直接返回
    if (!loadMore && _isCollectedLoading) return;

    final user = await UserService.getUser();
    if (user == null) {
      print('无法获取用户ID来加载收藏列表');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先登录以查看收藏')),
        );
      }
      // 如果未登录，也设置没有更多数据，避免无限触发
      if (mounted) {
        setState(() {
          _hasMoreCollected = false;
          _isCollectedLoading = false; // 确保初始加载状态被重置
          _isLoadingMoreCollected = false; // 确保加载更多状态被重置
        });
      }
      return;
    }

    setState(() {
      if (loadMore) {
        _isLoadingMoreCollected = true; // 设置加载更多状态
      } else {
        _isCollectedLoading = true; // 设置初始加载状态
        _currentCollectedPage = 1; // 重置页码
        _collectedPosts = []; // 清空列表
        _hasMoreCollected = true; // 重置是否有更多
      }
    });

    try {
      final apiService = ApiService();
      // 传递用户ID和当前页码
      final response = await apiService.getCollectedPosts(
        user.id.toString(),
        page: _currentCollectedPage,
      );
      print('Collected Posts Response (Page $_currentCollectedPage): $response');

      if (response['code'] == 'SUCCESS_0000' &&
          response['data'] is Map &&
          response['data']['list'] is List) {
        final List<dynamic> postListJson = response['data']['list'] ?? [];
        final List<Post> newPosts =
            postListJson.map((json) => Post.fromJson(json)).toList();

        setState(() {
          _collectedPosts.addAll(newPosts); // 追加新数据
          _currentCollectedPage++; // 页码增加
          // 判断是否还有更多数据（假设每页大小为 10）
          if (newPosts.length < 10) {
            _hasMoreCollected = false;
          }
        });
        print('加载收藏帖子成功: ${_collectedPosts.length} 条帖子, HasMore: $_hasMoreCollected');
      } else {
        String errorInfo = response['info'] ?? '未知错误';
        if (response['data'] == null || response['data']['list'] == null) {
          errorInfo = '返回数据格式不正确';
          if (response['data'] is Map && response['data']['list'] == null) {
            _hasMoreCollected = false;
          }
        }
        print('加载收藏失败: $errorInfo');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('加载收藏失败: $errorInfo')),
          );
        }
        setState(() {
          _hasMoreCollected = false;
        });
      }
    } catch (e) {
      print('加载收藏帖子异常: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载收藏失败: $e')),
        );
      }
      setState(() {
        _hasMoreCollected = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          if (loadMore) {
            _isLoadingMoreCollected = false; // 结束加载更多状态
          } else {
            _isCollectedLoading = false; // 结束初始加载状态
          }
        });
      }
    }
  }
  // --- 分页修改结束 ---

  // --- _loadLikedPosts 保持不变，或按需修改 ---
  Future<void> _loadLikedPosts(/*{bool loadMore = false}*/) async {
    final user = await UserService.getUser();
    if (user == null) {
       print('无法获取用户ID来加载点赞列表');
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('请先登录以查看点赞')),
         );
       }
       return;
    }

    setState(() {
      _isLikedLoading = true;
    });

    try {
      final apiService = ApiService();
       final user = await UserService.getUser();
       if (user == null) throw '用户未登录';
      // final response = await apiService.getLikedPosts(user.id.toString(), page: _currentLikedPage);
      final response = await apiService.getLikedPosts(user.id.toString()); // 暂时不分页
      print('Liked Posts Response: $response');

      if (response['code'] == 'SUCCESS_0000' && response['data'] != null) {
        final List<dynamic> postList = response['data']['list'] ?? [];
        setState(() {
          // if (!loadMore) _likedPosts.clear();
           _likedPosts = postList.map((json) => Post.fromJson(json)).toList(); // 暂时覆盖
          // _likedPosts.addAll(postList.map((json) => Post.fromJson(json)).toList());
          // _currentLikedPage++;
          // if (postList.length < 10) _hasMoreLiked = false;
        });
        print('加载点赞帖子成功: ${_likedPosts.length} 条帖子');
      } else {
        print('加载点赞帖子失败: ${response['info']}');
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('加载点赞失败: ${response['info']}')),
           );
         }
         // setState(() => _hasMoreLiked = false);
      }
    } catch (e) {
      print('加载点赞帖子异常: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载点赞失败: $e')),
        );
      }
      // setState(() => _hasMoreLiked = false);
    } finally {
      if (mounted) {
        setState(() {
          _isLikedLoading = false;
          // _isLoadingMoreLiked = false;
        });
      }
    }
  }
  // --- 分页修改结束 ---


  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _scrollController.removeListener(_onScroll); // 移除滚动监听
    _tabController.dispose();
    _scrollController.dispose(); // 释放 ScrollController
    super.dispose();
  }

  void _handleTabSelection() {
     if (!_tabController.indexIsChanging) {
        final index = _tabController.index;
        // 每次切换 Tab 都尝试加载 (如果不在加载中的话)
        if (index == 0 && !_isLoading && !_isLoadingMorePosts) { // 避免重复加载
           _loadPosts(loadMore: false); // 强制刷新第一页
        } else if (index == 1 && !_isCollectedLoading) {
          _loadCollectedPosts(); // 每次都加载收藏
        } else if (index == 2 && !_isLikedLoading) {
          _loadLikedPosts(); // 每次都加载赞过
        }
      }
  }


  Future<void> _handleDeletePost(String postId) async {
    // 显示确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: const Text('确定要删除这篇笔记吗？此操作无法撤销。'),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'),
              onPressed: () {
                Navigator.of(context).pop(false); // 返回 false 表示取消
              },
            ),
            TextButton(
              child: const Text('删除', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop(true); // 返回 true 表示确认
              },
            ),
          ],
        );
      },
    );

    // 如果用户确认删除
    if (confirmed == true) {
      try {
        final apiService = ApiService();
        final response = await apiService.deletePost(postId);

        if (response['code'] == 'SUCCESS_0000') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('删除成功')),
            );
            // --- 修改：调用 _loadPosts(loadMore: false) 刷新第一页 ---
            _loadPosts(loadMore: false);
            // --- 修改结束 ---
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('删除失败: ${response['info']}')),
            );
          }
        }
      } catch (e) {
        print('删除帖子异常: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: $e')),
          );
        }
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
    
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController, // 关联 ScrollController
          slivers: [
            // 用户信息部分
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundImage: NetworkImage(
                           _avatarUrl.isNotEmpty ? _avatarUrl: 'https://tvpic.gtimg.cn/head/31a13aa3a7bc4750a728131ab196f799da39a3ee5e6b4b0d3255bfef95601890afd80709/297?imageView2/2/w/100',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _username,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '年龄: $_age',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) =>  EditProfilePage()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: const Text('编辑资料'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _bio.isNotEmpty ? _bio : '这个人很懒，还没有填写简介',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatColumn('获赞', '0'), // TODO: 替换为实际获赞数
                        _buildStatColumn('关注', _followingCount.toString()),
                        _buildStatColumn('粉丝', _followerCount.toString()),
                        _buildStatColumn('收藏', _favoriteCount.toString()),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: '笔记'),
                    Tab(text: '收藏'),
                    Tab(text: '赞过'),
                  ],
                  indicatorColor: Theme.of(context).primaryColor,
                  labelColor: Theme.of(context).primaryColor,
                  unselectedLabelColor: Colors.grey,
                  labelStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                  ),
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.label,
                ),
              ),
            ),
            // 根据 Tab 显示内容的 Builder
            Builder(builder: (context) {
              final currentIndex = _tabController.index;
              List<Post> currentList;
              bool currentLoadingState;
              String emptyMessage;
              bool isLoadingMore; // 新增：是否在加载更多
              bool hasMore; // 新增：是否还有更多

              switch (currentIndex) {
                case 0: // 笔记
                  currentList = _posts;
                  currentLoadingState = _isLoading;
                  emptyMessage = '暂无笔记';
                  isLoadingMore = _isLoadingMorePosts; // 使用笔记的加载更多状态
                  hasMore = _hasMorePosts; // 使用笔记的是否还有更多状态
                  break;
                case 1: // 收藏
                  currentList = _collectedPosts;
                  currentLoadingState = _isCollectedLoading;
                  emptyMessage = '暂无收藏';
                  // 暂时不分页，所以这些是 false
                  isLoadingMore = false; // _isLoadingMoreCollected;
                  hasMore = false; // _hasMoreCollected;
                  break;
                case 2: // 赞过
                  currentList = _likedPosts;
                  currentLoadingState = _isLikedLoading;
                  emptyMessage = '暂无点赞';
                  // 暂时不分页
                  isLoadingMore = false; // _isLoadingMoreLiked;
                  hasMore = false; // _hasMoreLiked;
                  break;
                default:
                  currentList = [];
                  currentLoadingState = false;
                  emptyMessage = '';
                  isLoadingMore = false;
                  hasMore = false;
              }

              // 初始加载状态
              if (currentLoadingState && currentList.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              // 空状态
              if (currentList.isEmpty && !currentLoadingState) {
                 return SliverFillRemaining(
                   child: Center(child: Text(emptyMessage)),
                 );
              }

              // --- 修改：使用 SliverPadding 包裹 SliverGrid，并添加加载更多指示器 ---
              return SliverPadding( // 添加 Padding
                padding: const EdgeInsets.all(8.0), // Grid 周围的 Padding
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.8, // 可以根据内容调整
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      // 如果是最后一项且正在加载更多，显示加载指示器
                      if (index == currentList.length && isLoadingMore) {
                        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                      }
                      // 如果是最后一项且没有更多了，可以显示 "没有更多了"
                      if (index == currentList.length && !hasMore && currentList.isNotEmpty) {
                         // 只在笔记 Tab 显示 "没有更多了"
                         if (currentIndex == 0) {
                            return Container(
                              width: double.infinity,
                              alignment: Alignment.center,
                              child: const Center(child: Text("--- 没有更多了 ---", style: TextStyle(color: Colors.grey)))
                            );
                         } else {
                           return const SizedBox.shrink(); // 其他 Tab 不显示
                         }
                      }
                      // 正常显示帖子项
                      if (index < currentList.length) {
                        final post = currentList[index];
                        final imageList = post.images.split(',');
                        final firstImage = imageList.isNotEmpty ? imageList[0] : '';

                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PostDetailPage(
                                  postId: post.id.toString(),
                                ),
                              ),
                            );
                          },
                          // --- 修改：添加长按删除功能 ---
                          onLongPress: () {
                            // 只允许在 "笔记" Tab 删除自己的帖子
                            if (currentIndex == 0) {
                              _handleDeletePost(post.id.toString());
                            }
                          },
                          // --- 修改结束 ---
                          child: Card(
                            clipBehavior: Clip.antiAlias,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: firstImage.isNotEmpty
                                      ? Image.network(
                                          firstImage,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          // 添加加载和错误处理
                                          loadingBuilder: (context, child, loadingProgress) {
                                            if (loadingProgress == null) return child;
                                            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                                          },
                                          errorBuilder: (context, error, stackTrace) {
                                            return Image.network(
                                              'https://vcover-vt-pic.puui.qpic.cn/vcover_vt_pic/0/mzc00200n53vkqc1740479282101/0',
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              height: double.infinity,
                                              errorBuilder: (context, error, stackTrace) {
                                                return const Center(child: Icon(Icons.broken_image, color: Colors.grey));
                                              },
                                            );
                                          },
                                        )
                                      : Container( // 如果没有图片，显示占位符
                                          color: Colors.grey[200],
                                          child: const Center(child: Icon(Icons.image_not_supported, color: Colors.grey)),
                                        ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    post.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                  ),
                                ),
                                // 可以选择性地添加作者头像和昵称等信息
                                // Padding(
                                //   padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                //   child: Row(...)
                                // ),
                              ],
                            ),
                          ),
                        );
                      }
                      return null; // Should not happen
                    },
                    // --- 修改：childCount 需要考虑加载指示器和 "没有更多" 提示 ---
                    childCount: currentList.length + (isLoadingMore || (!hasMore && currentList.isNotEmpty && currentIndex == 0) ? 1 : 0),
                    // --- 修改结束 ---
                  ),
                ),
              );
              // --- 修改结束 ---
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String title, String count) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(title, style: TextStyle(color: Colors.grey[600])),
      ],
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
