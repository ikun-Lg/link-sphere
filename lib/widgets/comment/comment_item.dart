import 'package:flutter/material.dart';
import 'reply_item.dart';

class CommentItem extends StatelessWidget {
  final String username;
  final String avatar;
  final String content;
  final String time;
  final int likes;
  final List<Map<String, dynamic>> replies;

  const CommentItem({
    super.key,
    required this.username,
    required this.avatar,
    required this.content,
    required this.time,
    required this.likes,
    this.replies = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundImage: NetworkImage(avatar),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      content,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          time,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[400],
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {},
                          style: TextButton.styleFrom(
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: Text(
                            '回复',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[400],
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(
                            Icons.favorite_border,
                            size: 16,
                          ),
                        ),
                        Text(
                          '$likes',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 44),
              child: Column(
                children: replies.map((reply) {
                  return ReplyItem(
                    username: reply['username'],
                    replyTo: reply['replyTo'],
                    content: reply['content'],
                    time: reply['time'],
                    likes: reply['likes'],
                  );
                }).toList(),
              ),
            ),
          Divider(color: Colors.grey[200]),
        ],
      ),
    );
  }
}