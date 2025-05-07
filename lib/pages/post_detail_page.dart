
import 'package:flutter/material.dart';
import 'package:flutter_swiper_null_safety/flutter_swiper_null_safety.dart';
import 'package:link_sphere/services/api_service.dart';
import 'package:link_sphere/widgets/post/post_bottom_bar.dart';
// import 'package:link_sphere/widgets/post/post_header.dart'; // Removed unused import
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:link_sphere/pages/user_profile_page.dart'; // 导入新页面

class PostDetailPage extends StatefulWidget {
  final String postId;

  const PostDetailPage({
    super.key,
    required this.postId,
  });

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  Map<String, dynamic>? postDetail;
  List<dynamic> recommendPosts = []; // 添加推荐帖子列表
  bool isLoading = true;
  bool isLoadingRecommend = false; // 添加推荐帖子加载状态
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

  @override
  void initState() {
    super.initState();
    _fetchPostDetail();
    _fetchComments(); // 初始化时加载评论
  }

  Future<void> _fetchPostDetail() async {
    setState(() { // 开始加载时重置状态
      isLoading = true;
      isFollowing = false;
      isCollected = false;
      isLiked = false; // 重置点赞状态
      likesCount = 0; // 重置点赞数
    });
    try {
      final response = await ApiService().getPostDetail(widget.postId)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw '网络请求超时，请检查网络连接';
            },
          );

      if (response['code'] == 'SUCCESS_0000') {
        setState(() {
          postDetail = response['data'];
          isFollowing = postDetail?['isFollowed'] ?? false;
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
      if (mounted) {  // 添加 mounted 检查
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

// 添加获取评论的方法
  Future<void> _fetchComments() async {

    setState(() {
      isLoadingComments = true;
    });

    try {
      final response = await ApiService().getComments(
        entityType: 'post',
        entityId: widget.postId,
        page: commentPage,
      );

      if (response['code'] == 'SUCCESS_0000') {
        setState(() {
          comments.addAll(response['data']['comments']);
          hasMoreComments = response['data']['hasMore'];
          isLoadingComments = false;
        });
      } else {
        throw response['info'] ?? '获取评论失败';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('加载评论失败: $e')));
        setState(() {
          isLoadingComments = false;
        });
      }
    }
  }
  // Add the missing method definition here
  Future<void> _fetchRecommendPosts() async {
    if (postDetail == null || postDetail!['authorId'] == null) return;
    
    setState(() {
      isLoadingRecommend = true;
    });

    try {
      // Use the correct API method name as defined in ApiService
      final response = await ApiService().getRecommendContentForPost( 
        postAuthorId: postDetail!['authorId'].toString(),
        // topN: 6, // topN is optional, defaults to 6 in ApiService
      );

      if (response['code'] == 'SUCCESS_0000') {
        // Ensure the data structure matches the API response
        // The API returns a list directly in the 'data' field
        setState(() {
          recommendPosts = response['data'] ?? []; 
          isLoadingRecommend = false;
        });
      } else {
        throw response['info'] ?? '获取推荐帖子失败';
      }
    } catch (e) {
      print('获取推荐帖子失败: $e');
      // Avoid calling setState if the widget is disposed
      if (mounted) { 
        setState(() {
          isLoadingRecommend = false;
        });
        // Optionally show a snackbar for the error
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('加载推荐失败: $e')),
        // );
      }
    }
  }

  // 添加关注/取关处理方法
  Future<void> _handleFollow() async {
    if (isFollowLoading || postDetail == null || postDetail!['authorId'] == null) return;

    setState(() {
      isFollowLoading = true;
    });

    try {
      if (!isFollowing) {
        final response = await ApiService().followUser(postDetail!['authorId'].toString());
        if (response['code'] == 'SUCCESS_0000') {
          setState(() {
            isFollowing = true;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('关注成功'), duration: Duration(seconds: 1)),
            );
          }
        } else {
          throw response['info'] ?? '关注失败';
        }
      } else {
        final response = await ApiService().unfollowUser(postDetail!['authorId'].toString());
        if (response['code'] == 'SUCCESS_0000') {
          setState(() {
            isFollowing = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('取消关注成功'), duration: Duration(seconds: 1)),
            );
          }
        } else {
          throw response['info'] ?? '取消关注失败';
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e'), duration: const Duration(seconds: 2)),
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

    final postId = widget.postId; // 或者从 postDetail 获取 postDetail!['id'].toString()

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
            SnackBar(content: Text(isCollected ? '收藏成功' : '取消收藏成功'), duration: const Duration(seconds: 1)),
          );
        }
      } else {
        throw response['info'] ?? (isCollected ? '取消收藏失败' : '收藏失败');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e'), duration: const Duration(seconds: 2)),
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
      if (isLiked) { // 注意：此时 isLiked 已经是目标状态
        response = await ApiService().likePost(postId);
      } else {
        response = await ApiService().unlikePost(postId);
      }

      if (response['code'] == 'SUCCESS_0000') {
        // API 调用成功，UI 已更新，无需额外操作
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text(isLiked ? '点赞成功' : '取消点赞成功'), duration: const Duration(seconds: 1)),
           );
        }
      } else {
         // API 返回失败，回滚 UI
        setState(() {
          isLiked = originalLikedState;
          likesCount = originalLikesCount;
        });
        throw response['info'] ?? (isLiked ? '点赞失败' : '取消点赞失败');
      }
    } catch (e) {
      // 捕获到异常，回滚 UI
       if (mounted) { // 检查 mounted 状态避免 setState 错误
         setState(() {
           isLiked = originalLikedState;
           likesCount = originalLikesCount;
         });
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('操作失败: $e'), duration: const Duration(seconds: 2)),
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


  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (postDetail == null) {
      return const Scaffold(
        body: Center(
          child: Text('加载失败'),
        ),
      );
    }

    // 修改图片列表获取方式
    final List<String> images = postDetail!['images']?.toString().split(',').where((url) => url.trim().isNotEmpty).toList() ?? [];

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
                  if (images.isNotEmpty) SizedBox(
                    height: 300,
                    child: Swiper(
                      itemCount: images.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () => _openImageGallery(context, index, images),
                          child: Image.network(
                            images[index].trim(),
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
                      GestureDetector( // Wrap CircleAvatar with GestureDetector
                        onTap: () {
                          if (postDetail != null && postDetail!['authorId'] != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => UserProfilePage(
                                  authorId: postDetail!['authorId'].toString(),
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
                          backgroundImage: NetworkImage(postDetail!['authorAvatar'] ?? ''),
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
                        onPressed: isFollowLoading ? null : _handleFollow, // 点击调用处理方法，加载时禁用
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFollowing
                              ? Colors.grey // 已关注时灰色背景
                              : Theme.of(context).primaryColor, // 未关注时主题色
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        child: isFollowLoading
                            ? const SizedBox( // 加载时显示指示器
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          // 添加推荐帖子列表标题
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                          final images = post['images']?.toString().split(',') ?? [];
                          final firstImage = images.isNotEmpty ? images[0].trim() : '';
                          
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PostDetailPage(
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
                                      borderRadius: const BorderRadius.vertical(
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
                                      crossAxisAlignment: CrossAxisAlignment.start,
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
                                                overflow: TextOverflow.ellipsis,
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
          // 添加评论列表
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '评论',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
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
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: NetworkImage(comment['userAvatar'] ?? ''),
                          ),
                          title: Text(comment['userName'] ?? ''),
                          subtitle: Text(comment['content'] ?? ''),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: postDetail == null
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
            ),
    );
  }

  void _openImageGallery(BuildContext context, int initialIndex, List<String> images) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageGalleryPage(
          images: images.map((url) => url.trim()).toList(),
          initialIndex: initialIndex,
        ),
      ),
    );
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
              icon: const Icon(
                Icons.close,
                color: Colors.white,
                size: 30,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

// 移除 CommentItem 类
