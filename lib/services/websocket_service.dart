import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:dio/dio.dart';
import 'api_service.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  final _apiService = ApiService();
  WebSocket? _socket;
  String? _currentUserId;
  String? _authToken;
  bool _isConnected = false;
  bool _isReconnecting = false;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  final int _heartbeatInterval = 25000; // 25秒
  final int _reconnectDelay = 1000; // 1秒
  final int _maxRetries = 3;
  int _currentRetries = 0;
  bool _isDisposed = false;

  // 订阅相关的状态
  final Map<String, StreamController<Map<String, dynamic>>> _subscriptions = {};
  final Map<String, List<String>> _topicSubscribers = {};

  // 消息流控制器
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  // 连接状态流控制器
  final _connectionStatusController = StreamController<String>.broadcast();
  Stream<String> get connectionStatus => _connectionStatusController.stream;

  // 在线状态流控制器
  final _onlineStatusController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onlineStatus =>
      _onlineStatusController.stream;

  // 消息发送队列
  final Map<String, Map<String, dynamic>> _pendingMessages = {};

  bool get isConnected => _isConnected;

  String? getCurrentUserId() => _currentUserId;

  // 订阅主题
  Stream<Map<String, dynamic>> subscribe(String topic) {
    if (!_subscriptions.containsKey(topic)) {
      _subscriptions[topic] =
          StreamController<Map<String, dynamic>>.broadcast();
      _topicSubscribers[topic] = [];

      // 如果已连接，发送订阅消息
      if (_isConnected && _socket != null) {
        _sendSubscribeMessage(topic);
      }
    }
    return _subscriptions[topic]!.stream;
  }

  // 取消订阅
  void unsubscribe(String topic) {
    if (_subscriptions.containsKey(topic)) {
      if (_isConnected && _socket != null) {
        _sendUnsubscribeMessage(topic);
      }
      _subscriptions[topic]?.close();
      _subscriptions.remove(topic);
      _topicSubscribers.remove(topic);
    }
  }

  // 发送订阅消息
  void _sendSubscribeMessage(String topic) {
    if (_socket != null && _isConnected) {
      final subscribeMessage = {
        'type': 'subscribe',
        'topic': topic,
        'userId': _currentUserId,
        'timestamp': DateTime.now().toIso8601String(),
      };
      _socket!.add(json.encode(subscribeMessage));
      print('[WebSocket] 发送订阅消息: $topic');
    }
  }

  // 发送取消订阅消息
  void _sendUnsubscribeMessage(String topic) {
    if (_socket != null && _isConnected) {
      final unsubscribeMessage = {
        'type': 'unsubscribe',
        'topic': topic,
        'userId': _currentUserId,
        'timestamp': DateTime.now().toIso8601String(),
      };
      _socket!.add(json.encode(unsubscribeMessage));
      print('[WebSocket] 发送取消订阅消息: $topic');
    }
  }

  String _generateRandomString() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(
      8,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }

  Future<bool> _checkWebSocketAvailability(String userId) async {
    print('userId: $userId');
    try {
      await _apiService.dio.get(
        '/ws/info',
        queryParameters: {'t': userId},
      );
      await Future.delayed(const Duration(milliseconds: 100));
      return true;
    } catch (e) {
      print('[WebSocket] 检查服务可用性失败: $e');
      return false;
    }
  }

  Future<void> connect(String userId, String authToken, String baseUrl) async {
    if (_isDisposed) {
      print('[WebSocket] 服务已销毁，无法连接');
      return;
    }
    if (_isConnected) {
      print('[WebSocket] 已经连接，无需重复连接');
      return;
    }
    if (_isReconnecting) {
      print('[WebSocket] 正在重连中，请稍候...');
      return;
    }

    print('[WebSocket] 开始连接...');
    _currentUserId = userId;
    _authToken = authToken;
    _currentRetries = 0;

    // 首先检查 WebSocket 服务是否可用
    final isAvailable = await _checkWebSocketAvailability(userId);
    if (!isAvailable) {
      print('[WebSocket] 服务不可用');
      _connectionStatusController.add('服务不可用，请稍后重试');
      return;
    }

    _connectionStatusController.add('连接中...');
    await _connectWebSocket();
  }

  Future<void> _connectWebSocket() async {
    if (_isDisposed) return;
    if (_currentRetries >= _maxRetries) {
      _isReconnecting = false;
      print('[WebSocket] 连接失败，已达到最大重试次数');
      _connectionStatusController.add('连接失败，请检查网络后重试');
      return;
    }

    _cleanupExistingConnection();
    _isReconnecting = true;

    final randomString = _generateRandomString();
    final wsUrl =
        'ws://115.190.33.252:8089/api/v1/ws/$_currentUserId/$randomString/websocket';
    print('[WebSocket] 连接地址: $wsUrl');
    print('[WebSocket] 当前重试次数: $_currentRetries');

    try {
      print('[WebSocket] 开始创建 WebSocket 连接...');
      _socket = await WebSocket.connect(
        wsUrl,
        headers: {'Authorization': 'Bearer $_authToken'},
      );

      print('[WebSocket] WebSocket 连接成功');
      _isConnected = true;
      _isReconnecting = false;
      _currentRetries = 0;
      _connectionStatusController.add('已连接');

      // 发送连接成功消息
      final messageId = 'msg_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString()}';
      final connectMessage = {
        'messageId': messageId,
        'senderId': _currentUserId,
        'receiverId': '1', // 这里可以根据需要修改接收者ID
        'content': '你好',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      try {
        final response = await _apiService.dio.post(
          '/user/chat/send',
          data: connectMessage,
          options: Options(
            headers: {
              'Authorization': 'Bearer $_authToken',
              'Accept': 'application/json',
            },
          ),
        );
        print('[WebSocket] 发送连接成功消息响应: ${response.data}');
      } catch (e) {
        print('[WebSocket] 发送连接成功消息失败: $e');
      }

      // 重新订阅所有主题
      _resubscribeAllTopics();

      // 订阅个人消息队列
      _subscribeToPersonalQueue();

      // 设置消息监听
      _socket!.listen(
        (data) {
          print('[WebSocket] 收到消息: $data');
          try {
            final message = json.decode(data);
            _handleMessage(message);
          } catch (e) {
            print('[WebSocket] 消息解析错误: $e');
          }
        },
        onError: (error) {
          print('[WebSocket] 连接错误: $error');
          _handleReconnect();
        },
        onDone: () {
          print('[WebSocket] 连接关闭');
          _isConnected = false;
          _handleReconnect();
        },
      );

      // 启动心跳
      _startHeartbeat();
    } catch (e) {
      print('[WebSocket] 连接失败: $e');
      _handleReconnect();
    }
  }

  // 订阅个人消息队列
  void _subscribeToPersonalQueue() {
    if (_socket != null && _isConnected && _currentUserId != null) {
      final subscribeMessage = {
        'type': 'subscribe',
        'destination': '/user/$_currentUserId/queue/messages',
        'timestamp': DateTime.now().toIso8601String(),
      };
      _socket!.add(json.encode(subscribeMessage));
      print('[WebSocket] 订阅个人消息队列: /user/$_currentUserId/queue/messages');
    }
  }

  void _handleMessage(Map<String, dynamic> message) {
    final type = message['type'];
    switch (type) {
      case 'chat':
        _messageController.add(message);
        // 检查是否有订阅者
        final topic = message['topic'];
        if (topic != null && _subscriptions.containsKey(topic)) {
          _subscriptions[topic]?.add(message);
        }
        break;
      case 'online':
      case 'offline':
        _onlineStatusController.add(message);
        break;
      case 'subscribe_ack':
        print('[WebSocket] 订阅确认: ${message['destination']}');
        break;
      case 'unsubscribe_ack':
        print('[WebSocket] 取消订阅确认: ${message['destination']}');
        break;
      default:
        print('[WebSocket] 未知消息类型: $type');
    }
  }

  void _cleanupExistingConnection() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _socket?.close();
    _socket = null;
  }

  void _handleReconnect() {
    if (_isDisposed) return;
    if (_reconnectTimer != null) {
      _reconnectTimer!.cancel();
      _reconnectTimer = null;
    }

    if (_currentRetries < _maxRetries) {
      _currentRetries++;
      _reconnectTimer = Timer(
        Duration(milliseconds: _reconnectDelay * _currentRetries),
        () {
          if (!_isConnected && !_isDisposed) {
            _connectWebSocket();
          }
        },
      );
    } else {
      _isReconnecting = false;
      _connectionStatusController.add('连接失败，请检查网络后重试');
    }
  }

  void _startHeartbeat() {
    if (_isDisposed) return;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      Duration(milliseconds: _heartbeatInterval),
      (timer) {
        if (_isConnected && _socket != null && !_isDisposed) {
          try {
            _socket!.add(
              json.encode({
                'type': 'heartbeat',
                'timestamp': DateTime.now().toIso8601String(),
              }),
            );
          } catch (e) {
            if (!_isDisposed) {
              _handleReconnect();
            }
          }
        }
      },
    );
  }

  // 发送聊天消息
  Future<void> sendChatMessage({
    required String receiverId,
    required String content,
  }) async {
    if (!_isConnected || _socket == null) {
      throw Exception('WebSocket未连接');
    }

    final messageId =
        'msg_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString()}';
    final message = {
      'messageId': messageId,
      'senderId': _currentUserId,
      'receiverId': receiverId,
      'content': content,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    // 添加到待确认队列
    _addToPendingQueue(messageId, message);

    // 发送消息
    final stompMessage = {
      'type': 'chat',
      'destination': '/app/chat/ack',
      'body': message,
      'headers': {
        'Authorization': 'Bearer $_authToken',
        'message-id': messageId,
        'sender-id': _currentUserId,
      },
    };

    _socket!.add(json.encode(stompMessage));
    print('[WebSocket] 发送消息: $message');
  }

  // 添加到待确认队列
  void _addToPendingQueue(String messageId, Map<String, dynamic> message) {
    _pendingMessages[messageId] = {
      'message': message,
      'retries': 0,
      'timer': Timer(
        const Duration(seconds: 3),
        () => _retryMessage(messageId, message),
      ),
    };
    _savePendingMessages();
  }

  // 保存待确认消息到本地存储
  Future<void> _savePendingMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final messages = _pendingMessages.map(
        (key, value) => MapEntry(key, {
          'message': value['message'],
          'retries': value['retries'],
        }),
      );
      await prefs.setString('pending_messages', json.encode(messages));
    } catch (e) {
      print('[WebSocket] 保存待确认消息失败: $e');
    }
  }

  // 重试发送消息
  void _retryMessage(String messageId, Map<String, dynamic> message) {
    final pending = _pendingMessages[messageId];
    if (pending == null) return;

    if (pending['retries'] < _maxRetries) {
      pending['retries']++;
      print('[WebSocket] 重试消息 $messageId (第 ${pending['retries']} 次)');

      // 指数退避：3s → 6s → 12s
      final timeout = Duration(
        seconds: 3 * pow(2, pending['retries'] - 1).toInt(),
      );
      pending['timer'] = Timer(
        timeout,
        () => _retryMessage(messageId, message),
      );

      // 重新发送消息
      final stompMessage = {
        'type': 'chat',
        'destination': '/app/chat/ack',
        'body': message,
        'headers': {
          'Authorization': 'Bearer $_authToken',
          'message-id': messageId,
          'sender-id': _currentUserId,
        },
      };
      _socket?.add(json.encode(stompMessage));
    } else {
      // 超过最大重试次数
      _pendingMessages.remove(messageId);
      _messageController.add({
        'type': 'error',
        'message': '消息发送失败：服务器无响应 (ID: $messageId)',
      });
    }
  }

  // 处理消息确认
  void _handleAck(Map<String, dynamic> ackData) {
    final messageId = ackData['messageId'];
    final status = ackData['status'];

    if (status == 'FAILED') {
      _messageController.add({
        'type': 'error',
        'message': '消息发送失败 (ID: $messageId): ${ackData['error']}',
      });
      return;
    }

    if (status == 'REPEAT') {
      return; // 重复ACK，不做处理
    }

    // 成功ACK
    final pending = _pendingMessages[messageId];
    if (pending != null) {
      pending['timer']?.cancel();
      _pendingMessages.remove(messageId);
      _savePendingMessages();
    }
  }

  // 恢复未确认的消息
  Future<void> _restorePendingMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('pending_messages');
      if (saved != null) {
        final messages = Map<String, dynamic>.from(json.decode(saved));
        messages.forEach((messageId, data) {
          _pendingMessages[messageId] = {
            'message': data['message'],
            'retries': data['retries'],
            'timer': Timer(
              const Duration(seconds: 3),
              () => _retryMessage(messageId, data['message']),
            ),
          };
        });
      }
    } catch (e) {
      print('[WebSocket] 恢复未确认消息失败: $e');
    }
  }

  Future<void> saveLocalMessage(
    String receiverId,
    Map<String, dynamic> message,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'messages_${_currentUserId}_$receiverId';
      final messages = prefs.getStringList(key) ?? [];
      messages.add(json.encode(message));
      await prefs.setStringList(key, messages);
    } catch (e) {
      print('[WebSocket] 保存本地消息失败: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getLocalMessages(String receiverId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'messages_${_currentUserId}_$receiverId';
      final messages = prefs.getStringList(key) ?? [];
      return messages
          .map((msg) => json.decode(msg) as Map<String, dynamic>)
          .toList();
    } catch (e) {
      print('[WebSocket] 获取本地消息失败: $e');
      return [];
    }
  }

  Future<void> disconnect() async {
    _isDisposed = true;
    _cleanupExistingConnection();
    _isConnected = false;
    _connectionStatusController.add('已断开连接');
  }

  void dispose() {
    _isDisposed = true;
    _cleanupExistingConnection();
    _connectionStatusController.close();
    _messageController.close();
    _onlineStatusController.close();

    // 关闭所有订阅
    for (final controller in _subscriptions.values) {
      controller.close();
    }
    _subscriptions.clear();
    _topicSubscribers.clear();
  }

  // 重新订阅所有主题
  void _resubscribeAllTopics() {
    if (_isConnected && _socket != null) {
      for (final topic in _subscriptions.keys) {
        _sendSubscribeMessage(topic);
      }
    }
  }
}