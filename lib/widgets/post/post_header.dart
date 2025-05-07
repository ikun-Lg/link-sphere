import 'package:flutter/material.dart';

class PostHeader extends StatelessWidget {
  final Map<String, dynamic> post;

  const PostHeader({
    super.key,
    required this.post,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundImage: NetworkImage(
            'https://picsum.photos/50/50?random=${post['title']}',
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              post['author'] ?? '用户名',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '2024-01-20',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
        const Spacer(),
        TextButton(
          onPressed: () {},
          child: const Row(
            children: [
              Icon(Icons.add),
              Text('关注'),
            ],
          ),
        ),
      ],
    );
  }
}