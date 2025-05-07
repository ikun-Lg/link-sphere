import 'package:flutter/material.dart';
import 'package:link_sphere/pages/cart_page.dart';
import 'package:link_sphere/services/user_service.dart';
import 'pages/home_page.dart';
import 'pages/discover_page.dart';
import 'pages/message_page.dart';
import 'pages/profile_page.dart';
import 'pages/register_page.dart'; // 添加注册页面导入
import 'pages/create_post_page.dart'; // 添加创作页面导入
import 'pages/login_page.dart'; // <--- 新增：导入登录页面
import 'services/api_service.dart'; // <--- 新增：导入 ApiService

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await UserService.init();

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

class MyApp extends StatelessWidget {
  final String initialRoute;
  const MyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      home: const RegisterPage(),
      initialRoute: initialRoute, // <--- 修改：使用传入的 initialRoute
      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (context) => const MyHomePage(), // 假设 MyHomePage 是您的主页
        // 您可以根据需要添加其他路由
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

    // 调整索引以匹配实际页面
    int actualIndex = index;
    if (index > 2) {
      actualIndex = index - 1;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
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
