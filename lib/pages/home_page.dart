import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:link_sphere/models/post.dart';
import 'package:link_sphere/pages/cart_page.dart';
import 'package:link_sphere/pages/post_detail_page.dart';
import 'package:link_sphere/pages/search_result_page.dart';
import 'package:link_sphere/pages/order_page.dart';
import 'package:link_sphere/pages/message_page.dart';
import 'package:link_sphere/services/api_service.dart';
import 'package:link_sphere/services/noti_service.dart';
import 'package:link_sphere/services/user_service.dart';
import 'package:link_sphere/services/websocket_service.dart';
import 'login_page.dart'; // <--- 新增：导入登录页面

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  List<Post> posts = []; // 修改类型为 Post
  bool isLoading = false;
  bool hasMore = true;
  int currentPage = 1;
  final int pageSize = 10;
  final ScrollController _scrollController = ScrollController();

  // 添加 TabController
  late TabController _tabController;
  
  // 添加用户信息相关状态变量
  String _username = '';
  String _avatarUrl = '';

  // Remove StreamSubscription for notifications
  // StreamSubscription<String?>? _notificationSubscription; // <--- 移除

  @override
  void initState() {
    super.initState();
    // Call showDailyNotification with a payload
    // NotiService.showDailyNotification(
    //   title: '每日精选',
    //   body: '来看看今天有什么新鲜事！点击查看购物车。',
    //   payload: 'open_cart',
    // );
    // NotiService.showDailyNotification(
    //   title: '每日精选',
    //   body: '来看看今天有什么新鲜事！',
    //   payload: 'open_home',
    // );
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _fetchPosts();
      }
    });
    _fetchPosts();
    _scrollController.addListener(_onScroll);
    UserService.getToken().then((token) {
      debugPrint('Token: $token');
    });
    
    _loadUserInfo();

    // Listen to notification stream  // <--- 移除以下所有监听逻辑
    // _notificationSubscription = NotiService.selectNotificationStream.stream.listen((String? payload) {
    //   if (payload != null && payload.isNotEmpty) {
    //     debugPrint('HomePage: Received notification payload: $payload');
    //     if (payload == 'open_cart') {
    //       if (mounted) {
    //         Navigator.push(context, MaterialPageRoute(builder: (context) => CartPage()));
    //       }
    //     } else if (payload == 'open_orders') {
    //       if (mounted) {
    //         Navigator.push(context, MaterialPageRoute(builder: (context) => const OrderPage()));
    //       }
    //     } else if (payload == 'open_home') {
    //       if (mounted) {
    //         debugPrint("Notification action: 'open_home'. Current context is HomePage. No new HomePage pushed.");
    //       }
    //     } else if (payload == 'open_messages') {
    //       if (mounted) {
    //         // 导航到消息页面
    //         Navigator.push(
    //           context,
    //           MaterialPageRoute(
    //             builder: (context) => const MessagePage(),
    //           ),
    //         );
    //       }
    //     } else if (payload.startsWith('open_advertisement_')) {
    //       if (mounted) {
    //         // 处理广告点击
    //         final advertisementId = payload.replaceAll('open_advertisement_', '');
    //         // TODO: 导航到广告详情页面
    //         debugPrint('Opening advertisement: $advertisementId');
    //       }
    //     }
    //   }
    // });
  }
  
  // 添加加载用户信息的方法
  Future<void> _loadUserInfo() async {
    final user = await UserService.getUser();
    if (user != null && mounted) {
      setState(() {
        _username = user.username;
        _avatarUrl = user.avatarUrl;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    // _notificationSubscription?.cancel(); // Cancel the subscription // <--- 移除
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;

    if (currentScroll >= maxScroll * 0.9 && !isLoading && hasMore) {
      _fetchPosts(isLoadMore: true);
    }
  }

  Future<void> _fetchPosts({bool isLoadMore = false}) async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    try {
      final type = _tabController.index == 0 ? 'latest' : 'hot';

      final response = await ApiService().getHomePosts(
        page: isLoadMore ? currentPage + 1 : 1,
        size: pageSize,
        type: type,
      );

      if (response['code'] == 'SUCCESS_0000') {
        final List<dynamic> postList = response['data']['list'];

        // Replace print with debugPrint
        debugPrint('帖子列表数据: $postList');

        final List<Post> newPosts = [];
        for (var json in postList) {
          try {
            if (json['id'] is String) {
              json['id'] = int.tryParse(json['id'].toString()) ?? 0;
            }
            if (json['authorId'] is String) {
              json['authorId'] = int.tryParse(json['authorId'].toString()) ?? 0;
            }

            final post = Post.fromJson(json);
            newPosts.add(post);
          } catch (e) {
            debugPrint('解析帖子数据错误: $e, 数据: $json');
          }
        }

        if (!mounted) return; // Add mounted check

        setState(() {
          if (isLoadMore) {
            posts.addAll(newPosts);
            currentPage += 1;
          } else {
            posts = newPosts;
            currentPage = 1;
          }
          hasMore = type == 'hot' ? false : newPosts.length >= pageSize;
        });
      } else {
        throw response['info'] ?? '获取帖子失败';
      }
    } catch (e) {
      debugPrint('获取帖子失败: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('获取帖子失败: $e')));
    } finally {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              // 添加用户信息区域（可选）
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: _avatarUrl.isNotEmpty 
                          ? NetworkImage(_avatarUrl)
                          : null,
                      backgroundColor: Theme.of(context).primaryColor,
                      child: _avatarUrl.isEmpty 
                          ? const Icon(Icons.person, size: 30, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        _username.isNotEmpty ? _username : '未登录',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 菜单项列表
              ListTile(
                leading: const Icon(Icons.shopping_cart),
                title: const Text('我的购物车'),
                onTap: () {
                  Navigator.pop(context); // 关闭抽屉
                  Navigator.push(context, MaterialPageRoute(builder: (context)=>CartPage()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.receipt_long),
                title: const Text('我的订单'),
                onTap: () {
                  Navigator.pop(context); // 关闭抽屉
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const OrderPage(),
                    ),
                  );
                },
              ),
              const Divider(), // 分隔线
              // 可以添加更多菜单项
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('设置'),
                onTap: () {
                  Navigator.pop(context);
                  // 导航到设置页面
                },
              ),
              // 添加WebSocket测试按钮
              ListTile(
                leading: const Icon(Icons.message),
                title: const Text('发送测试消息'),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    final wsService = WebSocketService();
                    if (wsService.isConnected) {
                      final success = await wsService.sendMessage(
                        '这是一条测试消息 ${DateTime.now()}',
                        '1', // 发送给ID为1的用户
                      );
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('测试消息发送成功')),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('测试消息发送失败')),
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('WebSocket未连接')),
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('发送消息出错: $e')),
                    );
                  }
                },
              ),
              const Spacer(), // <--- 新增：用于将注销按钮推到底部
              const Divider(), // <--- 新增：分隔线
              ListTile( // <--- 新增：注销按钮
                leading: Icon(Icons.logout, color: Colors.red[700]),
                title: Text('注销', style: TextStyle(color: Colors.red[700])),
                onTap: () async {
                  // 断开WebSocket连接
                  WebSocketService().dispose();
                  // 清除用户登录状态
                  await UserService.clearUser();
                  // 关闭抽屉
                  Navigator.pop(context);
                  // 跳转到登录页并移除所有之前的路由
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                    (route) => false,
                  );
                },
              ),
              const SizedBox(height: 16), // <--- 新增：底部留白
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _fetchPosts(),
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              // 搜索栏
              SliverAppBar(
                floating: true,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                title: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[200], // 修改搜索框背景色
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: Colors.grey[600]), // 修改图标颜色
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          style: TextStyle(
                            color: Colors.grey[800], // 修改输入文字颜色
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: '搜索',
                            hintStyle: TextStyle(
                              color: Colors.grey[600], // 修改提示文字颜色
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onSubmitted: (value) {
                            if (value.trim().isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SearchResultPage(
                                    keyword: value.trim(),
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 添加 Tab 栏
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverAppBarDelegate(
                  TabBar(
                    controller: _tabController,
                    labelColor: Theme.of(context).primaryColor,
                    unselectedLabelColor: Colors.grey,
                    indicatorSize: TabBarIndicatorSize.label,
                    tabs: const [Tab(text: '最新'), Tab(text: '热门')],
                  ),
                ),
              ),

              // 瀑布流内容
              SliverPadding(
                padding: const EdgeInsets.all(8),
                sliver: SliverMasonryGrid.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childCount: posts.length + (isLoading && hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == posts.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    final post = posts[index];
                    final firstImage =
                        post.images.isNotEmpty
                            ? post.images.split(',')[0].trim()
                            : '';

                    return PostCard(
                      title: post.title,
                      content: post.content,
                      imageUrl: firstImage,
                      postId: post.id.toString(),
                      authorName: post.authorName, // Add these parameters
                      authorAvatar: post.authorAvatar,
                      likesCount: post.likesCount,
                      liked: post.liked, // 传递 liked 状态
                    );
                  },
                ),
              ),

              if (!hasMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: Text('没有更多内容了')),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// 添加 SliverPersistentHeaderDelegate 实现
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

class PostCard extends StatelessWidget {
  final String title;
  final String content;
  final String imageUrl;
  final String postId;
  final String authorName; // Add these properties
  final String authorAvatar;
  final int likesCount;
  final bool liked; // 添加 liked 属性

  const PostCard({
    super.key,
    required this.title,
    required this.content,
    required this.imageUrl,
    required this.postId,
    required this.authorName, // Add these required parameters
    required this.authorAvatar,
    required this.likesCount,
    required this.liked, // 添加 liked 到构造函数
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostDetailPage(postId: postId.toString()),
          ),
        );
      },
      child: Card(
        color: Colors.white,
        elevation: 2,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl.isNotEmpty)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Image.network(
                    'https://vcover-vt-pic.puui.qpic.cn/vcover_vt_pic/0/mzc00200aaogpgh1731229785085/0',
                    fit: BoxFit.cover,
                  );
                },
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundImage: NetworkImage(
                          authorAvatar,
                        ), // Use the property
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          authorName, // Use the property
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                      Icon(
                        liked
                            ? Icons.favorite
                            : Icons.favorite_border, // 根据 liked 状态选择图标
                        size: 16,
                        color:
                            liked
                                ? Colors.red
                                : Colors.grey[600], // 根据 liked 状态选择颜色
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$likesCount', // Use the property
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
  }
}
