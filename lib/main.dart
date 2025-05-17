import 'package:flutter/material.dart';
import 'package:link_sphere/pages/cart_page.dart';
import 'package:link_sphere/services/noti_service.dart';
import 'package:link_sphere/services/user_service.dart';
import 'package:link_sphere/services/websocket_service.dart';
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
  bool _isWebSocketInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkClipboardForSharedPost();
    _initWebSocket();
  }

  Future<void> _initWebSocket() async {
    if (_isWebSocketInitialized) {
      print('[App] WebSocket 已经初始化，跳过');
      return;
    }

    try {
      final token = await UserService.getToken();
      if (token != null && token.isNotEmpty) {
        final user = await UserService.getUser();
        if (user != null) {
          print('[App] 初始化 WebSocket 连接...');
          await WebSocketService().connect(
            user.id.toString(),
            token,
            ApiService().dio.options.baseUrl,
          );
          _isWebSocketInitialized = true;
          print('[App] WebSocket 连接成功并订阅个人消息队列');
        }
      }
    } catch (e) {
      print('[App] WebSocket 初始化失败: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WebSocketService().dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _checkClipboardForSharedPost();
      _initWebSocket(); // 应用恢复时重新连接
    } else if (state == AppLifecycleState.paused) {
      WebSocketService().disconnect();
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
