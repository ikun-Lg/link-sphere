import 'package:flutter/material.dart';

class PostBottomBar extends StatelessWidget {
  final Map<String, dynamic> post;
  final bool isCollected;
  final bool isCollectLoading;
  final VoidCallback? onCollectPressed;
  final bool isLiked; // Add this parameter
  final bool isLikeLoading; // Add this parameter
  final int likesCount; // Add this parameter
  final VoidCallback? onLikePressed; // Add this parameter
  // TODO: Add parameters for comment, share state and callbacks

  const PostBottomBar({
    super.key,
    required this.post,
    required this.isCollected,
    required this.isCollectLoading,
    this.onCollectPressed,
    required this.isLiked, // Add and make required
    required this.isLikeLoading, // Add and make required
    required this.likesCount, // Add and make required
    this.onLikePressed, // Add (optional or required)
    // TODO: Initialize other parameters
  });

  @override
  Widget build(BuildContext context) {
    // Use parameters instead of deriving from 'post' map for like state/count
    // final int likesCount = post['likesCount'] ?? 0; // Remove or comment out
    final int commentsCount = post['commentsCount'] ?? 0;
    final int sharesCount = post['sharesCount'] ?? 0;
    // final bool isLiked = post['isLikedByCurrentUser'] ?? false; // Remove or comment out

    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Comment Button
          _buildIconButton(
            context: context,
            icon: Icons.chat_bubble_outline,
            label: commentsCount > 0 ? '$commentsCount' : '评论',
            onPressed: () {
              // TODO: Implement comment action
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('评论功能待实现')),
              );
            },
          ),
          // Like Button (Using the new parameters)
          _buildIconButton(
            context: context,
            icon: isLiked ? Icons.favorite : Icons.favorite_border, // Use parameter
            label: likesCount > 0 ? '$likesCount' : '点赞', // Use parameter
            color: isLiked ? Colors.red : null, // Use parameter
            isLoading: isLikeLoading, // Use parameter
            onPressed: onLikePressed, // Use parameter
          ),
          // Collect Button
          _buildIconButton(
            context: context,
            icon: isCollected ? Icons.star : Icons.star_border,
            label: '收藏',
            color: isCollected ? Colors.amber : null,
            isLoading: isCollectLoading,
            onPressed: onCollectPressed,
          ),
          // Share Button
          _buildIconButton(
            context: context,
            icon: Icons.share_outlined,
            label: sharesCount > 0 ? '$sharesCount' : '分享',
            onPressed: () {
              // TODO: Implement share action
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('分享功能待实现')),
              );
            },
          ),
        ],
      ),
    );
  }

  // Helper method to build icon buttons, now includes isLoading
  Widget _buildIconButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    Color? color,
    VoidCallback? onPressed,
    bool isLoading = false, // Add isLoading parameter
  }) {
    final effectiveColor = color ?? Theme.of(context).iconTheme.color;
    return TextButton.icon(
      onPressed: isLoading ? null : onPressed, // Disable when loading
      icon: isLoading
          ? SizedBox( // Show progress indicator when loading
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: effectiveColor),
            )
          : Icon(icon, color: effectiveColor, size: 20),
      label: Text(
        label,
        style: TextStyle(color: effectiveColor, fontSize: 12),
      ),
      style: TextButton.styleFrom(
        foregroundColor: effectiveColor,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }
}