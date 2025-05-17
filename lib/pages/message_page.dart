import 'package:flutter/material.dart';
import '../widgets/message/message_list_item.dart';
import 'chat_page.dart';
import 'package:link_sphere/services/api_service.dart';

class MessagePage extends StatefulWidget {
  const MessagePage({super.key});

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  List<Map<String, dynamic>> _friends = [];
  bool _loading = true;
  String? _error;
  static const String defaultAvatar = 'https://tvpic.gtimg.cn/head/c2010ebc0c8b6d8521373ffeced635c8da39a3ee5e6b4b0d3255bfef95601890afd80709/361?imageView2/2/w/100';

  @override
  void initState() {
    super.initState();
    _fetchFriends();
  }

  Future<void> _fetchFriends() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final friends = await ApiService().getFriends();
      setState(() {
        _friends = friends;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('好友列表'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _friends.isEmpty
                  ? const Center(child: Text('暂无好友'))
                  : RefreshIndicator(
                      onRefresh: _fetchFriends,
                      child: ListView.separated(
                        itemCount: _friends.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final friend = _friends[index];
                          return InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatPage(
                                    username: friend['username'] ?? '好友',
                                    avatar: (friend['avatar'] == null || (friend['avatar'] as String).isEmpty)
                                        ? defaultAvatar
                                        : friend['avatar'],
                                    friendId: friend['id']?.toString() ?? '',
                                  ),
                                ),
                              );
                            },
                            child: MessageListItem(
                              avatar: (friend['avatar'] == null || (friend['avatar'] as String).isEmpty)
                                  ? defaultAvatar
                                  : friend['avatar'],
                              username: friend['username'] ?? '好友',
                              lastMessage: friend['lastMessage'] ?? '',
                              time: '',
                              hasUnread: false,
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}