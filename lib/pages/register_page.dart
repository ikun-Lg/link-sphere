import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:link_sphere/pages/login_page.dart';
import 'package:link_sphere/services/api_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _accountController = TextEditingController();
  final _verifyCodeController = TextEditingController();
  final _passwordController = TextEditingController(); // 恢复密码控制器
  bool _isPasswordRegister = false; // 注册方式切换
  bool _isPhone = false;
  bool _obscurePassword = true;
  int _countdownSeconds = 0;
  final _apiService = ApiService();
  bool _isLoading = false;

  @override
  void dispose() {
    _accountController.dispose();
    // _passwordController.dispose(); // 移除密码控制器
    _verifyCodeController.dispose();
    super.dispose();
  }

  Future<void> _sendVerificationCode() async {
    if (_accountController.text.isEmpty) {
      _showMessage(_isPhone ? '请输入手机号' : '请输入邮箱', isError: true);
      return;
    }
    if (_isPhone && _accountController.text.length != 11) {
      _showMessage('请输入11位手机号', isError: true);
      return;
    }
    if (!_isPhone &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
            .hasMatch(_accountController.text)) {
      _showMessage('请输入正确的邮箱格式', isError: true);
      return;
    }

    setState(() {
      _isLoading = true; // 开始加载状态，避免重复点击
    });

    try {
      // 修改为调用新的获取注册验证码接口
      await _apiService.getRegisterVerificationCode(
        contactInformation: _accountController.text,
        type: _isPhone ? 1 : 2, // 1 for phone, 2 for email
      );
      _showMessage('验证码已发送');
      _startCountdown();
    } catch (e) {
      _showMessage(e.toString(), isError: true);
    } finally {
      setState(() {
        _isLoading = false; // 结束加载状态
      });
    }
  }

  void _startCountdown() {
    if (_countdownSeconds == 0) {
      setState(() {
        _countdownSeconds = 60;
      });
    }
    Future.delayed(const Duration(seconds: 1), () {
      if (_countdownSeconds > 0) {
        setState(() {
          _countdownSeconds--;
        });
        _startCountdown();
      }
    });
  }

  // 在 _RegisterPageState 类中添加显示提示的方法
  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
  
    // Store the BuildContext
    final BuildContext currentContext = context;
    
    showDialog(
      context: currentContext,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      builder: (BuildContext dialogContext) {
        // Use delayed future only if we need to auto-dismiss
        if (!isError) {
          Future.delayed(const Duration(seconds: 2), () {
            // Check if the dialog is still showing before trying to dismiss it
            if (mounted && Navigator.canPop(dialogContext)) {
              Navigator.pop(dialogContext);
            }
          });
        }
    
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: isError 
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

  // 删除 _login 方法,只保留 _register 方法
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
  setState(() {
    _isLoading = true;
  });
  try {
    final success = await _apiService.register(
      contactInformation: _accountController.text,
      code: _verifyCodeController.text,
      type: _isPhone ? '1' : '2',
    );
    if (success && mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
        (route) => false,
      );
      return; // 跳转后立即 return，避免后续 setState
    }
  } catch (e) {
    if (mounted) {
      _showMessage(e.toString(), isError: true);
    }
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
      backgroundColor: Colors.white,
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
                        '创建账号', // 修改标题
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,  // 修改为黑色
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '加入LinkSphere，开启您的社交之旅', // 修改副标题
                        style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // 注册方式切换
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
                          onTap: () => setState(() => _isPasswordRegister = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _isPasswordRegister ? Theme.of(context).primaryColor : Colors.transparent,
                              borderRadius: BorderRadius.circular(21),
                            ),
                            child: Text(
                              '密码注册',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _isPasswordRegister ? Colors.white : Colors.black87,
                                fontWeight: _isPasswordRegister ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isPasswordRegister = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: !_isPasswordRegister ? Theme.of(context).primaryColor : Colors.transparent,
                              borderRadius: BorderRadius.circular(21),
                            ),
                            child: Text(
                              '验证码注册',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: !_isPasswordRegister ? Colors.white : Colors.black87,
                                fontWeight: !_isPasswordRegister ? FontWeight.bold : FontWeight.normal,
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                if (_isPasswordRegister)
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
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            color: Colors.grey[600],
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      obscureText: _obscurePassword,
                      enabled: false, // 禁用密码注册输入
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextFormField(
                            controller: _verifyCodeController,
                            style: const TextStyle(color: Colors.black87),
                            decoration: InputDecoration(
                              labelText: '验证码',
                              labelStyle: TextStyle(color: Colors.grey[600]),
                              prefixIcon: Icon(
                                Icons.verified_user_outlined,
                                color: Colors.grey[600],
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '请输入验证码';
                              }
                              if (value.length != 6) {
                                return '请输入6位验证码';
                              }
                              return null;
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 120,
                        child: ElevatedButton(
                          onPressed:
                              _isLoading || _countdownSeconds > 0 || _isPasswordRegister // 密码注册时禁用
                                  ? null
                                  : _sendVerificationCode,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            disabledBackgroundColor: Colors.grey,
                          ),
                          child: Text(
                            _countdownSeconds > 0
                                ? '${_countdownSeconds}s'
                                : '获取验证码',
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 40),
                // 注册按钮
                ElevatedButton(
                  onPressed: _isLoading  ? null : _register, // 密码注册时禁用
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
                            '注册',
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
                    Text(
                      '已有账号?',
                      style: TextStyle(color: Colors.grey[400]),
                    ), // 修改底部提示文字
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => LoginPage()),
                        );
                      },
                      child: Text(
                        '立即登录',
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
