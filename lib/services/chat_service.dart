import 'dart:async';
import 'dart:convert';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';
import 'package:link_sphere/services/user_service.dart';
import 'package:link_sphere/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  StompClient? _stompClient;
  String? _token;
  String? _userId;
  String? _baseUrl;
  bool _isConnected = false;
  Timer? _heartbeatTimer;
  final int _heartbeatInterval = 25000; // 25秒
  final int _reconnectDelay = 1000; // 1秒
  final int _maxRetries = 3;
  final Map<String, _PendingMessage> _pendingMessages = {};

  // 消息回调
  void Function(Map<String, dynamic> message)? onMessage;
  void Function(Map<String, dynamic> ack)? onAck;
  void Function(List<Map<String, dynamic>> history)? onHistory;
  void Function(String status)? onStatus;

  // 初始化连接
  Future<void> connect() async {
    _token = await UserService.getToken();
    final user = await UserService.getUser();
    _userId = user?.id.toString();
    _baseUrl = ApiService().dio.options.baseUrl.replaceFirst('/api/v1', '');
    print('[ChatService] connect: token=$_token, userId=$_userId, baseUrl=$_baseUrl');
    if (_token == null || _userId == null || _baseUrl == null) {
      onStatus?.call('未登录或信息不全');
      print('[ChatService] connect: 未登录或信息不全');
      return;
    }
    _connectStomp();
  }

  void _connectStomp() {
    print('$_baseUrl/ws');
    onStatus?.call('连接中...');
    print('[ChatService] _connectStomp: ws://$_baseUrl/ws');
    _stompClient = StompClient(
      config: StompConfig(
        url: 'ws://$_baseUrl/ws',
        onConnect: _onConnect,
        beforeConnect: () async {
          print('[ChatService] beforeConnect');
          await Future.delayed(const Duration(milliseconds: 200));
        },
        onWebSocketError: (err) {
          print('[ChatService] onWebSocketError: $err');
          onStatus?.call('连接异常: $err');
          _reconnect();
        },
        onStompError: (frame) {
          print('[ChatService] onStompError: ${frame.body}');
          onStatus?.call('STOMP错误: ${frame.body}');
          _reconnect();
        },
        onDisconnect: (frame) {
          print('[ChatService] onDisconnect');
          onStatus?.call('已断开连接');
          _isConnected = false;
          _reconnect();
        },
        stompConnectHeaders: {
          'Authorization': _token!,
        },
        webSocketConnectHeaders: {
          'Authorization': _token!,
        },
        heartbeatOutgoing: Duration(milliseconds: _heartbeatInterval),
        heartbeatIncoming: Duration(milliseconds: _heartbeatInterval),
      ),
    );
    _stompClient!.activate();
  }

  void _onConnect(StompFrame frame) {
    _isConnected = true;
    print('[ChatService] onConnect: 已连接');
    onStatus?.call('已连接');
    // 订阅消息
    _stompClient?.subscribe(
      destination: '/user/$_userId/queue/messages',
      callback: (frame) {
        if (frame.body != null) {
          final msg = json.decode(frame.body!);
          print('[ChatService] 收到消息: $msg');
          onMessage?.call(msg);
        }
      },
      headers: {'Authorization': _token!},
    );
    // 订阅ACK
    _stompClient?.subscribe(
      destination: '/user/$_userId/queue/acks',
      callback: (frame) {
        if (frame.body != null) {
          final ack = json.decode(frame.body!);
          print('[ChatService] 收到ACK: $ack');
          _handleAck(ack);
          onAck?.call(ack);
        }
      },
      headers: {'Authorization': _token!},
    );
    // 订阅在线状态
    _stompClient?.subscribe(
      destination: '/topic/online',
      callback: (frame) { print('[ChatService] 用户上线: ${frame.body}'); },
      headers: {'Authorization': _token!},
    );
    _stompClient?.subscribe(
      destination: '/topic/offline',
      callback: (frame) { print('[ChatService] 用户下线: ${frame.body}'); },
      headers: {'Authorization': _token!},
    );
    // 订阅在线列表
    _stompClient?.subscribe(
      destination: '/user/$_userId/queue/online-list',
      callback: (frame) { print('[ChatService] 在线列表: ${frame.body}'); },
      headers: {'Authorization': _token!},
    );
    // 订阅广告
    _stompClient?.subscribe(
      destination: '/user/$_userId/queue/advertisement',
      callback: (frame) { print('[ChatService] 广告: ${frame.body}'); },
      headers: {'Authorization': _token!},
    );
    // 启动心跳
    _startHeartbeat();
    // 获取历史消息
    fetchHistoryMessages();
  }

  void _reconnect() {
    _isConnected = false;
    print('[ChatService] _reconnect: 尝试重连...');
    _heartbeatTimer?.cancel();
    Future.delayed(Duration(milliseconds: _reconnectDelay), () {
      connect();
    });
  }

  void disconnect() {
    print('[ChatService] disconnect');
    _heartbeatTimer?.cancel();
    _stompClient?.deactivate();
    _isConnected = false;
    onStatus?.call('已断开连接');
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(Duration(milliseconds: _heartbeatInterval), (timer) {
      if (_isConnected && _stompClient != null) {
        try {
          print('[ChatService] 发送心跳');
          _stompClient!.send(
            destination: '/app/heartbeat',
            body: '{}',
            headers: {'Authorization': _token!},
          );
        } catch (e) {
          print('[ChatService] 心跳异常: $e');
          onStatus?.call('心跳异常: $e');
          _reconnect();
        }
      } else {
        print('[ChatService] 心跳失败，尝试重连');
        onStatus?.call('心跳失败，尝试重连');
        _reconnect();
      }
    });
  }

  // 发送消息
  void sendMessage({
    required String receiverId,
    required String content,
  }) {
    if (!_isConnected || _stompClient == null) {
      print('[ChatService] sendMessage: 未连接，无法发送');
      return;
    }
    final messageId = _generateMessageId();
    final message = {
      'messageId': messageId,
      'senderId': _userId,
      'receiverId': receiverId,
      'content': content,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    print('[ChatService] 发送消息: $message');
    _addToPendingQueue(messageId, message);
    _stompClient!.send(
      destination: '/app/chat/ack',
      body: json.encode(message),
      headers: {
        'Authorization': _token!,
        'message-id': messageId,
        'sender-id': _userId!,
      },
    );
  }

  // 历史消息
  Future<void> fetchHistoryMessages() async {
    // 这里建议通过API获取历史消息，onHistory回调传递
    // 伪代码：
    // final data = await ApiService().getHistoryMessages();
    // onHistory?.call(data);
    // 你可以根据实际API调整
  }

  // ACK处理
  void _handleAck(Map<String, dynamic> ack) {
    final messageId = ack['messageId'];
    if (ack['status'] == 'FAILED') {
      _pendingMessages.remove(messageId);
      onStatus?.call('消息发送失败: ${ack['error']}');
      return;
    }
    if (ack['status'] == 'REPEAT') {
      return;
    }
    final pending = _pendingMessages.remove(messageId);
    pending?.timer?.cancel();
  }

  // 待确认队列
  void _addToPendingQueue(String messageId, Map<String, dynamic> message) {
    final pending = _PendingMessage(
      message: message,
      retries: 0,
      timer: Timer(Duration(seconds: 3), () => _retryHandler(messageId)),
    );
    _pendingMessages[messageId] = pending;
  }

  void _retryHandler(String messageId) {
    final pending = _pendingMessages[messageId];
    if (pending == null) return;
    if (pending.retries < _maxRetries) {
      pending.retries++;
      pending.timer = Timer(Duration(seconds: 3 * (1 << (pending.retries - 1))), () => _retryHandler(messageId));
      _stompClient?.send(
        destination: '/app/chat/ack',
        body: json.encode(pending.message),
        headers: {
          'Authorization': _token!,
          'message-id': messageId,
          'sender-id': _userId!,
        },
      );
    } else {
      _pendingMessages.remove(messageId);
      onStatus?.call('消息发送失败: 服务器无响应 (ID: $messageId)');
    }
  }

  String _generateMessageId() {
    return 'msg_ ${DateTime.now().millisecondsSinceEpoch}_${_userId}_${DateTime.now().microsecondsSinceEpoch}';
  }

  // 保存消息到本地（按好友ID）
  Future<void> saveLocalMessage(String friendId, Map<String, dynamic> message) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'chat_history_$friendId';
    final List<String> history = prefs.getStringList(key) ?? [];
    history.add(jsonEncode(message));
    await prefs.setStringList(key, history);
    print('[ChatService] saveLocalMessage: $friendId, $message');
  }

  // 获取本地消息记录（按好友ID）
  Future<List<Map<String, dynamic>>> getLocalMessages(String friendId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'chat_history_$friendId';
    final List<String> history = prefs.getStringList(key) ?? [];
    print('[ChatService] getLocalMessages: $friendId, count=${history.length}');
    return history.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
  }
}

class _PendingMessage {
  final Map<String, dynamic> message;
  int retries;
  Timer? timer;
  _PendingMessage({required this.message, required this.retries, this.timer});
} 