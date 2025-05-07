import 'package:flutter/material.dart';
import 'dart:math'; // 用于生成随机数据

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
  Map<String, dynamic> _mockUserData = {};
  List<MockPost> _mockPosts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // 假设有 "笔记" 和 "赞过" 两个Tab
    _loadMockData();
  }

  Future<void> _loadMockData() async {
    // 模拟网络延迟
    await Future.delayed(const Duration(milliseconds: 500));

    // 模拟用户信息 (可以根据 authorId 生成不同的假数据，但这里简化处理)
    _mockUserData = {
      'username': '用户${widget.authorId}',
      'avatarUrl': 'https://picsum.photos/seed/${widget.authorId}/200/200', // 使用 authorId 作为种子
      'bio': '这是用户 ${widget.authorId} 的简介，欢迎关注！',
      'followerCount': Random().nextInt(5000) + 100,
      'followingCount': Random().nextInt(500) + 10,
      'likedCount': Random().nextInt(10000) + 500, // 获赞与收藏数
    };

    // 模拟帖子列表
    _mockPosts = List.generate(
      Random().nextInt(15) + 5, // 随机生成 5 到 20 个帖子
      (index) => MockPost(
        id: 'post_${widget.authorId}_$index',
        imageUrl: 'https://picsum.photos/seed/${widget.authorId}_post_$index/300/400',
        title: '用户 ${widget.authorId} 的笔记 $index',
      ),
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
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
              _buildPostsGrid(_mockPosts),
              // "赞过" Tab 的内容 (暂时也用同样的帖子列表)
              _buildPostsGrid(_mockPosts.reversed.toList()), // 可以用不同的假数据
            ],
          ),
        ),
      ),
    );
  }

  // 构建用户信息部分 - 接收 topPadding 参数
  Widget _buildUserInfoSection(double topPadding) {
    return Container(
      // 使用传入的 topPadding
      padding: EdgeInsets.only(top: topPadding + 16, left: 16, right: 16, bottom: 16), // 在 AppBar 高度基础上再加一点间距
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // 让 Column 包裹内容
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundImage: NetworkImage(_mockUserData['avatarUrl']),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatColumn('关注', _mockUserData['followingCount'].toString()),
                    _buildStatColumn('粉丝', _mockUserData['followerCount'].toString()),
                    _buildStatColumn('获赞与收藏', _mockUserData['likedCount'].toString()),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _mockUserData['username'],
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _mockUserData['bio'],
            style: const TextStyle(fontSize: 14, color: Colors.grey),
            maxLines: 2, // 限制简介行数防止溢出
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: 实现关注/取消关注逻辑
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, // 小红书风格
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text('关注'), // 按钮文字需要根据状态变化
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {
                  // TODO: 实现私信逻辑
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
          ),
        ],
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
  Widget _buildPostsGrid(List<MockPost> posts) {
    if (posts.isEmpty) {
      return const Center(child: Text('暂无内容'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // 每行显示2个
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 0.75, // 调整宽高比
      ),
      itemCount: posts.length,
      itemBuilder: (context, index) {
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
                post.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image)),
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