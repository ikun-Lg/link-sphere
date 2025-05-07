import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:link_sphere/services/api_service.dart'; // <--- 导入 ApiService

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final List<String> _uploadedImageUrls = [];
  final ImagePicker _picker = ImagePicker();
  final ApiService _apiService = ApiService();
  bool _isUploading = false;
  // --- 新增：是否公开的状态和发布状态 ---
  bool _isPublic = true; // 默认公开
  bool _isPublishing = false; // 发布状态标志
  // --- 新增结束 ---

  // --- 修改：选择图片并上传 ---
  Future<void> _pickAndUploadImages() async {
    if (_isUploading) return; // 防止重复触发

    final List<XFile> images = await _picker.pickMultiImage(imageQuality: 80); // 可以设置图片质量
    if (images.isNotEmpty) {
      setState(() {
        _isUploading = true; // 开始上传，显示加载指示
      });

      // 逐个上传图片
      for (var image in images) {
        try {
          final imageUrl = await _apiService.uploadFile(image); // 调用 API 上传
          setState(() {
            _uploadedImageUrls.add(imageUrl); // 将返回的 URL 添加到列表
          });
        } catch (e) {
          // 处理上传错误
          print('上传图片失败: ${image.name}, 错误: $e');
          if (mounted) { // 检查 widget 是否还在树中
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('图片 ${image.name} 上传失败: $e')),
            );
          }
          // 可以选择是否中断上传过程
          // break;
        }
      }

      setState(() {
        _isUploading = false; // 上传结束
      });
    }
  }
  // --- 修改结束 ---

  // --- 修改：移除图片 URL ---
  void _removeImage(int index) {
    setState(() {
      _uploadedImageUrls.removeAt(index); // <--- 从 URL 列表移除
    });
  }
  // --- 修改结束 ---

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // --- 新增：处理发布逻辑 ---
  Future<void> _publishPost() async {
    if (_isPublishing || _isUploading) return; // 防止重复提交

    // 基本校验
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入帖子标题')),
      );
      return;
    }
    if (_descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入帖子内容')),
      );
      return;
    }

    setState(() {
      _isPublishing = true; // 开始发布
    });

    try {
      await _apiService.publishPost(
        title: _titleController.text,
        content: _descriptionController.text,
        images: _uploadedImageUrls,
        isPublic: _isPublic,
      );

      // 发布成功
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('发布成功！')),
      );
      Navigator.pop(context, true); // 返回 true 表示发布成功，可以用于刷新列表

    } catch (e) {
      // 发布失败
      print('发布帖子失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发布失败: $e')),
        );
      }
    } finally {
      // 无论成功或失败，结束发布状态
      if (mounted) {
        setState(() {
          _isPublishing = false;
        });
      }
    }
  }
  // --- 新增结束 ---


  @override
  Widget build(BuildContext context) {
    // --- 修改：发布按钮状态判断 ---
    // 同时考虑图片上传和帖子发布状态
    final bool isLoading = _isUploading || _isPublishing;
    // --- 修改结束 ---

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '发布帖子',
          style: TextStyle(color: Colors.black, fontSize: 16),
        ),
        actions: [
          TextButton(
            // --- 修改：使用 isLoading 和调用 _publishPost ---
            onPressed: isLoading ? null : _publishPost, // 调用发布方法
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('发布'),
            // --- 修改结束 ---
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题输入框
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: '添加标题',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // 图片网格
            // --- 修改：使用 URL 显示图片 ---
            if (_uploadedImageUrls.isNotEmpty)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: _uploadedImageUrls.length, // <--- 使用 URL 列表长度
                itemBuilder: (context, index) {
                  final imageUrl = _uploadedImageUrls[index]; // <--- 获取 URL
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        // 使用 Image.network 加载网络图片
                        child: Image.network(
                          imageUrl, // <--- 使用 URL
                          fit: BoxFit.cover,
                          // 添加加载和错误处理
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                    : null,
                                strokeWidth: 2,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[200],
                              child: Icon(Icons.broken_image, color: Colors.grey[400]),
                            );
                          },
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeImage(index), // <--- 调用修改后的移除方法
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            // --- 修改结束 ---

            // 添加图片按钮
            // --- 修改：添加加载状态显示 ---
            GestureDetector(
              onTap: _pickAndUploadImages, // <--- 调用新的选择和上传方法
              child: Container(
                width: 100,
                height: 100,
                margin: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _isUploading
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2)) // <--- 上传时显示加载
                    : Icon(
                        Icons.add_photo_alternate_outlined,
                        size: 32,
                        color: Colors.grey[400],
                      ),
              ),
            ),
            // --- 修改结束 ---

            // 描述输入框
            TextField(
              controller: _descriptionController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: '添加描述...',
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 16), // 添加一些间距

            // --- 新增：是否公开的 Switch ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('是否公开', style: TextStyle(fontSize: 16)),
                Switch(
                  value: _isPublic,
                  onChanged: (value) {
                    setState(() {
                      _isPublic = value;
                    });
                  },
                  activeColor: Theme.of(context).primaryColor, // 使用主题色
                ),
              ],
            ),
            // --- 新增结束 ---

            const SizedBox(height: 32), // 底部增加一些空间
          ],
        ),
      ),
    );
  }
}