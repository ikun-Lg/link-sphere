import 'package:flutter/material.dart';
import 'package:flutter_swiper_null_safety/flutter_swiper_null_safety.dart';
import 'package:link_sphere/services/api_service.dart';
import 'package:link_sphere/widgets/post/post_bottom_bar.dart';
import 'package:link_sphere/pages/product_detail_page.dart';
// import 'package:link_sphere/widgets/post/post_header.dart'; // Removed unused import
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:link_sphere/pages/user_profile_page.dart'; // 导入新页面
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/services.dart'; // 导入剪贴板服务

class PostDetailPage extends StatefulWidget {
  final String postId;

  const PostDetailPage({super.key, required this.postId});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  Map<String, dynamic>? postDetail;
  List<dynamic> recommendPosts = []; // 添加推荐帖子列表
  List<dynamic> recommendProducts = []; // 添加推荐商品列表
  bool isLoading = true;
  bool isLoadingRecommend = false; // 添加推荐帖子加载状态
  bool isLoadingProductRecommend = false; // 添加推荐商品加载状态
  bool isFollowing = false;
  bool isFollowLoading = false;
  bool isCollected = false;
  bool isCollectLoading = false;
  bool isLiked = false; // 添加点赞状态
  bool isLikeLoading = false; // 添加点赞加载状态
  int likesCount = 0; // 添加点赞数量状态

  // 添加评论相关状态
  List<dynamic> comments = [];
  bool isLoadingComments = false;
  int commentPage = 1;
  bool hasMoreComments = true;

  // 二级评论相关状态
  Map<String, List<dynamic>> replyComments = {}; // 存储每个一级评论的回复
  Map<String, bool> isLoadingReplies = {}; // 每个一级评论的加载状态
  Map<String, String?> replyLastIds = {}; // 每个一级评论的最后一个回复ID
  Map<String, bool> hasMoreReplies = {}; // 每个一级评论是否有更多回复
  Map<String, bool> showReplies = {}; // 控制每个一级评论的回复是否展开

  // 评论输入控制器
  final TextEditingController _commentController = TextEditingController();
  // 评论图片相关变量
  String? _commentImageUrl;
  XFile? _commentImageFile;
  bool _isUploadingCommentImage = false;
  // 回复输入控制器
  final TextEditingController _replyController = TextEditingController();
  // 当前正在回复的评论
  Map<String, dynamic>? _currentReplyComment;

  // 回复图片相关变量
  String? _replyImageUrl;
  XFile? _replyImageFile;
  bool _isUploadingReplyImage = false;

  // 新增：用于滚动到评论区的 GlobalKey
  final GlobalKey _commentsSectionKey = GlobalKey();

  // 选择并上传评论图片
  Future<void> _pickCommentImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      setState(() {
        _isUploadingCommentImage = true;
      });
      try {
        final url = await ApiService().uploadFile(pickedFile);
        setState(() {
          _commentImageFile = pickedFile;
          _commentImageUrl = url;
        });
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('图片上传失败: $e')));
      } finally {
        setState(() {
          _isUploadingCommentImage = false;
        });
      }
    }
  }

  // 移除已选评论图片
  void _removeCommentImage() {
    setState(() {
      _commentImageFile = null;
      _commentImageUrl = null;
    });
  }

  // 选择并上传回复图片
  Future<void> _pickReplyImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      setState(() {
        _isUploadingReplyImage = true;
      });
      try {
        final url = await ApiService().uploadFile(pickedFile);
        setState(() {
          _replyImageFile = pickedFile;
          _replyImageUrl = url;
        });
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(content: Text('图片上传失败: $e')),
        );
      } finally {
        setState(() {
          _isUploadingReplyImage = false;
        });
      }
    }
  }

  // 移除已选图片
  void _removeReplyImage() {
    setState(() {
      _replyImageFile = null;
      _replyImageUrl = null;
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchPostDetail();
    _fetchRecommendPosts();
    _fetchProductRecommend();
    _fetchComments();
  }

  Future<void> _fetchPostDetail() async {
    setState(() {
      // 开始加载时重置状态
      isLoading = true;
      isFollowing = false;
      isCollected = false;
      isLiked = false; // 重置点赞状态
      likesCount = 0; // 重置点赞数
    });
    try {
      final response = await ApiService()
          .getPostDetail(widget.postId)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw '网络请求超时，请检查网络连接';
            },
          );

      if (response['code'] == 'SUCCESS_0000') {
        setState(() {
          postDetail = response['data'];
          isFollowing = postDetail?['followedAuthor'] ?? false;
          isCollected = postDetail?['isCollected'] ?? false;
          isLiked = postDetail?['isLiked'] ?? false;
          likesCount = postDetail?['likesCount'] ?? 0;
          isLoading = false;
        });

        // 获取帖子详情成功后加载推荐帖子和评论
        _fetchRecommendPosts();
      } else {
        throw response['info'] ?? '获取帖子详情失败';
      }
    } catch (e) {
      if (mounted) {
        // 添加 mounted 检查
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            // Simplified string interpolation
            content: Text(e is String ? e : '获取帖子详情失败'),
            duration: const Duration(seconds: 2),
          ),
        );
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // 获取评论列表
  Future<void> _fetchComments({bool resetScroll = true}) async {
    setState(() {
      isLoadingComments = true;
    });

    try {
      final response = await ApiService().getCommentList(
        entityType: 'posts',
        entityId: int.parse(widget.postId),
        page: commentPage,
        size: 10,
      );

      if (response['code'] == 'SUCCESS_0000') {
        final data = response['data'];
        setState(() {
          comments = data['list'];
          hasMoreComments = data['pages'] > commentPage;
          isLoadingComments = false;

          // 初始化回复相关的状态
          for (var comment in comments) {
            replyLastIds[comment['commentId'] as String] = null;
            hasMoreReplies[comment['commentId'] as String] =
                comment['replyCount'] > 0;
            showReplies[comment['commentId'] as String] = false;
          }
        });
      } else {
        throw response['info'] ?? '获取评论列表失败';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is String ? e : '获取评论列表失败'),
            duration: const Duration(seconds: 2),
          ),
        );
        setState(() {
          isLoadingComments = false;
        });
      }
    }
  }

  // 加载更多评论
  Future<void> _loadMoreComments() async {
    if (hasMoreComments && !isLoadingComments) {
      setState(() {
        commentPage++;
        isLoadingComments = true;
      });

      try {
        final response = await ApiService().getCommentList(
          entityType: 'posts',
          entityId: int.parse(widget.postId),
          page: commentPage,
          size: 10,
        );

        if (response['code'] == 'SUCCESS_0000') {
          final data = response['data'];
          setState(() {
            comments.addAll(data['list']);
            hasMoreComments = data['pages'] > commentPage;
            isLoadingComments = false;

            // 初始化新加载的评论的回复相关状态
            for (var comment in data['list']) {
              replyLastIds[comment['commentId'] as String] = null;
              hasMoreReplies[comment['commentId'] as String] =
                  comment['replyCount'] > 0;
              showReplies[comment['commentId'] as String] = false;
            }
          });
        } else {
          throw response['info'] ?? '获取更多评论失败';
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e is String ? e : '获取更多评论失败'),
              duration: const Duration(seconds: 2),
            ),
          );
          setState(() {
            commentPage--;
            isLoadingComments = false;
          });
        }
      }
    }
  }

  // 获取二级评论
  Future<void> _fetchSecondLevelComments(String parentCommentId) async {
    if (isLoadingReplies[parentCommentId] ?? false) return;

    setState(() {
      isLoadingReplies[parentCommentId] = true;
    });

    try {
      final lastId = replyLastIds[parentCommentId];
      final response = await ApiService().getSecondLevelComments(
        parentId: int.parse(parentCommentId),
        lastId: lastId != null ? int.parse(lastId) : null,
      );

      setState(() {
        // 如果是第一次加载，直接设置回复列表
        if (lastId == null) {
          replyComments[parentCommentId] = response;
        } else {
          // 如果不是第一次加载，追加回复列表
          replyComments[parentCommentId]!.addAll(response);
        }

        // 更新最后一个回复的ID
        if (response.isNotEmpty) {
          replyLastIds[parentCommentId] =
              response.first['commentId'].toString();
          hasMoreReplies[parentCommentId] = response.length == 10;
        } else {
          hasMoreReplies[parentCommentId] = false;
        }

        isLoadingReplies[parentCommentId] = false;
        showReplies[parentCommentId] = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is String ? e : '获取二级评论失败'),
            duration: const Duration(seconds: 2),
          ),
        );
        setState(() {
          isLoadingReplies[parentCommentId] = false;
        });
      }
    }
  }

  // 加载更多评论按钮
  Widget _buildLoadMoreButton() {
    return isLoadingComments
        ? const Center(child: CircularProgressIndicator())
        : TextButton(onPressed: _loadMoreComments, child: const Text('加载更多评论'));
  }

  // 单个评论项
  // 点赞评论
  Future<void> _toggleCommentLike(dynamic comment) async {
    try {
      final commentId = int.parse(comment['commentId'].toString());
      final parentId =
          comment['parentId'] != null
              ? int.parse(comment['parentId'].toString())
              : null;

      final response =
          comment['like']
              ? await ApiService().unlikeComment(
                commentId: commentId,
                parentId: parentId,
              )
              : await ApiService().likeComment(
                commentId: commentId,
                parentId: parentId,
              );

      if (response['code'] == 'SUCCESS_0000') {
        // 直接更新点赞状态，避免重新获取整个列表
        setState(() {
          final index = comments.indexWhere(
            (c) => c['commentId'] == comment['commentId'],
          );
          if (index != -1) {
            comments[index]['like'] = !comment['like'];
            comments[index]['likeCount'] += comment['like'] ? 1 : -1;
          }
        });

        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text(comment['like'] ? '取消点赞成功' : '点赞成功'),
        //     duration: const Duration(seconds: 2),
        //   ),
        // );
      } else {
        throw response['info'] ?? '点赞操作失败';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is String ? e : '点赞操作失败'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Widget _buildCommentItem(dynamic comment) {
    final commentId = comment['commentId'] as String;
    final replyCount = comment['replyCount'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: CircleAvatar(
            backgroundImage: NetworkImage(comment['userAvatar'] ?? ''),
          ),
          title: Text(comment['username'] ?? ''),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(comment['content'] ?? ''),
              if (comment['imageUrl'] != null &&
                  (comment['imageUrl'] as String).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      comment['imageUrl'],
                      height: 120,
                      width: 120,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (context, error, stackTrace) => Container(
                            color: Colors.grey[200],
                            height: 120,
                            width: 120,
                            child: const Icon(
                              Icons.broken_image,
                              color: Colors.grey,
                            ),
                          ),
                    ),
                  ),
                ),
              Text(
                comment['commentTime'] ?? '',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.reply, color: Colors.grey),
                onPressed: () => _openReplyBox(comment),
              ),
              IconButton(
                icon: Icon(
                  Icons.thumb_up,
                  color: comment['like'] ? Colors.blue : Colors.grey,
                ),
                onPressed: () => _toggleCommentLike(comment),
              ),
              Text(comment['likeCount'].toString()),
            ],
          ),
        ),
        if (replyCount > 0)
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: TextButton(
              onPressed: () {
                if (!(showReplies[commentId] ?? false)) {
                  _fetchSecondLevelComments(commentId);
                } else {
                  setState(() {
                    showReplies[commentId] = false;
                  });
                }
              },
              child: Text(
                showReplies[commentId] ?? false ? '收起回复' : '查看$replyCount条回复',
                style: const TextStyle(color: Colors.blue),
              ),
            ),
          ),
        if (showReplies[commentId] ?? false)
          _buildSecondLevelComments(commentId),
      ],
    );
  }

  Widget _buildSecondLevelComments(String parentCommentId) {
    final replies = replyComments[parentCommentId] ?? [];
    final isLoading = isLoadingReplies[parentCommentId] ?? false;
    final hasMore = hasMoreReplies[parentCommentId] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...replies.map(
          (reply) => Padding(
            padding: const EdgeInsets.only(left: 32.0, bottom: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundImage: NetworkImage(reply['userAvatar'] ?? ''),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reply['username'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(reply['content'] ?? ''),
                      if (reply['imageUrl'] != null &&
                          (reply['imageUrl'] as String).isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              reply['imageUrl'],
                              height: 100,
                              width: 100,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (context, error, stackTrace) => Container(
                                    color: Colors.grey[200],
                                    height: 100,
                                    width: 100,
                                    child: const Icon(
                                      Icons.broken_image,
                                      color: Colors.grey,
                                    ),
                                  ),
                            ),
                          ),
                        ),
                      Text(
                        reply['commentTime'] ?? '',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.thumb_up,
                    color: reply['like'] ? Colors.blue : Colors.grey,
                    size: 16,
                  ),
                  onPressed: () => _toggleCommentLike(reply),
                ),
                Text(reply['likeCount'].toString()),
              ],
            ),
          ),
        ),
        if (isLoading) const Center(child: CircularProgressIndicator()),
        if (hasMore && !isLoading)
          Padding(
            padding: const EdgeInsets.only(left: 32.0),
            child: TextButton(
              onPressed: () => _fetchSecondLevelComments(parentCommentId),
              child: const Text('加载更多回复', style: TextStyle(color: Colors.blue)),
            ),
          ),
      ],
    );
  }

  // 发布评论
  Future<void> _publishComment() async {
    final commentText = _commentController.text.trim();
    if (commentText.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('评论内容不能为空')));
      return;
    }

    try {
      final response = await ApiService().publishComment(
        entityId: int.parse(widget.postId),
        entityType: 'posts',
        content: commentText,
        imageUrl: _commentImageUrl ?? '',
      );

      if (response['code'] == 'SUCCESS_0000') {
        // 清空输入框和图片
        _commentController.clear();
        _removeCommentImage();
        // 重新加载评论
        await _fetchComments();
        // 显示成功提示
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('评论发布成功')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('发布评论失败：$e')));
    }
  }

  // 发布回复
  Future<void> _publishReply() async {
    if (_currentReplyComment == null) return;

    final replyText = _replyController.text.trim();
    if (replyText.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('回复内容不能为空')));
      return;
    }

    try {
      final response = await ApiService().publishReply(
        replyCommentId: _currentReplyComment!['id'],
        parentId:
            _currentReplyComment!['parentId'] ?? _currentReplyComment!['id'],
        content: replyText,
      );

      if (response['code'] == 'SUCCESS_0000') {
        // 清空输入框
        _replyController.clear();
        // 重新加载评论
        await _fetchComments();
        // 显示成功提示
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('回复发布成功')));
        // 关闭回复输入框
        setState(() {
          _currentReplyComment = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('发布回复失败：$e')));
    }
  }

  // 添加获取推荐帖子的方法
  Future<void> _fetchRecommendPosts() async {
    if (postDetail == null || postDetail!['authorId'] == null) return;

    setState(() {
      isLoadingRecommend = true;
    });

    try {
      final response = await ApiService().getRecommendContentForPost(
        postAuthorId: postDetail!['authorId'].toString(),
      );

      if (response['code'] == 'SUCCESS_0000') {
        setState(() {
          recommendPosts = response['data'] ?? [];
          isLoadingRecommend = false;
        });
      } else {
        throw response['info'] ?? '获取推荐帖子失败';
      }
    } catch (e) {
      print('获取推荐帖子失败: $e');
      if (mounted) {
        setState(() {
          isLoadingRecommend = false;
        });
      }
    }
  }

  // 添加获取商品推荐的方法
  Future<void> _fetchProductRecommend() async {
    setState(() {
      isLoadingProductRecommend = true;
    });

    try {
      final response = await ApiService().getProductRecommendByPost(
        postsId: widget.postId,
      );

      if (response['code'] == 'SUCCESS_0000') {
        setState(() {
          recommendProducts = response['data'] ?? [];
          // print('lg:${response['data']}');
          isLoadingProductRecommend = false;
        });
      } else {
        throw response['info'] ?? '获取商品推荐失败';
      }
    } catch (e) {
      print('获取商品推荐失败: $e');
      if (mounted) {
        setState(() {
          isLoadingProductRecommend = false;
        });
      }
    }
  }

  // 添加关注/取关处理方法
  Future<void> _handleFollow() async {
    if (isFollowLoading ||
        postDetail == null ||
        postDetail!['authorId'] == null)
      return;

    setState(() {
      isFollowLoading = true;
    });

    try {
      if (!isFollowing) {
        final response = await ApiService().followUser(
          postDetail!['authorId'].toString(),
        );
        if (response['code'] == 'SUCCESS_0000') {
          setState(() {
            isFollowing = true;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('关注成功'),
                duration: Duration(seconds: 1),
              ),
            );
          }
        } else {
          throw response['info'] ?? '关注失败';
        }
      } else {
        final response = await ApiService().unfollowUser(
          postDetail!['authorId'].toString(),
        );
        if (response['code'] == 'SUCCESS_0000') {
          setState(() {
            isFollowing = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('取消关注成功'),
                duration: Duration(seconds: 1),
              ),
            );
          }
        } else {
          throw response['info'] ?? '取消关注失败';
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('操作失败: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isFollowLoading = false;
        });
      }
    }
  }

  // 添加收藏/取消收藏处理方法
  Future<void> _handleCollect() async {
    if (isCollectLoading || postDetail == null) return;

    setState(() {
      isCollectLoading = true;
    });

    final postId =
        widget.postId; // 或者从 postDetail 获取 postDetail!['id'].toString()

    try {
      Map<String, dynamic> response;
      if (!isCollected) {
        response = await ApiService().collectPost(postId);
      } else {
        response = await ApiService().uncollectPost(postId);
      }

      if (response['code'] == 'SUCCESS_0000') {
        setState(() {
          isCollected = !isCollected; // 切换收藏状态
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isCollected ? '收藏成功' : '取消收藏成功'),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } else {
        throw response['info'] ?? (isCollected ? '取消收藏失败' : '收藏失败');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('操作失败: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
        // 可选：如果API调用失败，可能需要将状态回滚
        // setState(() { isCollected = !isCollected; });
      }
    } finally {
      if (mounted) {
        setState(() {
          isCollectLoading = false;
        });
      }
    }
  }

  // 添加点赞/取消点赞处理方法
  Future<void> _handleLike() async {
    if (isLikeLoading || postDetail == null) return;

    setState(() {
      isLikeLoading = true;
    });

    final postId = widget.postId;
    final originalLikedState = isLiked; // 保存原始状态用于回滚
    final originalLikesCount = likesCount; // 保存原始点赞数

    // 乐观更新 UI
    setState(() {
      isLiked = !isLiked;
      likesCount += isLiked ? 1 : -1;
    });

    try {
      Map<String, dynamic> response;
      if (isLiked) {
        // 注意：此时 isLiked 已经是目标状态
        response = await ApiService().likePost(postId);
      } else {
        response = await ApiService().unlikePost(postId);
      }

      if (response['code'] == 'SUCCESS_0000') {
        // API 调用成功，UI 已更新，无需额外操作
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(!originalLikedState ? '取消点赞成功' : '点赞成功'),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } else {
        // API 返回失败，回滚 UI
        setState(() {
          isLiked = originalLikedState;
          likesCount = originalLikesCount;
        });
        // 修改点：错误信息基于操作意图
        final String defaultErrorMessage = originalLikedState ? '取消点赞失败' : '点赞失败';
        throw response['info'] ?? defaultErrorMessage;
      }
    } catch (e) {
      // 捕获到异常，回滚 UI
      if (mounted) {
        // 检查 mounted 状态避免 setState 错误
        setState(() {
          isLiked = originalLikedState;
          likesCount = originalLikesCount;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('操作失败: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLikeLoading = false;
        });
      }
    }
  }

  // ---- 新增分享处理方法 ----
  Future<void> _handleSharePost() async {
    if (postDetail == null) return;

    final String postId = widget.postId;
    // 您可以自定义分享文本的格式
    final String shareText = "探索精彩内容！快来看看这个帖子，ID: $postId #LinkSphereApp";

    await Clipboard.setData(ClipboardData(text: shareText));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('分享链接已复制到剪贴板！'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
  // ---- 新增结束 ----

  // ---- 新增：滚动到评论区的方法 ----
  void _scrollToComments() {
    final context = _commentsSectionKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }
  // ---- 新增结束 ----

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (postDetail == null) {
      return const Scaffold(body: Center(child: Text('加载失败')));
    }

    // 修改图片列表获取方式
    final List<String> images =
        postDetail!['images']
            ?.toString()
            .split(',')
            .where((url) => url.trim().isNotEmpty)
            .toList() ??
        [];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 图片轮播
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  if (images.isNotEmpty)
                    SizedBox(
                      height: 300,
                      child: Swiper(
                        itemCount: images.length,
                        itemBuilder: (context, index) {
                          final imageUrl = images[index].trim();
                          return GestureDetector(
                            onTap:
                                () => _openImageGallery(context, index, images),
                            child:
                                imageUrl.isNotEmpty &&
                                        Uri.tryParse(
                                              imageUrl,
                                            )?.hasAbsolutePath ==
                                            true
                                    ? Image.network(
                                      imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (
                                        context,
                                        error,
                                        stackTrace,
                                      ) {
                                        return Image.network(
                                          'https://vcover-vt-pic.puui.qpic.cn/vcover_vt_pic/0/mzc00200n53vkqc1740479282101/0',
                                          fit: BoxFit.cover,
                                        );
                                      },
                                    )
                                    : Image.network(
                                      'https://vcover-vt-pic.puui.qpic.cn/vcover_vt_pic/0/mzc00200n53vkqc1740479282101/0',
                                      fit: BoxFit.cover,
                                    ),
                          );
                        },
                        pagination: const SwiperPagination(
                          builder: DotSwiperPaginationBuilder(
                            activeColor: Colors.white,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                    ),
                  // 添加半透明的渐变背景保护返回按钮
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 80,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withAlpha(178),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ), // 添加缺失的闭合括号
          // 帖子内容
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 添加作者信息行
                  Row(
                    children: [
                      // --- 修改开始 ---
                      GestureDetector(
                        // Wrap CircleAvatar with GestureDetector
                        onTap: () {
                          if (postDetail != null &&
                              postDetail!['authorId'] != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => UserProfilePage(
                                      authorId:
                                          postDetail!['authorId'].toString(),
                                    ),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('无法获取作者信息')),
                            );
                          }
                        },
                        child: CircleAvatar(
                          radius: 20,
                          backgroundImage: NetworkImage(
                            postDetail!['authorAvatar'] ?? '',
                          ),
                          onBackgroundImageError: (exception, stackTrace) {
                            // Handle avatar load error
                          },
                          // Fallback icon removed for cleaner look, error handled by NetworkImage
                        ),
                      ),
                      // --- 修改结束 ---
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              postDetail!['authorName'] ?? '',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Row(
                            //   children: [
                            //     Icon(Icons.remove_red_eye_outlined, size: 12, color: Colors.grey[600]),
                            //     const SizedBox(width: 4),
                            //     Text(
                            //       '${postDetail!['viewsCount'] ?? 0}',
                            //       style: TextStyle(
                            //         fontSize: 12,
                            //         color: Colors.grey[600],
                            //       ),
                            //     ),
                            //   ],
                            // ),
                          ],
                        ),
                      ),
                      // 修改关注按钮
                      ElevatedButton(
                        onPressed:
                            isFollowLoading
                                ? null
                                : _handleFollow, // 点击调用处理方法，加载时禁用
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isFollowing
                                  ? Colors
                                      .grey // 已关注时灰色背景
                                  : Theme.of(context).primaryColor, // 未关注时主题色
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        child:
                            isFollowLoading
                                ? const SizedBox(
                                  // 加载时显示指示器
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : Text(isFollowing ? '已关注' : '关注'), // 根据状态显示文本
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    postDetail!['title'] ?? '',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    postDetail!['content'] ?? '',
                    style: const TextStyle(fontSize: 16, height: 1.6),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          if (recommendPosts.isNotEmpty)
            // 添加推荐帖子列表标题
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '相关推荐',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (recommendPosts.isNotEmpty)
            // 添加推荐帖子列表
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isLoadingRecommend)
                      const Center(child: CircularProgressIndicator())
                    else if (recommendPosts.isEmpty)
                      const Center(child: Text('暂无推荐'))
                    else
                      SizedBox(
                        height: 240,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: recommendPosts.length,
                          itemBuilder: (context, index) {
                            final post = recommendPosts[index];
                            final images =
                                post['images']?.toString().split(',') ?? [];
                            final firstImage =
                                images.isNotEmpty ? images[0].trim() : '';

                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => PostDetailPage(
                                          postId: post['id'].toString(),
                                        ),
                                  ),
                                );
                              },
                              child: Container(
                                width: 160,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (firstImage.isNotEmpty)
                                      ClipRRect(
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(8),
                                            ),
                                        child: Image.network(
                                          firstImage,
                                          height: 160,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            post['title'] ?? '',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 12,
                                                backgroundImage: NetworkImage(
                                                  post['authorAvatar'] ?? '',
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  post['authorName'] ?? '',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
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
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (recommendProducts.isNotEmpty)
            // 添加推荐商品列表标题
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '相关推荐商品',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // 添加推荐商品列表
          if (recommendProducts.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isLoadingProductRecommend)
                      const Center(child: CircularProgressIndicator())
                    else if (recommendProducts.isEmpty)
                      const Center(child: Text('暂无推荐商品'))
                    else
                      SizedBox(
                        height: 240,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: recommendProducts.length,
                          itemBuilder: (context, index) {
                            final product = recommendProducts[index];
                            final images =
                                product['images']?.toString().split(',') ?? [];
                            final firstImage =
                                images.isNotEmpty ? images[0].trim() : '';

                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) =>
                                            ProductDetailPage(product: product),
                                  ),
                                );
                              },
                              child: Container(
                                width: 160,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (firstImage.isNotEmpty)
                                      ClipRRect(
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(8),
                                            ),
                                        child: Image.network(
                                          firstImage,
                                          height: 160,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product['title'] ?? '',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Text(
                                                '¥${product['price'] ?? ''}',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
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
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          // 添加评论列表
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                key: _commentsSectionKey, // <-- 将 GlobalKey 赋予评论区容器
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '评论',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (isLoadingComments)
                    const Center(child: CircularProgressIndicator())
                  else if (comments.isEmpty)
                    const Center(child: Text('暂无评论'))
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: comments.length + (hasMoreComments ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index < comments.length) {
                          final comment = comments[index];
                          final replies = comment['replies'] as List? ?? [];

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildCommentItem(comment),
                              if (replies.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(left: 16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children:
                                        replies.map((reply) {
                                          return ListTile(
                                            dense: true,
                                            leading: CircleAvatar(
                                              radius: 16,
                                              backgroundImage: NetworkImage(
                                                reply['userAvatar'] ?? '',
                                              ),
                                            ),
                                            title: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  reply['userName'] ?? '',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  reply['time'] ?? '',
                                                  style: const TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            subtitle: Text(
                                              reply['content'] ?? '',
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                  ),
                                ),
                            ],
                          );
                        } else {
                          return _buildLoadMoreButton();
                        }
                      },
                    ),
                  SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet:
          postDetail == null
              ? null
              : _currentReplyComment != null
              ? Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '回复 ${_currentReplyComment!['userName'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _replyController,
                            decoration: InputDecoration(
                              hintText: '输入你的回复...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.grey[200],
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                            maxLines: null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_isUploadingReplyImage)
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        if (_replyImageFile != null)
                          Stack(
                            alignment: Alignment.topRight,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.file(
                                    File(_replyImageFile!.path),
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: _removeReplyImage,
                                child: Container(
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
                            ],
                          )
                        else
                          IconButton(
                            icon: const Icon(Icons.image, color: Colors.green),
                            tooltip: '添加图片',
                            onPressed:
                                _isUploadingReplyImage ? null : _pickReplyImage,
                          ),
                        IconButton(
                          icon: const Icon(Icons.send, color: Colors.blue),
                          onPressed: _sendReply,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () {
                            setState(() {
                              _currentReplyComment = null;
                              _replyImageFile = null;
                              _replyImageUrl = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              )
              : Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: InputDecoration(
                          hintText: '发表你的评论...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey[200],
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        maxLines: null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_isUploadingCommentImage)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    if (_commentImageFile != null)
                      Stack(
                        alignment: Alignment.topRight,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.file(
                                File(_commentImageFile!.path),
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: _removeCommentImage,
                            child: Container(
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
                        ],
                      ),
                    IconButton(
                      icon: const Icon(Icons.image, color: Colors.green),
                      tooltip: '添加图片',
                      onPressed: _isUploadingCommentImage ? null : _pickCommentImage,
                    ),
                    IconButton(
                      icon: const Icon(Icons.send, color: Colors.blue),
                      onPressed: _publishComment,
                    ),
                  ],
                ),
              ),
      bottomNavigationBar:
          postDetail == null
              ? null
              : PostBottomBar(
                post: postDetail!,
                isCollected: isCollected,
                isCollectLoading: isCollectLoading,
                onCollectPressed: _handleCollect,
                isLiked: isLiked,
                isLikeLoading: isLikeLoading,
                likesCount: likesCount,
                onLikePressed: _handleLike,
                onSharePressed: _handleSharePost, 
                onCommentIconPressed: _scrollToComments, 
                actualCommentsCount: comments.length,
              ),
    );
  }

  void _openImageGallery(
    BuildContext context,
    int initialIndex,
    List<String> images,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ImageGalleryPage(
              images: images.map((url) => url.trim()).toList(),
              initialIndex: initialIndex,
            ),
      ),
    );
  }

  // 点击回复按钮时调用
  void _openReplyBox(Map<String, dynamic> comment) {
    setState(() {
      _currentReplyComment = comment;
      // 自动聚焦到回复输入框
      FocusScope.of(context).requestFocus();
    });
  }

  // 发布回复
  Future<void> _sendReply() async {
    if (_currentReplyComment == null || _replyController.text.trim().isEmpty) {
      return;
    }

    try {
      print('parentId${_currentReplyComment!['parentId']}');
      final response = await ApiService().publishReply(
        replyCommentId: int.parse(_currentReplyComment!['commentId']),
        parentId:
            _currentReplyComment!['parentId'] != null &&
                    _currentReplyComment!['parentId'].toString().isNotEmpty
                ? int.parse(_currentReplyComment!['parentId'].toString())
                : null,
        content: _replyController.text.trim(),
        imageUrl: _replyImageUrl ?? '',
      );
      print('回复评论$response');
      if (response['code'] == 'SUCCESS_0000') {
        // 清空回复输入框和图片
        _replyController.clear();
        setState(() {
          _replyImageFile = null;
          _replyImageUrl = null;
        });

        // 关闭回复输入框
        setState(() {
          _currentReplyComment = null;
        });

        // 重新获取评论列表，不重置滚动位置
        await _fetchComments(resetScroll: false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('回复成功'), duration: Duration(seconds: 2)),
        );
      } else {
        throw response['info'] ?? '发布回复失败';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is String ? e : '发布回复失败'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

class ImageGalleryPage extends StatelessWidget {
  final List<String> images;
  final int initialIndex;

  const ImageGalleryPage({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PhotoViewGallery.builder(
            itemCount: images.length,
            builder: (context, index) {
              return PhotoViewGalleryPageOptions(
                imageProvider: NetworkImage(images[index]),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 2,
              );
            },
            scrollPhysics: const BouncingScrollPhysics(),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            pageController: PageController(initialPage: initialIndex),
          ),
          // 关闭按钮
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 10,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

// 移除 CommentItem 类
