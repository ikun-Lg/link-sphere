import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:link_sphere/models/user.dart';
import 'package:link_sphere/services/api_service.dart';
import 'package:link_sphere/services/user_service.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      final userInfo = await UserService.getUser();
      final userId = (userInfo?.id)?.toInt();
      final response = await ApiService().getUserInfo(userId); // 替换为实际用户ID
      if (response['code'] == 'SUCCESS_0000') {
        final userData = response['data'];
        setState(() {
          _usernameController.text = userData['username'];
          _bioController.text = userData['bio'];
          _ageController.text = userData['age'].toString();
          // 你可以根据需要添加更多字段，例如头像URL等
        });
      } else {
        // 处理错误信息
        print('获取用户信息失败: ${response['info']}');
      }
    } catch (e) {
      print('加载用户信息异常: $e');
    }
  }

  Future<void> _saveProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await ApiService().updateUserInfo(
        username: _usernameController.text.isNotEmpty ? _usernameController.text : null,
        avatarUrl: '', // 这里可以添加头像上传逻辑
        bio: _bioController.text.isNotEmpty ? _bioController.text : null,
        age: int.tryParse(_ageController.text),
      );

      if (success) {
        // 获取最新的用户信息
        final userInfo = await UserService.getUser();
        final userId = (userInfo?.id)?.toInt();
        final response = await ApiService().getUserInfo(userId);

        if (response['code'] == 'SUCCESS_0000') {
          final userData = response['data'];
          // 更新本地存储中的用户信息
          final updatedUser = User(
            followCount: userData['followCount'],
            followerCount: userData['followerCount'],
            favoriteCount: userData['favoriteCount'],
            avatarUrl: userData['avatarUrl'], // 从新的用户数据中获取头像URL,
            id:userData['id'],
            username: userData['username'],
            bio: userData['bio'],
            age: userData['age'],
            token: (await UserService.getToken()) ?? '',
          );
          await UserService.saveUser(updatedUser);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('资料更新成功')),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('获取最新用户信息失败')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('资料更新失败')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新失败: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑资料'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: '用户名'),
            ),
            TextField(
              controller: _bioController,
              decoration: const InputDecoration(labelText: '简介'),
              maxLines: 3, // 设置简介输入框的最大行数以增加高度
            ),
            TextField(
              controller: _ageController,
              decoration: const InputDecoration(labelText: '年龄'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly], // 限制输入为数字
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _saveProfile,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}