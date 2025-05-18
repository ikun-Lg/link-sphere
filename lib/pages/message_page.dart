import 'package:flutter/material.dart';
import '../models/search_user.dart';
import '../services/api_service.dart';
import 'chat_page.dart';

class MessagePage extends StatefulWidget {
  const MessagePage({super.key});

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  List<SearchUser> friends = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    setState(() {
      isLoading = true;
    });

    try {
      final List<Map<String, dynamic>> friendList = await ApiService().getFriends();
      setState(() {
        friends = friendList.map((json) => SearchUser.fromJson(json)).toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载好友列表失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('消息'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadFriends,
              child: ListView.builder(
                itemCount: friends.length,
                itemBuilder: (context, index) {
                  final friend = friends[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: NetworkImage(friend.avatarUrl),
                    ),
                    title: Text(friend.username),
                    subtitle: Text(friend.email),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatPage(
                            receiverId: friend.id,
                            receiverName: friend.username,
                            receiverAvatar: friend.avatarUrl,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
    );
  }
}