import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/message.dart';
import '../services/websocket_service.dart';

class MessageProvider with ChangeNotifier {
  final WebSocketService _webSocketService = WebSocketService();
  final List<Message> _messages = [];
  String _connectionStatus = '未连接';
  bool _isConnected = false;

  List<Message> get messages => List.unmodifiable(_messages);
  String get connectionStatus => _connectionStatus;
  bool get isConnected => _isConnected;

  MessageProvider() {
    _setupWebSocketListeners();
  }

  void _setupWebSocketListeners() {
    _webSocketService.connectionStatus.listen((status) {
      _connectionStatus = status;
      _isConnected = status.contains('已连接');
      notifyListeners();
    });

    _webSocketService.messages.listen((messageData) {
      final message = Message.fromJson(messageData);
      _addMessage(message);
    });
  }

  void _addMessage(Message message) {
    _messages.add(message);
    notifyListeners();
  }

  Future<void> connect(String userId, String authToken, String baseUrl) async {
    await _webSocketService.connect(userId, authToken, baseUrl);
  }

  Future<void> sendMessage(String receiverId, String content) async {
    if (!_isConnected) {
      throw Exception('WebSocket未连接');
    }

    await _webSocketService.sendMessage(receiverId, content);
  }

  void disconnect() {
    _webSocketService.disconnect();
  }

  @override
  void dispose() {
    _webSocketService.dispose();
    super.dispose();
  }
} 