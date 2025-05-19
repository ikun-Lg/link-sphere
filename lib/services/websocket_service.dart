import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../models/message.dart';
import 'user_service.dart';
import 'noti_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; // <--- 新增导入
import 'package:flutter/material.dart'; // <--- 新增导入
import '../pages/login_page.dart'; // <--- 新增导入，确保路径正确
import 'api_service.dart'; // 确保导入 ApiService
import '../models/user.dart'; // 确保导入 User 模型 (如果 getUserProfileById 返回 User 对象)

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  Timer? _heartbeatTimer;
  final String _baseUrl = 'ws://115.190.33.252:8089/api/v1/ws';
  String? _token;
  bool _isConnected = false;
  String? _currentUserId;

  // 消息流控制器
  StreamController<Message> _messageController = StreamController<Message>.broadcast();
  Stream<Message> get messageStream => _messageController.stream;

  // 连接状态流控制器
  StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionController.stream;

  // 获取当前用户ID
  String? get currentUserId => _currentUserId;

  // 检查并自动连接
  Future<bool> checkAndConnect() async {
    try {
      final user = await UserService.getUser();
      if (user != null && user.token.isNotEmpty) {
        await initialize(user.token, user.id.toString());
        return true;
      }
      return false;
    } catch (e) {
      print('WebSocket自动连接失败: $e');
      return false;
    }
  }

  // 初始化WebSocket连接
  Future<void> initialize(String token, String userId) async {
    _token = token;
    _currentUserId = userId;
    
    // 如果 StreamController 已关闭，创建新的实例
    if (_messageController.isClosed) {
      _messageController = StreamController<Message>.broadcast();
    }
    if (_connectionController.isClosed) {
      _connectionController = StreamController<bool>.broadcast();
    }
    
    await connect();
    _startHeartbeat();
  }

  // 连接WebSocket
  Future<void> connect() async {
    if (_token == null) {
      throw Exception('Token is required to connect to WebSocket');
    }

    try {
      final wsUrl = '$_baseUrl?token=$_token';
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      
      _channel!.stream.listen(
        (message) {
          if (!_messageController.isClosed) {
          _handleMessage(message);
          }
        },
        onError: (error) {
          print('WebSocket Error: $error');
          _isConnected = false;
          if (!_connectionController.isClosed) {
          _connectionController.add(false);
          }
          _reconnect();
        },
        onDone: () {
          print('WebSocket connection closed');
          _isConnected = false;
          if (!_connectionController.isClosed) {
          _connectionController.add(false);
          }
          _reconnect();
        },
      );

      _isConnected = true;
      if (!_connectionController.isClosed) {
      _connectionController.add(true);
      }
    } catch (e) {
      print('WebSocket connection error: $e');
      _isConnected = false;
      if (!_connectionController.isClosed) {
      _connectionController.add(false);
      }
      _reconnect();
    }
  }

  // 重连机制
  Future<void> _reconnect() async {
    await Future.delayed(const Duration(seconds: 5));
    if (!_isConnected) {
      await connect();
    }
  }

  // 发送消息
  Future<bool> sendMessage(String content, String receiverId) async {
    if (!_isConnected) {
      throw Exception('WebSocket is not connected');
    }

    try {
      final message = {
        'messageType': 'message',
        'data': {
          'messageId': _generateMessageId(),
          'content': content,
          'receiverId': receiverId,
        }
      };

      print('发送消息: ${jsonEncode(message)}');
      _channel?.sink.add(jsonEncode(message));
      return true;
    } catch (e) {
      print('发送消息出错: $e');
      return false;
    }
  }

  // 发送测试消息
  Future<bool> sendTestMessage() async {
    if (!_isConnected) {
      throw Exception('WebSocket is not connected');
    }

    try {
      final message = {
        'messageType': 'message',
        'data': {
          'messageId': _generateMessageId(),
          'content': '这是一条LGGBOND测试消息 ${DateTime.now()}',
          'receiverId': '1',
        }
      };

      _channel?.sink.add(jsonEncode(message));
      return true;
    } catch (e) {
      print('Error sending test message: $e');
      return false;
    }
  }

  // 发送心跳
  void _sendHeartbeat() {
    if (!_isConnected) return;

    final heartbeat = {
      'messageType': 'heartbeat',
      'messageId': _generateMessageId(),
    };

    print('发送心跳: ${jsonEncode(heartbeat)}');
    _channel?.sink.add(jsonEncode(heartbeat));
  }

  // 启动心跳定时器
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (timer) {
      _sendHeartbeat();
    });
  }

  SharedPreferences? _prefs; // 添加 SharedPreferences 实例

  // WebSocketService._internal() {  <--- REMOVE THIS CONSTRUCTOR
  //   _initPrefs(); // 初始化 SharedPreferences
  // }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Helper to get chat key, ensure consistency with ChatPage
  String _getChatKey(String userId1, String userId2) {
    // Sort IDs to ensure consistency, e.g., 'chat_1_2' is same as 'chat_2_1'
    List<String> ids = [userId1, userId2];
    ids.sort();
    return 'chat_${ids[0]}_${ids[1]}';
  }

  // 处理接收到的消息
  void _handleMessage(String message) async {
    try {
      final decodedMessage = jsonDecode(message);
      final msg = Message.fromJson(decodedMessage);
      print('收到消息1: ${jsonEncode(msg.toJson())}');
      
      if (msg.isMessage) {
        final chatMessage = ChatMessage.fromJson(msg.data);
        if (!_messageController.isClosed) {
          _messageController.add(msg);
        }
        print('收到消息2: ${jsonEncode(chatMessage.toJson())}');
        
        // 确保 SharedPreferences 已初始化
        if (_prefs == null) {
          await _initPrefs();
        }
        
        // 将收到的消息保存到本地
        if (_prefs != null) {
          try {
            final chatKey = _getChatKey(chatMessage.senderId, chatMessage.receiverId);
            final savedMessages = _prefs!.getStringList(chatKey) ?? [];
            
            // 检查消息是否已存在
            bool messageExists = savedMessages.any((m) {
              try {
                final existingMsg = jsonDecode(m);
                return existingMsg['messageId'] == chatMessage.messageId;
              } catch (e) {
                return false;
              }
            });
            
            if (!messageExists) {
              savedMessages.add(jsonEncode(chatMessage.toJson()));
              await _prefs!.setStringList(chatKey, savedMessages);
              print('消息已保存到本地存储: $chatKey, 消息ID: ${chatMessage.messageId}');
            } else {
              print('消息已存在，跳过保存: ${chatMessage.messageId}');
            }
          } catch (e) {
            print('保存消息到本地存储失败: $e');
          }
        }

        // 仅当消息不是由当前用户发送时才显示通知 (这部分逻辑和之前一样)
        if (chatMessage.senderId != _currentUserId) {
          String senderName = chatMessage.senderId; // 默认使用 senderId
          String senderAvatar = "https://tvpic.gtimg.cn/head/c2010ebc0c8b6d8521373ffeced635c8da39a3ee5e6b4b0d3255bfef95601890afd80709/361?imageView2/2/w/100"; // 默认头像

          try {
            // 调用API获取发送者信息
            final apiService = ApiService();
            // 注意：您需要确保 ApiService 中有类似 getUserProfileById 的方法
            // 并且该方法能正确处理可能发生的异常
            int? senderIdInt = int.tryParse(chatMessage.senderId);
            if (senderIdInt != null) {
              final userInfoResponse = await apiService.getUserInfo(senderIdInt);

              // 假设 getUserProfileById 返回的是一个包含用户信息的Map，或者一个User对象
              // 例如，如果返回的是 User 对象:
              // final User senderInfo = User.fromJson(userInfoResponse['data']);
              // senderName = senderInfo.username;
              // senderAvatar = senderInfo.avatarUrl;

              // 或者如果直接返回包含 username 和 avatarUrl 的 Map:
              if (userInfoResponse['code'] == 'SUCCESS_0000' && userInfoResponse['data'] != null) {
                  final userData = userInfoResponse['data'];
                  senderName = userData['username'] ?? chatMessage.senderId;
                  // 移除 avatarUrl 周围可能存在的反引号和空格
                  String? rawAvatarUrl = userData['avatarUrl'];
                  if (rawAvatarUrl != null) {
                    senderAvatar = rawAvatarUrl.trim().replaceAll('`', '');
                  } else {
                    senderAvatar = senderAvatar; // Keep default if null
                  }
              } else {
                  print('获取发送者 ${chatMessage.senderId} 信息失败: ${userInfoResponse['info']}');
              }
            } else {
              print('无法将 senderId ${chatMessage.senderId} 转换为整数');
            }

          } catch (e) {
            print('获取发送者 ${chatMessage.senderId} 信息时出错: $e');
            // 出错时，保持使用 senderId 和默认头像
          }

          NotiService.showDailyNotification(
            title: '新消息来自 $senderName',
            body: chatMessage.content,
            payload: jsonEncode({
              'type': 'chat',
              'senderId': chatMessage.senderId,
              'senderName': senderName, 
              'senderAvatar': senderAvatar, 
            }),
          );
        }
      } else if (msg.isAdvertisement) {
        print('收到广告消息: ${msg.data}'); // <--- Use 'msg' here
        if (!_messageController.isClosed) {
          _messageController.add(msg); // <--- Use 'msg' here
        }
        final advertisement = Advertisement.fromJson(msg.data); // <--- Use 'msg' here
        NotiService.showDailyNotification(
          title: advertisement.title,
          body: advertisement.content,
          payload: jsonEncode({
            'type': 'advertisement',
            'id': advertisement.advertisementId,
            'entityId': advertisement.entityId,
            'entityType': advertisement.entityType,
            'link': advertisement.link,
          }),
          imageUrl: advertisement.imageUrl, // 传递图片URL
          isAdvertisement: true, // 标记为广告通知
        );
      } else if (msg.isOffline) { 
        print('接收到离线消息，执行注销操作');
        UserService.clearUser();
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (Route<dynamic> route) => false,
        );
      } else if (msg.isAck) {
        final ack = MessageAck.fromJson(msg.data);
        print('收到ACK: ${ack.messageId} - ${ack.status}');
      } else {
        print('收到未知类型的消息: ${msg.messageType}'); // <--- Use 'msg' here
      }
    } catch (e) {
      print('处理消息失败: $e');
    }
  }

  // 保存消息到本地存储
  // 保存消息到本地存储
  Future<void> _saveMessageToLocal(ChatMessage message) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // 使用 _getChatKey 方法确保一致性
      final chatKey = _getChatKey(message.senderId, message.receiverId);
      
      // 获取现有消息
      final savedMessages = prefs.getStringList(chatKey) ?? [];
      
      // 添加新消息
      savedMessages.add(jsonEncode(message.toJson()));
      
      // 保存回本地存储
      await prefs.setStringList(chatKey, savedMessages);
      print('消息已保存到本地存储: $chatKey');
    } catch (e) {
      print('保存消息到本地存储时出错: $e');
    }
  }

  // 获取本地存储的消息
  Future<List<ChatMessage>> getLocalMessages(String senderId, String receiverId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // 使用 _getChatKey 方法确保一致性
      final chatKey = _getChatKey(senderId, receiverId);
      
      final savedMessages = prefs.getStringList(chatKey) ?? [];
      print('从本地存储加载消息: $chatKey, 消息数量: ${savedMessages.length}');
      return savedMessages
          .map((msgJson) => ChatMessage.fromJson(jsonDecode(msgJson)))
          .toList();
    } catch (e) {
      print('获取本地存储消息时出错: $e');
      return [];
    }
  }

  // 生成消息ID
  String _generateMessageId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    String result = '';
    for (int i = 0; i < 8; i++) {
      result += chars[random.nextInt(chars.length)];
    }
    return result + DateTime.now().millisecondsSinceEpoch.toString();
  }

  // 关闭连接
  void dispose() {
    _heartbeatTimer?.cancel();
    _channel?.sink.close(status.goingAway);
    _messageController.close();
    _connectionController.close();
    _isConnected = false;
    _token = null;
    _currentUserId = null;
  }

  // 检查连接状态
  bool get isConnected => _isConnected;

  void _handleNewMessage(Message message) {
    print('收到新消息: ${message.messageType}');
    print('消息数据: ${message.data}');
    // ... 其余代码 ...
  }
}
