import 'package:flutter/material.dart';

class PostBottomBar extends StatelessWidget {
  final Map<String, dynamic> post;
  final bool isCollected;
  final bool isCollectLoading;
  final VoidCallback onCollectPressed;
  final bool isLiked;
  final bool isLikeLoading;
  final int likesCount;
  final VoidCallback onLikePressed;
  final VoidCallback? onSharePressed;
  final VoidCallback? onCommentIconPressed;
  final int actualCommentsCount;

  const PostBottomBar({
    super.key,
    required this.post,
    required this.isCollected,
    required this.isCollectLoading,
    required this.onCollectPressed,
    required this.isLiked,
    required this.isLikeLoading,
    required this.likesCount,
    required this.onLikePressed,
    this.onSharePressed,
    this.onCommentIconPressed,
    required this.actualCommentsCount,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            // Comment button
            TextButton.icon(
              icon: const Icon(Icons.comment_outlined),
              label: Text(actualCommentsCount.toString()),
              onPressed: onCommentIconPressed,
            ),
            // Collect button
            TextButton.icon(
              icon: Icon(
                isCollected ? Icons.star : Icons.star_border,
                color: isCollected ? Colors.amber : null,
              ),
              label: Text(isCollected ? '已收藏' : '收藏'),
              onPressed: isCollectLoading ? null : onCollectPressed,
            ),
            // Like button
            TextButton.icon(
              icon: Icon(
                isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                color: isLiked ? Theme.of(context).primaryColor : null,
              ),
              label: Text(likesCount.toString()),
              onPressed: isLikeLoading ? null : onLikePressed,
            ),
            // Share button
            if (onSharePressed != null)
              TextButton.icon(
                icon: const Icon(Icons.share_outlined),
                label: const Text('分享'),
                onPressed: onSharePressed,
              ),
          ],
        ),
      ),
    );
  }
}