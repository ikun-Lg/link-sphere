import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:link_sphere/pages/cart_page.dart';
import 'package:link_sphere/pages/chat_page.dart';
import 'package:link_sphere/pages/order_page.dart'; //确保导入 OrderPage
import 'package:link_sphere/services/noti_service.dart';
import 'package:link_sphere/services/user_service.dart';
import 'pages/home_page.dart';
import 'pages/discover_page.dart';
import 'pages/message_page.dart';
import 'pages/profile_page.dart';
import 'pages/register_page.dart'; // 添加注册页面导入
import 'pages/create_post_page.dart'; // 添加创作页面导入
import 'pages/login_page.dart'; // <--- 新增：导入登录页面
import 'services/api_service.dart'; // <--- 新增：导入 ApiService
import 'package:flutter/services.dart'; // For Clipboard
import 'package:link_sphere/pages/post_detail_page.dart'; // For navigation
import 'package:link_sphere/services/websocket_service.dart';

// GlobalKey for NavigatorState
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotiService.initNotification();
  await UserService.init();
  
  // 添加全局错误处理
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    print('全局错误: ${details.exception}');
    print('堆栈跟踪: ${details.stack}');
  };

  // 检查并连接WebSocket
  final wsService = WebSocketService();
  final connected = await wsService.checkAndConnect();
  print('WebSocket自动连接${connected ? "成功" : "失败"}');
  
  String initialRoute = '/login'; // 默认为登录页
  final token = await UserService.getToken();
  if (token != null && token.isNotEmpty) {
    final apiService = ApiService();
    final isValid = await apiService.validateToken(token);
    if (isValid) {
      initialRoute = '/home'; // Token有效，进入主页
    }
  }

  runApp(MyApp(initialRoute: initialRoute));
}

class MyApp extends StatefulWidget {
  final String initialRoute;
  const MyApp({super.key, required this.initialRoute});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final bool _isWebSocketInitialized = false;
  StreamSubscription<String?>? _notificationSubscription; // 新增 StreamSubscription

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkClipboardForSharedPost();
    _setupNotificationListener(); // 新增调用
  }

  // --- 新增：设置通知监听 --- 
  void _setupNotificationListener() {
    _notificationSubscription = NotiService.selectNotificationStream.stream.listen((String? payload) { // <--- 修改处
      if (payload != null) {
        try {
          // Try to decode as JSON first for structured payloads
          Map<String, dynamic> payloadData = {};
          bool isJson = false;
          try {
            payloadData = jsonDecode(payload);
            isJson = true;
          } catch (e) {
            // Not a JSON payload, treat as simple string
            isJson = false;
          }

          if (isJson) {
            final String? type = payloadData['type'];

            if (type == 'chat') {
              print('lg');
              final String? senderId = payloadData['senderId'];
              final String? senderName = payloadData['senderName'];
               String? senderAvatar = payloadData['senderAvatar'];
              print((senderId != null && senderName != null && senderAvatar != null));
              senderAvatar ?? (senderAvatar = "https://tvpic.gtimg.cn/head/c2010ebc0c8b6d8521373ffeced635c8da39a3ee5e6b4b0d3255bfef95601890afd80709/361?imageView2/2/w/100");
              if (senderId != null && senderName != null) {
                navigatorKey.currentState?.push(
                  MaterialPageRoute(
                    builder: (context) => ChatPage(
                      receiverId: senderId,
                      receiverName: senderName,
                      receiverAvatar: senderAvatar ?? "https://tvpic.gtimg.cn/head/c2010ebc0c8b6d8521373ffeced635c8da39a3ee5e6b4b0d3255bfef95601890afd80709/361?imageView2/2/w/100",
                    ),
                  ),
                );
              }
            } else if (type == 'advertisement' || type == 'post') {
              final String? id = payloadData['id']?.toString();
              if (id != null) {
                // 假设有 PostDetailPage，并且它接收 postId
                // navigatorKey.currentState?.push(
                //   MaterialPageRoute(
                //     builder: (context) => PostDetailPage(postId: id),
                //   ),
                // );
                debugPrint('导航到帖子/广告详情页: $id'); // 替换为实际的导航逻辑
              }
            } else if (type == 'product') {
              final String? id = payloadData['id']?.toString();
              if (id != null) {
                // 假设有 ProductDetailPage，并且它接收 productId
                // navigatorKey.currentState?.push(
                //   MaterialPageRoute(
                //     builder: (context) => ProductDetailPage(productId: int.parse(id)),
                //   ),
                // );
                debugPrint('导航到商品详情页: $id'); // 替换为实际的导航逻辑
              }
            }
          } else {
            // Handle simple string payloads
            if (payload == 'open_messages') {
               navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const MessagePage()));
            } else if (payload == 'open_cart') {
               navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => CartPage())); // Ensure CartPage is imported if not const
            } else if (payload == 'open_home') {
              // 首页可能不需要特殊导航，或者根据需求调整
              debugPrint("Notification action: 'open_home'. Current context is MyApp. No new HomePage pushed if already on home.");
            } else if (payload == 'open_orders') { // <--- 新增处理 open_orders
              navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => const OrderPage()));
            } else if (payload.startsWith('open_advertisement_')) { // Fallback for older advertisement format if needed
                final advertisementId = payload.replaceAll('open_advertisement_', '');
                // TODO: 导航到广告详情页面, e.g., using a specific page or showing a dialog
                debugPrint('Opening advertisement (legacy format): $advertisementId');
            }
          }
        } catch (e) {
          debugPrint('解析或处理通知 payload 失败: $e. Payload: $payload');
        }
      }
    });
  }
  // --- 新增结束 ---

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationSubscription?.cancel(); // 取消监听
    super.dispose();
  }

  // 定时发送通知
  void sendLocalNotifi() {
    // 随机通知内容列表
    final List<Map<String, String>> notifications = [
      {
        'title': '每日精选',
        'body': '来看看今天有什么新鲜事！点击查看购物车。',
        'payload': 'open_cart'
      },
      {
        'title': '新消息提醒',
        'body': '您有新的消息待查看，点击查看详情。',
        'payload': 'open_messages'
      },
      {
        'title': '热门推荐',
        'body': '发现了一些您可能感兴趣的内容，快来看看吧！',
        'payload': 'open_home'
      },
      {
        'title': '订单更新',
        'body': '您的订单状态有更新，点击查看详情。',
        'payload': 'open_orders'
      }
    ];

    // 随机选择一个通知
    final random = Random();
    final notification = notifications[random.nextInt(notifications.length)];

    NotiService.showDailyNotification(
      title: notification['title']!,
      body: notification['body']!,
      payload: notification['payload']!,
    );
  }


  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _checkClipboardForSharedPost();
    } else if (state == AppLifecycleState.paused) {
    }
  }

  Future<void> _checkClipboardForSharedPost() async {
    final context = navigatorKey.currentContext ?? this.context;
    print('[ClipboardCheck] Attempting to read clipboard.');
    ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    print('[ClipboardCheck] Clipboard.getData result: $data');

    if (data != null && data.text != null && data.text!.isNotEmpty) {
      String clipboardText = data.text!;
      print('[ClipboardCheck] Clipboard text: "$clipboardText"');
      
      RegExp regExp = RegExp(r"ID: (\w+) #LinkSphereApp");
      Match? match = regExp.firstMatch(clipboardText);

      if (match != null && match.groupCount >= 1) {
        final String postId = match.group(1)!;
        print("[ClipboardCheck] Matched! Post ID: $postId");

        await Clipboard.setData(const ClipboardData(text: '')); // 注释掉此行，不再立即清空剪贴板
        print('[ClipboardCheck] Clipboard cleared.'); // 同时注释掉对应的打印
        
        if (mounted) {
          print('[ClipboardCheck] Component is mounted. Showing dialog...');
          showDialog(
            context: context, 
            builder: (BuildContext dialogContext) {
              return AlertDialog(
                title: const Text("发现分享内容"),
                content: Text("检测到分享的帖子 ID: $postId，是否立即查看？"),
                actions: <Widget>[
                  TextButton(
                    child: const Text("取消"),
                    onPressed: () async {
                      Navigator.of(dialogContext).pop();
                      await Clipboard.setData(const ClipboardData(text: ''));
                      print('[ClipboardCheck] Clipboard cleared.');
                    },
                  ),
                  TextButton(
                    child: const Text("查看"),
                    onPressed: () async {
                      Navigator.of(dialogContext).pop();
                      await Clipboard.setData(const ClipboardData(text: ''));
                      print('[ClipboardCheck] Clipboard cleared.');
                      navigatorKey.currentState?.push(
                        MaterialPageRoute(
                          builder: (_) => PostDetailPage(postId: postId),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          );
        } else {
          print('[ClipboardCheck] Component not mounted. Cannot show dialog.');
        }
      } else {
        print('[ClipboardCheck] RegExp did not match the clipboard text.');
      }
    } else {
      if (data == null) {
        print('[ClipboardCheck] Clipboard data is null.');
      } else if (data.text == null) {
        print('[ClipboardCheck] Clipboard text is null.');
      } else if (data.text!.isEmpty) {
        print('[ClipboardCheck] Clipboard text is empty.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, 
      debugShowCheckedModeBanner: false,
      title: 'LinkSphere',
      theme: ThemeData(
        colorScheme: ColorScheme.light(
          primary: const Color(0xFFfe2c55),
          secondary: const Color(0xFF25F4EE),
          surface: Colors.white,
          onSurface: Colors.black,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: IconThemeData(color: Colors.black),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.black),
          bodyMedium: TextStyle(color: Colors.black),
          titleMedium: TextStyle(color: Colors.black),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Color(0xFFfe2c55),
          unselectedItemColor: Colors.grey,
        ),
      ),
      initialRoute: widget.initialRoute, 
      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (context) => const MyHomePage(), 
      },
    );
  }
}

// --- 您现有的 MyHomePage widget --- 
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  final List<Widget> _pages = [
     HomePage(),
    const DiscoverPage(),
    const SizedBox.shrink(), // 添加空页面占位
    const MessagePage(),
    ProfilePage(),
  ];

  void _onItemTapped(int index) {
    // 跳过中间的创作按钮
    if (index == 2) return;

    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Adjust pages access based on _selectedIndex directly for BottomNavigationBar
    // The _pages list is already structured for direct indexing if we map BottomNavBar index to _pages index correctly.
    // However, the current _onItemTapped logic is fine with _selectedIndex and how _pages is structured.
    // It seems the _pages array might be missing one page if _selectedIndex can go up to 4 and index > 2 means index -1 for _pages. 
    // Let's assume the existing logic for _pages and _selectedIndex is correct for now based on its usage.
    // Correct access to _pages with current _selectedIndex and _onItemTapped logic:
    // Widget currentPage;
    // if (_selectedIndex < 2) {
    //   currentPage = _pages[_selectedIndex];
    // } else if (_selectedIndex > 2) { // For Message (index 3) and Profile (index 4)
    //   currentPage = _pages[_selectedIndex -1]; // Accesses _pages[2] and _pages[3]
    // } else {
    //   // This case should ideally not be reached if index == 2 is handled by return in _onItemTapped
    //   // Or if the _selectedIndex is directly mapped without the placeholder
    //   currentPage = const SizedBox.shrink(); // Fallback, though _onItemTapped prevents index 2
    // }

    return Scaffold(
      body: _pages[_selectedIndex], // Use the determined current page
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreatePostPage()),
          );
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFFfe2c55),
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white, // 修改为白色背景
        elevation: 1, // 添加轻微阴影
        selectedFontSize: 11,
        unselectedFontSize: 11,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: '首页',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            activeIcon: Icon(Icons.explore),
            label: '发现',
          ),
          BottomNavigationBarItem(
            icon: SizedBox.shrink(), // 中间留空
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message_outlined),
            activeIcon: Icon(Icons.message),
            label: '消息',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
