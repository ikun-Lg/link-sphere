import 'package:flutter/material.dart';
import '../widgets/message/message_list_item.dart';
import 'chat_page.dart';

class MessagePage extends StatelessWidget {
  const MessagePage({super.key});

  @override
  Widget build(BuildContext context) {
    // 模拟消息列表数据
    final List<Map<String, dynamic>> messages = List.generate(
      20,
      (index) => {
        'avatar': 'https://picsum.photos/200/200?random=$index',
        'username': '用户 $index',
        'lastMessage': '这是最后一条消息 $index',
        'time': '${index + 1}分钟前',
        'hasUnread': index % 3 == 0,
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('消息'),
      ),
      body: ListView.separated(
        itemCount: messages.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final message = messages[index];
          return InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatPage(
                    username: message['username'],
                    avatar: message['avatar'],
                  ),
                ),
              );
            },
            child: MessageListItem(
              avatar: message['avatar'],
              username: message['username'],
              lastMessage: message['lastMessage'],
              time: message['time'],
              hasUnread: message['hasUnread'],
            ),
          );
        },
      ),
    );
  }
}