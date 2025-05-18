import 'package:flutter/material.dart';
import '../models/message.dart';
import '../services/websocket_service.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ChatPage extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  final String receiverAvatar;

  const ChatPage({
    super.key,
    required this.receiverId,
    required this.receiverName,
    required this.receiverAvatar,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<Message>? _messageSubscription;
  final WebSocketService _wsService = WebSocketService();
  late SharedPreferences _prefs;
  String get _chatKey => 'chat_${_wsService.currentUserId}_${widget.receiverId}';

  @override
  void initState() {
    super.initState();
    _initSharedPreferences();
    _messageSubscription = _wsService.messageStream.listen(_handleNewMessage);
  }

  Future<void> _initSharedPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    _loadMessages();
  }

  void _loadMessages() {
    final savedMessages = _prefs.getStringList(_chatKey);
    if (savedMessages != null) {
      setState(() {
        _messages.addAll(
          savedMessages.map((msgJson) => ChatMessage.fromJson(jsonDecode(msgJson))).toList()
        );
      });
      // 延迟滚动到底部，确保列表构建完成
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  Future<void> _saveMessages() async {
    final messagesJson = _messages.map((msg) => jsonEncode(msg.toJson())).toList();
    await _prefs.setStringList(_chatKey, messagesJson);
  }

  void _handleNewMessage(Message message) {
    print('ChatPage 收到新消息: ${message.messageType}');
    
    if (message.isMessage) {
      try {
        final chatMessage = ChatMessage.fromJson(message.data);
        final currentUserId = _wsService.currentUserId;
        print('消息详情: senderId=${chatMessage.senderId}, receiverId=${chatMessage.receiverId}, currentUserId=$currentUserId, widget.receiverId=${widget.receiverId}');

        // 检查消息是否属于当前聊天
        if (chatMessage.senderId == currentUserId && chatMessage.receiverId == widget.receiverId) {
          print('收到自己发给 ${widget.receiverName} 的消息副本，忽略');
          return;
        }

        if (chatMessage.receiverId == currentUserId && chatMessage.senderId == widget.receiverId) {
          print('收到 ${widget.receiverName} 发来的新消息，添加到列表');
          setState(() {
            _messages.add(chatMessage);
          });
          _saveMessages();
          _delayedScrollToBottom(); // 使用延迟滚动
        } else {
          print('消息不匹配当前聊天，忽略');
        }
      } catch (e) {
        print('处理聊天消息时出错: $e');
        print('消息数据: ${message.data}');
      }
    } else if (message.isAck) {
      try {
        final ack = MessageAck.fromJson(message.data);
        print('收到消息确认: messageId=${ack.messageId}, status=${ack.status}');
        
        if (ack.status != 'SUCCESS' && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('消息发送失败: ${ack.message}')),
          );
        }
      } catch (e) {
        print('处理消息确认时出错: $e');
        print('消息数据: ${message.data}');
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _delayedScrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _scrollToBottom();
      }
    });
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final tempMessage = ChatMessage(
      messageId: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      senderId: _wsService.currentUserId ?? '',
      receiverId: widget.receiverId,
      sendTime: DateTime.now().toIso8601String(),
      read: false,
    );

    // 先添加到本地列表并保存
    setState(() {
      _messages.add(tempMessage);
    });
    _saveMessages();
    _delayedScrollToBottom(); // 使用延迟滚动

    _messageController.clear();

    try {
      final success = await _wsService.sendMessage(content, widget.receiverId);
      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('消息发送失败')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送消息出错: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _saveMessages(); // 退出聊天页面时保存
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _wsService.currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: NetworkImage(widget.receiverAvatar),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(widget.receiverName, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isMe = message.senderId == currentUserId;
                
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.blue : Colors.grey[300],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      message.content,
                      style: TextStyle(
                        color: isMe ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: '输入消息...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.0),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    ),
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  onPressed: _sendMessage,
                  mini: true,
                  elevation: 0,
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}