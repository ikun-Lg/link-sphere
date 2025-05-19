import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:link_sphere/main.dart';
import 'register_page.dart';
import 'package:link_sphere/services/api_service.dart';
import 'package:link_sphere/services/websocket_service.dart';
import 'package:link_sphere/services/user_service.dart';
import 'package:link_sphere/services/noti_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:link_sphere/models/message.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _accountController = TextEditingController();
  final _passwordController = TextEditingController();
  final _verifyCodeController = TextEditingController();
  bool _isPasswordLogin = true;
  bool _isPhone = false;
  bool _obscurePassword = true;
  int _countdownSeconds = 0;
  final _apiService = ApiService();
  bool _isLoading = false;
  Timer? _timer; // <--- 新增：用于管理倒计时

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    _verifyCodeController.dispose();
    _timer?.cancel(); // <--- 新增：在 dispose 时取消计时器
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel(); // <--- 新增：先取消之前的计时器
    setState(() {
      _countdownSeconds = 60;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // <--- 修改：使用 Timer.periodic
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdownSeconds > 0) {
        setState(() {
          _countdownSeconds--;
        });
      } else {
        timer.cancel(); // <--- 修改：倒计时结束时取消计时器
      }
    });
  }

  // --- 新增：获取验证码逻辑 ---
  Future<void> _fetchVerificationCode() async {
    final contactInfo = _accountController.text;
    if (contactInfo.isEmpty) {
      _showMessage(_isPhone ? '请输入手机号' : '请输入邮箱', isError: true);
      return;
    }
    if (_isPhone && contactInfo.length != 11) {
      _showMessage('请输入11位手机号', isError: true);
      return;
    }
    if (!_isPhone && !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(contactInfo)) {
      _showMessage('请输入正确的邮箱格式', isError: true);
      return;
    }

    setState(() {
      _isLoading = true; // 可以复用 isLoading 或添加新的状态
    });

    try {
      final response = await _apiService.getVerificationCode(
        contactInformation: contactInfo,
        type: _isPhone ? 1 : 2,
      );
      if (mounted) {
        if (response['code'] == 'SUCCESS_0000') {
          _showMessage('验证码已发送');
          _startCountdown(); // 成功后开始倒计时
          // 可以选择将验证码填充到输入框（如果API返回了）
          // _verifyCodeController.text = response['data'] ?? '';
        } else {
          _showMessage('获取验证码失败: ${response['info']}', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        _showMessage('获取验证码出错: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 在 _LoginPageState 类中添加显示提示的方法
  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      builder: (BuildContext dialogContext) {
        // Get the dialog context
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && Navigator.of(dialogContext).mounted) {
            // Use dialog context
            Navigator.of(dialogContext).pop();
          }
        });

        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color:
                  isError
                      ? Colors.red.withAlpha(230)
                      : Colors.green.withAlpha(230),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isError ? Icons.error_outline : Icons.check_circle_outline,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    message,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 修改 _login 方法中的提示部分
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      print("验证码${_verifyCodeController.text}");
      final success = await _apiService.login(
        contactInformation: _accountController.text,
        passwordCode: _isPasswordLogin
                ? _passwordController.text
                : _verifyCodeController.text,
        code: _isPasswordLogin ? 2 : 1,
      );

      if (success) {
        // 获取用户信息
        final user = await UserService.getUser();
        if (user != null) {
          // 创建新的 WebSocketService 实例
          final wsService = WebSocketService();
          // 初始化新的 WebSocket 连接
          await wsService.initialize(user.token, user.id.toString());

          // 获取未读消息
          try {
            final unreadMessages = await _apiService.getUnreadMessages();
            if (unreadMessages['code'] == 'SUCCESS_0000' && unreadMessages['data'] != null) {
              final messages = unreadMessages['data'] as List;
              for (var messageGroup in messages) {
                final userId = messageGroup['userId'];
                final username = messageGroup['username'];
                final messageList = messageGroup['messageList'] as List;
                
                // 对每条消息进行通知和保存
                for (var message in messageList) {
                  // 发送通知
                  await NotiService.showDailyNotification(
                    title: '来自 $username 的新消息',
                    body: message['content'] ?? '新消息',
                    payload: 'open_messages',
                  );

                  // 将消息转换为 ChatMessage 格式并保存
                  final chatMessage = ChatMessage(
                    senderId: userId.toString(),
                    receiverId: user.id.toString(),
                    content: message['content'] ?? '',
                    sendTime: DateTime.fromMillisecondsSinceEpoch(
                      message['timestamp'] ?? DateTime.now().millisecondsSinceEpoch
                    ).toIso8601String(),
                    messageId: message['id'] ?? '',
                    read: false,
                  );
                  
                  // 保存消息到本地存储
                  final prefs = await SharedPreferences.getInstance();
                  final chatKey = 'chat_${userId}_${user.id}';
                  final savedMessages = prefs.getStringList(chatKey) ?? [];
                  savedMessages.add(jsonEncode(chatMessage.toJson()));
                  await prefs.setStringList(chatKey, savedMessages);
                }
              }

              // 标记消息已读
              await _apiService.markMessagesAsRead();
            }
          } catch (e) {
            print('获取未读消息失败: $e');
          }
        }

        if (mounted) {
          _showMessage('登录成功');
          // 延迟跳转，让用户看到成功提示
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const MyHomePage()),
                (route) => false, // 移除所有路由
              );
            }
          });
        }
      }
    } catch (e) {
      _showMessage(e.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // 修改背景色
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                // Logo 和标题
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '欢迎回来',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '登录LinkSphere，继续您的社交之旅',
                        style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // 登录方式切换
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(25),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isPasswordLogin = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color:
                                  _isPasswordLogin
                                      ? Theme.of(context).primaryColor
                                      : Colors.transparent,
                              borderRadius: BorderRadius.circular(21),
                            ),
                            child: Text(
                              '密码登录',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color:
                                    _isPasswordLogin
                                        ? Colors.white
                                        : Colors.black87,
                                fontWeight:
                                    _isPasswordLogin
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isPasswordLogin = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color:
                                  !_isPasswordLogin
                                      ? Theme.of(context).primaryColor
                                      : Colors.transparent,
                              borderRadius: BorderRadius.circular(21),
                            ),
                            child: Text(
                              '验证码登录',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color:
                                    !_isPasswordLogin
                                        ? Colors.white
                                        : Colors.black87,
                                fontWeight:
                                    !_isPasswordLogin
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // 账号输入框
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextFormField(
                    controller: _accountController,
                    style: const TextStyle(color: Colors.black87),
                    decoration: InputDecoration(
                      labelText: _isPhone ? '手机号' : '邮箱',
                      labelStyle: TextStyle(color: Colors.grey[600]),
                      prefixIcon: Icon(
                        _isPhone ? Icons.phone_android : Icons.email_outlined,
                        color: Colors.grey[600],
                      ),
                      suffixIcon: Switch(
                        value: _isPhone,
                        onChanged: (value) => setState(() => _isPhone = value),
                        activeColor: Theme.of(context).primaryColor,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    keyboardType:
                        _isPhone
                            ? TextInputType.phone
                            : TextInputType.emailAddress,
                    inputFormatters:
                        _isPhone
                            ? [FilteringTextInputFormatter.digitsOnly]
                            : null,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return _isPhone ? '请输入手机号' : '请输入邮箱';
                      }
                      if (_isPhone && value.length != 11) {
                        return '请输入11位手机号';
                      }
                      if (!_isPhone &&
                          !RegExp(
                            r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                          ).hasMatch(value)) {
                        return '请输入正确的邮箱格式';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // 密码/验证码输入框
                if (_isPasswordLogin)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextFormField(
                      controller: _passwordController,
                      style: const TextStyle(color: Colors.black87),
                      decoration: InputDecoration(
                        labelText: '密码',
                        labelStyle: TextStyle(color: Colors.grey[600]),
                        prefixIcon: Icon(
                          Icons.lock_outline,
                          color: Colors.grey[600],
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey[600],
                          ),
                          onPressed:
                              () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      obscureText: _obscurePassword,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入密码';
                        }
                        if (value.length < 6) {
                          return '密码至少6位';
                        }
                        return null;
                      },
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          // ... existing code ...
                          child: TextFormField(
                           controller: _verifyCodeController,
                            style: const TextStyle(color: Colors.black87),
                            decoration: InputDecoration(
                              labelText: '验证码',
                              labelStyle: TextStyle(color: Colors.grey[600]),
                              prefixIcon: Icon(
                                Icons.lock_outline,
                                color: Colors.grey[600],
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              )
                            )
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 120,
                        child: ElevatedButton(
                          onPressed:
                              _countdownSeconds > 0 ||
                                      _isLoading // <--- 修改：添加 _isLoading 判断
                                  ? null
                                  : _fetchVerificationCode, // <--- 修改：调用 _fetchVerificationCode
                          child:
                              _isLoading &&
                                      !_isPasswordLogin // <--- 新增：在获取验证码时显示加载指示器
                                  ? const SizedBox(
                                    width: 16, // 调整大小以适应按钮
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                  : Text(
                                    _countdownSeconds > 0
                                        ? '${_countdownSeconds}s'
                                        : '获取验证码',
                                  ),
                        ),
                      ),
                    ],
                  ),
                if (_isPasswordLogin) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        // TODO: 实现忘记密码功能
                      },
                      child: Text(
                        '忘记密码？',
                        style: TextStyle(color: Colors.grey[400], fontSize: 14),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 40),

                // 登录按钮
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child:
                      _isLoading
                          ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : const Text(
                            '登录',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                ),
                const SizedBox(height: 24),

                // 底部文字
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('还没有账号？', style: TextStyle(color: Colors.grey[400])),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RegisterPage(),
                          ),
                        );
                      },
                      child: Text(
                        '立即注册',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
