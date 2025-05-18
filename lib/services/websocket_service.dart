import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../models/message.dart';
import 'user_service.dart';
import 'noti_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final _messageController = StreamController<Message>.broadcast();
  Stream<Message> get messageStream => _messageController.stream;

  // 连接状态流控制器
  final _connectionController = StreamController<bool>.broadcast();
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
          _handleMessage(message);
        },
        onError: (error) {
          print('WebSocket Error: $error');
          _isConnected = false;
          _connectionController.add(false);
          _reconnect();
        },
        onDone: () {
          print('WebSocket connection closed');
          _isConnected = false;
          _connectionController.add(false);
          _reconnect();
        },
      );

      _isConnected = true;
      _connectionController.add(true);
    } catch (e) {
      print('WebSocket connection error: $e');
      _isConnected = false;
      _connectionController.add(false);
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

  // 处理接收到的消息
  void _handleMessage(dynamic message) {
    try {
      print('收到原始消息: $message');
      
      // 检查消息是否为字符串
      if (message is! String) {
        print('消息不是字符串格式，忽略');
        return;
      }
      
      // 检查消息是否为有效的 JSON
      if (!message.startsWith('{') || !message.endsWith('}')) {
        print('消息不是有效的 JSON 格式，忽略');
        return;
      }
      
      final Map<String, dynamic> data = jsonDecode(message);
      final Message messageObj = Message.fromJson(data);
      
      if (messageObj.isMessage) {
        print("收到消息类型: ${messageObj.messageType}");
        print("消息数据: ${messageObj.data}");
        
        // 验证消息数据格式
        if (!messageObj.data.containsKey('senderId') || 
            !messageObj.data.containsKey('receiverId') ||
            !messageObj.data.containsKey('content')) {
          print('消息数据缺少必要字段，忽略');
          return;
        }
        
        final chatMessage = ChatMessage.fromJson(messageObj.data);
        print("解析后的消息: senderId=${chatMessage.senderId}, receiverId=${chatMessage.receiverId}, currentUserId=$_currentUserId");
        
        if (chatMessage.receiverId == _currentUserId) {
          print("消息接收者匹配，添加到消息流");
          _messageController.add(messageObj);
          
          // 保存消息到本地存储
          _saveMessageToLocal(chatMessage);
          
          // 发送本地通知
          NotiService.showDailyNotification(
            title: '新消息',
            body: chatMessage.content,
            payload: 'open_messages',
          );
        } else {
          print("消息接收者不匹配，忽略消息");
        }
      } else if (messageObj.isAck) {
        print('收到消息确认: ${messageObj.data}');
        _messageController.add(messageObj);
      } else if (messageObj.isAdvertisement) {
        print('收到广告消息: ${messageObj.data}');
        _messageController.add(messageObj);
      } else {
        print('收到未知类型的消息: ${messageObj.messageType}');
      }
    } catch (e) {
      print('处理消息时出错: $e');
      print('原始消息内容: $message');
    }
  }

  // 保存消息到本地存储
  Future<void> _saveMessageToLocal(ChatMessage message) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final chatKey = 'chat_${message.senderId}_${message.receiverId}';
      
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
      final chatKey = 'chat_${senderId}_$receiverId';
      
      final savedMessages = prefs.getStringList(chatKey) ?? [];
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
}
