import 'dart:async';
import 'dart:convert';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  StompClient? _stompClient;
  String? _currentUserId;
  String? _authToken;
  String? _baseUrl;
  bool _isConnected = false;
  bool _isReconnecting = false;
  Timer? _heartbeatTimer;
  final int _heartbeatInterval = 25000; // 25秒
  final int _reconnectDelay = 1000; // 1秒
  final int _maxRetries = 3;
  int _currentRetries = 0;
  final Map<String, _PendingMessage> _pendingMessages = {};

  // 连接状态流控制器
  final _connectionStatusController = StreamController<String>.broadcast();
  Stream<String> get connectionStatus => _connectionStatusController.stream;

  // 消息流控制器
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  // 在线状态流控制器
  final _onlineStatusController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onlineStatus => _onlineStatusController.stream;

  // 历史消息流控制器
  final _historyController = StreamController<List<Map<String, dynamic>>>.broadcast();
  Stream<List<Map<String, dynamic>>> get history => _historyController.stream;

  bool get isConnected => _isConnected;

  String? getCurrentUserId() => _currentUserId;

  Future<void> connect(String userId, String authToken, String baseUrl) async {
    if (_isConnected) {
      print('[WebSocketService] 已经连接，无需重复连接');
      return;
    }

    if (_isReconnecting) {
      print('[WebSocketService] 正在重连中，请稍候...');
      return;
    }

    _currentUserId = userId;
    _authToken = authToken;
    _baseUrl = baseUrl;
    _currentRetries = 0;

    try {
      _connectionStatusController.add('连接中...');
      _connectStomp();
    } catch (e) {
      print('[WebSocketService] 连接异常: $e');
      _connectionStatusController.add('连接异常');
    }
  }

  void _connectStomp() {
    if (_currentRetries >= _maxRetries) {
      _isReconnecting = false;
      _connectionStatusController.add('连接失败，请检查网络后重试');
      return;
    }

    _isReconnecting = true;
    final wsUrl = '${_baseUrl!
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://')}/ws';

    if (_currentRetries == 0) {
      print('[WebSocketService] 连接WebSocket: $wsUrl');
    }

    _stompClient = StompClient(
      config: StompConfig(
        url: wsUrl,
        onConnect: _onConnect,
        beforeConnect: () async {
          await Future.delayed(const Duration(milliseconds: 200));
        },
        onWebSocketError: (dynamic error) {
          print('[WebSocketService] WebSocket错误: $error');
          _handleReconnect();
        },
        onStompError: (StompFrame frame) {
          print('[WebSocketService] STOMP错误: ${frame.body}');
          _handleReconnect();
        },
        onDisconnect: (StompFrame frame) {
          print('[WebSocketService] 连接断开');
          _isConnected = false;
          _handleReconnect();
        },
        stompConnectHeaders: {
          'Authorization': 'Bearer $_authToken',
        },
        webSocketConnectHeaders: {
          'Authorization': 'Bearer $_authToken',
        },
        heartbeatOutgoing: Duration(milliseconds: _heartbeatInterval),
        heartbeatIncoming: Duration(milliseconds: _heartbeatInterval),
      ),
    );

    _stompClient?.activate();
  }

  void _handleReconnect() {
    if (_currentRetries < _maxRetries) {
      _currentRetries++;
      if (_currentRetries == 1) {
        _connectionStatusController.add('正在重连 ($_currentRetries/$_maxRetries)...');
      } else {
        _connectionStatusController.add('重连中...');
      }
      Future.delayed(Duration(milliseconds: _reconnectDelay * _currentRetries), () {
        _connectStomp();
      });
    } else {
      _isReconnecting = false;
      _connectionStatusController.add('连接失败，请检查网络后重试');
    }
  }

  void _onConnect(StompFrame frame) {
    _isConnected = true;
    _isReconnecting = false;
    _currentRetries = 0;
    _connectionStatusController.add('已连接（用户ID: $_currentUserId）');

    // 订阅个人消息队列
    _stompClient?.subscribe(
      destination: '/user/$_currentUserId/queue/messages',
      callback: (StompFrame frame) {
        if (frame.body != null) {
          final message = json.decode(frame.body!);
          _messageController.add(message);
          // 保存消息到本地
          saveLocalMessage(message['receiverId'], message);
        }
      },
      headers: {'Authorization': 'Bearer $_authToken'},
    );

    // 订阅 ACK 队列
    _stompClient?.subscribe(
      destination: '/user/$_currentUserId/queue/acks',
      callback: (StompFrame frame) {
        if (frame.body != null) {
          final ackData = json.decode(frame.body!);
          _handleAck(ackData);
        }
      },
      headers: {'Authorization': 'Bearer $_authToken'},
    );

    // 订阅在线状态
    _stompClient?.subscribe(
      destination: '/topic/online',
      callback: (StompFrame frame) {
        if (frame.body != null) {
          _onlineStatusController.add({
            'type': 'online',
            'data': json.decode(frame.body!),
          });
        }
      },
      headers: {'Authorization': 'Bearer $_authToken'},
    );

    _stompClient?.subscribe(
      destination: '/topic/offline',
      callback: (StompFrame frame) {
        if (frame.body != null) {
          _onlineStatusController.add({
            'type': 'offline',
            'data': json.decode(frame.body!),
          });
        }
      },
      headers: {'Authorization': 'Bearer $_authToken'},
    );

    // 订阅在线列表
    _stompClient?.subscribe(
      destination: '/user/$_currentUserId/queue/online-list',
      callback: (StompFrame frame) {
        if (frame.body != null) {
          print('[WebSocketService] 在线列表: ${frame.body}');
        }
      },
      headers: {'Authorization': 'Bearer $_authToken'},
    );

    // 启动心跳
    _startHeartbeat();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(Duration(milliseconds: _heartbeatInterval), (timer) {
      if (_isConnected && _stompClient != null) {
        try {
          _stompClient!.send(
            destination: '/app/heartbeat',
            body: '{}',
            headers: {'Authorization': 'Bearer $_authToken'},
          );
        } catch (e) {
          print('[WebSocketService] 心跳异常: $e');
          _handleReconnect();
        }
      } else {
        print('[WebSocketService] 心跳失败，尝试重连');
        _handleReconnect();
      }
    });
  }

  void _handleAck(Map<String, dynamic> ackData) {
    final messageId = ackData['messageId'];
    if (ackData['status'] == 'FAILED') {
      print('[WebSocketService] 消息发送失败 (ID: $messageId): ${ackData['error']}');
      _pendingMessages.remove(messageId);
      return;
    }

    if (ackData['status'] == 'REPEAT') {
      return;
    }

    final pending = _pendingMessages.remove(messageId);
    pending?.timer.cancel();
  }

  Future<void> sendMessage(String receiverId, String content) async {
    if (!_isConnected) {
      throw Exception('WebSocket未连接');
    }

    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    final message = {
      'messageId': messageId,
      'senderId': _currentUserId,
      'receiverId': receiverId,
      'content': content,
      'timestamp': DateTime.now().toIso8601String(),
    };

    try {
      _stompClient!.send(
        destination: '/app/chat',
        body: json.encode(message),
        headers: {'Authorization': 'Bearer $_authToken'},
      );

      // 保存消息到本地
      await saveLocalMessage(receiverId, message);

      // 添加到待确认消息列表
      _pendingMessages[messageId] = _PendingMessage(
        message: message,
        timestamp: DateTime.now(),
        timer: Timer(const Duration(seconds: 5), () {
          print('[WebSocketService] 消息发送超时 (ID: $messageId)');
          _pendingMessages.remove(messageId);
        }),
      );
    } catch (e) {
      print('[WebSocketService] 发送消息失败: $e');
      throw Exception('发送消息失败: $e');
    }
  }

  Future<void> saveLocalMessage(String receiverId, Map<String, dynamic> message) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'messages_${_currentUserId}_$receiverId';
      final messages = prefs.getStringList(key) ?? [];
      messages.add(json.encode(message));
      await prefs.setStringList(key, messages);
    } catch (e) {
      print('[WebSocketService] 保存本地消息失败: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getLocalMessages(String receiverId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'messages_${_currentUserId}_$receiverId';
      final messages = prefs.getStringList(key) ?? [];
      return messages.map((msg) => json.decode(msg) as Map<String, dynamic>).toList();
    } catch (e) {
      print('[WebSocketService] 获取本地消息失败: $e');
      return [];
    }
  }

  Future<void> disconnect() async {
    _heartbeatTimer?.cancel();
    _stompClient?.deactivate();
    _isConnected = false;
    _connectionStatusController.add('已断开连接');
  }

  void dispose() {
    disconnect();
    _connectionStatusController.close();
    _messageController.close();
    _onlineStatusController.close();
    _historyController.close();
  }
}

class _PendingMessage {
  final Map<String, dynamic> message;
  final DateTime timestamp;
  final Timer timer;

  _PendingMessage({
    required this.message,
    required this.timestamp,
    required this.timer,
  });
} 