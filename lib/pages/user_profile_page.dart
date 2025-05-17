import 'package:flutter/material.dart';
import 'dart:math'; // 用于生成随机数据
import '../models/user.dart';
import '../services/user_service.dart';
import '../services/api_service.dart';
import '../pages/chat_page.dart'; // 添加聊天页面导入
import '../models/post.dart';

// 简单的 Post 模型（如果需要更复杂的结构，可以复用 models/post.dart）
class MockPost {
  final String id;
  final String imageUrl;
  final String title;

  MockPost({required this.id, required this.imageUrl, required this.title});
}

class UserProfilePage extends StatefulWidget {
  final String authorId;

  const UserProfilePage({super.key, required this.authorId});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _userData;
  final List<Post> _userPosts = []; // 用户的笔记
  final List<Post> _likedPosts = []; // 用户赞过的帖子
  bool _isLoading = true;
  bool _isFollowing = false;
  final ApiService _apiService = ApiService();
  bool _isLoadingPosts = false; // 加载笔记的状态
  bool _isLoadingLikedPosts = false; // 加载赞过帖子的状态
  int _currentPage = 1; // 当前页码
  int _currentLikedPage = 1; // 当前赞过帖子的页码
  bool _hasMorePosts = true; // 是否还有更多笔记
  bool _hasMoreLikedPosts = true; // 是否还有更多赞过的帖子

  // 添加默认图片URL常量
  static const String defaultPostImageUrl = 'https://vcover-vt-pic.puui.qpic.cn/vcover_vt_pic/0/mzc00200s5j9upv1737603032866/0?max_age=7776000';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserData();
    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      if (_tabController.index == 0 && _userPosts.isEmpty) {
        _loadUserPosts();
      } else if (_tabController.index == 1 && _likedPosts.isEmpty) {
        _loadLikedPosts();
      }
    }
  }

  Future<void> _loadUserData() async {
    try {
      final response = await _apiService.getUserInfo(int.parse(widget.authorId));
      if (response['code'] == 'SUCCESS_0000') {
        setState(() {
          _userData = response['data'];
          _isFollowing = _userData!['follow'] ?? false;
          _isLoading = false;
        });
        // 加载用户数据成功后，立即加载笔记数据
        _loadUserPosts();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response['info'] ?? '获取用户信息失败')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载用户信息出错: $e')),
        );
      }
    }
  }

  Future<void> _handleFollowAction() async {
    if (_userData == null) return;

    try {
      final userId = widget.authorId;
      Map<String, dynamic> response;
      
      if (_isFollowing) {
        // 取消关注
        response = await _apiService.unfollowUser(userId);
      } else {
        // 关注
        response = await _apiService.followUser(userId);
      }

      if (response['code'] == 'SUCCESS_0000') {
        setState(() {
          _isFollowing = !_isFollowing;
          // 更新粉丝数
          if (_userData != null) {
            _userData!['followerCount'] = (_userData!['followerCount'] ?? 0) + (_isFollowing ? 1 : -1);
            // 更新关注状态
            _userData!['follow'] = _isFollowing;
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isFollowing ? '关注成功' : '已取消关注')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['info'] ?? '操作失败')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失败: $e')),
      );
    }
  }

  // 加载用户的笔记
  Future<void> _loadUserPosts() async {
    if (_isLoadingPosts || !_hasMorePosts) return;

    setState(() {
      _isLoadingPosts = true;
    });

    try {
      final response = await _apiService.getAuthorPosts(
        page: _currentPage,
        size: 10,
      );

      if (response['code'] == 'SUCCESS_0000') {
        final List<dynamic> postsData = response['data']['list'] ?? [];
        final List<Post> newPosts = postsData.map((data) => Post.fromJson(data)).toList();

        setState(() {
          _userPosts.addAll(newPosts);
          _currentPage++;
          _hasMorePosts = newPosts.length >= 10;
          _isLoadingPosts = false;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response['info'] ?? '获取笔记失败')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载笔记失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPosts = false;
        });
      }
    }
  }

  // 加载用户赞过的帖子
  Future<void> _loadLikedPosts() async {
    if (_isLoadingLikedPosts || !_hasMoreLikedPosts) return;

    setState(() {
      _isLoadingLikedPosts = true;
    });

    try {
      final response = await _apiService.getLikedPosts(widget.authorId);

      if (response['code'] == 'SUCCESS_0000' && response['data'] != null) {
        final List<dynamic> postList = response['data']['list'] ?? [];
        final List<Post> newPosts = postList.map((data) => Post.fromJson(data)).toList();

        setState(() {
          _likedPosts.addAll(newPosts);
          _currentLikedPage++;
          _hasMoreLikedPosts = newPosts.length >= 10;
          _isLoadingLikedPosts = false;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response['info'] ?? '获取赞过的帖子失败')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载赞过的帖子失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLikedPosts = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('用户主页')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // 获取 AppBar 的默认高度和状态栏高度
    final double appBarHeight = AppBar().preferredSize.height; // 通常是 kToolbarHeight
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double topPaddingForBackground = appBarHeight + statusBarHeight;

    return Scaffold(
      body: SafeArea(
        top: false, // SafeArea 由 NestedScrollView 处理
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                // --- 修改：进一步增加 expandedHeight ---
                expandedHeight: 320.0, // 增加展开高度，例如到 320
                // --- 修改结束 ---
                floating: false,
                pinned: true,
                backgroundColor: Colors.white,
                elevation: 0.5,
                flexibleSpace: FlexibleSpaceBar(
                  background: _buildUserInfoSection(topPaddingForBackground),
                  // 可以选择性地添加 title，它会在折叠时显示
                  // title: Text(_mockUserData['username'], style: TextStyle(color: Colors.black)),
                  // centerTitle: true, // 根据需要设置
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.more_horiz, color: Colors.black),
                    onPressed: () {
                      // TODO: 实现更多操作
                    },
                  ),
                ],
                leading: IconButton( // 添加返回按钮
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              SliverPersistentHeader(
                delegate: _SliverAppBarDelegate(
                  TabBar(
                    controller: _tabController,
                    labelColor: Colors.black,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.black,
                    tabs: const [
                      Tab(text: '笔记'),
                      Tab(text: '赞过'),
                    ],
                  ),
                ),
                pinned: true, // TabBar 固定在 AppBar 下方
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              // "笔记" Tab 的内容
              _buildPostsGrid(_userPosts, _isLoadingPosts),
              // "赞过" Tab 的内容
              _buildPostsGrid(_likedPosts, _isLoadingLikedPosts),
            ],
          ),
        ),
      ),
    );
  }

  // 构建用户信息部分 - 接收 topPadding 参数
  Widget _buildUserInfoSection(double topPadding) {
    if (_userData == null) {
      return const Center(child: Text('用户信息加载失败'));
    }

    const String defaultAvatarUrl = 'https://tvpic.gtimg.cn/head/c2010ebc0c8b6d8521373ffeced635c8da39a3ee5e6b4b0d3255bfef95601890afd80709/361?imageView2/2/w/100';

    return SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.only(top: topPadding + 16, left: 16, right: 16, bottom: 16),
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: NetworkImage(_userData!['avatarUrl'] ?? defaultAvatarUrl),
                  onBackgroundImageError: (exception, stackTrace) {
                    // 当图片加载失败时，使用默认头像
                    setState(() {
                      _userData!['avatarUrl'] = defaultAvatarUrl;
                    });
                  },
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn('关注', _userData!['followCount']?.toString() ?? '0'),
                      _buildStatColumn('粉丝', _userData!['followerCount']?.toString() ?? '0'),
                      _buildStatColumn('获赞与收藏', _userData!['favoriteCount']?.toString() ?? '0'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _userData!['username'] ?? '',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              _userData!['bio'] ?? '',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _handleFollowAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isFollowing ? Colors.grey : Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(_isFollowing ? '已关注' : '关注'),
                  ),
                ),
                if (_isFollowing) ...[
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () {
                      // 跳转到聊天页面
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatPage(
                            username: _userData!['username'] ?? '',
                            avatar: _userData!['avatarUrl'] ?? defaultAvatarUrl,
                            friendId: widget.authorId,
                          ),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Colors.grey),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text('私信'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 构建统计数据列
  Widget _buildStatColumn(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  // 构建帖子网格
  Widget _buildPostsGrid(List<Post> posts, bool isLoading) {
    if (posts.isEmpty && !isLoading) {
      return const Center(child: Text('暂无内容'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 0.75,
      ),
      itemCount: posts.length + (isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == posts.length) {
          return const Center(child: CircularProgressIndicator());
        }

        final post = posts[index];
        return Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                post.images.isNotEmpty ? post.images[0] : defaultPostImageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Image.network(
                  defaultPostImageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(Icons.broken_image),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                    ),
                  ),
                  child: Text(
                    post.title,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// TabBar 固定代理 (与 ProfilePage 中的类似)
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white, // 背景色设为白色
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}