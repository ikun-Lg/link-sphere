import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:link_sphere/models/user.dart';
import 'package:image_picker/image_picker.dart';
import 'package:link_sphere/services/api_service.dart';
import 'package:link_sphere/services/user_service.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  String? _avatarUrl;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  bool _isLoading = false;

  // 修复：头像选择与上传方法
  Future<void> _pickAndUploadAvatar() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() { _isLoading = true; });
        final url = await ApiService().uploadAvatar(image);
        await UserService.setAvatar(url);
        setState(() { _avatarUrl = url; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('头像上传成功')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('头像上传失败: $e')),
      );
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    // 加载头像url
    final userInfo = await UserService.getUser();
    setState(() {
      _avatarUrl = userInfo?.avatarUrl;
    });
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
      // 打印输入的年龄值
      print('Age input: ${_ageController.text}');
      
      // Ensure age is converted to an integer, defaulting to 0 if parsing fails
      final ageValue = int.tryParse(_ageController.text) ?? 0;
      
      // 打印解析后的年龄值
      print('Parsed age value: $ageValue');
      
      final success = await ApiService().updateUserInfo(
        username: _usernameController.text.isNotEmpty ? _usernameController.text : null,
        avatarUrl: _avatarUrl ?? '', // 头像url
        bio: _bioController.text.isNotEmpty ? _bioController.text : null,
        age: ageValue,
      );
      
      // 打印更新结果
      print('Update success: $success');

      if (success) {
        // 获取最新的用户信息
        final userInfo = await UserService.getUser();
        final userId = userInfo?.id;
        print('User ID: $userId');
        
        if (userId != null) {
          final response = await ApiService().getUserInfo(userId);
          print('Get User Info Response: $response');

          if (response['code'] == 'SUCCESS_0000') {
            final userData = response['data'];
            print('User Data: $userData');
            
            // 更新本地存储中的用户信息
            print('Creating User with data: $userData');
            
            // 确保所有必需的字段都被正确处理
            final updatedUser = User(
              id: userData['id'] is int 
                  ? userData['id'] 
                  : int.tryParse(userData['id'].toString()) ?? 0,
              username: userData['username'] ?? '',
              token: (await UserService.getToken()) ?? '',
              age: userData['age'] is int 
                  ? userData['age'] 
                  : int.tryParse(userData['age'].toString()) ?? 0,
              bio: userData['bio'] ?? '',
              avatarUrl: userData['avatarUrl'] ?? '',
              followerCount: userData['followerCount'] is int 
                  ? userData['followerCount'] 
                  : int.tryParse(userData['followerCount'].toString()) ?? 0,
              followCount: userData['followCount'] is int 
                  ? userData['followCount'] 
                  : int.tryParse(userData['followCount'].toString()) ?? 0,
              favoriteCount: userData['favoriteCount'] is int 
                  ? userData['favoriteCount'] 
                  : int.tryParse(userData['favoriteCount'].toString()) ?? 0,
            );
            
            print('Created User: ${updatedUser.toJson()}');
            await UserService.saveUser(updatedUser);

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('资料更新成功')),
            );
            Navigator.pop(context);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('获取最新用户信息失败: ${response['info']}')),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未找到用户信息')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('资料更新失败')),
        );
      }
    } catch (e) {
      print('保存个人资料时发生错误: $e');
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
    // 头像控件
    Widget avatarWidget = GestureDetector(
      onTap: _isLoading ? null : _pickAndUploadAvatar,
      child: CircleAvatar(
        radius: 40,
        backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty
            ? NetworkImage(_avatarUrl!)
            : null,
        child: _avatarUrl == null || _avatarUrl!.isEmpty
            ? const Icon(Icons.person, size: 40)
            : null,
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑资料'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            avatarWidget,
            const SizedBox(height: 16),
            Text('点击头像更换', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
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