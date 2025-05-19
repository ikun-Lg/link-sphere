class Message {
  final String messageType;
  final Map<String, dynamic> data;

  Message({
    required this.messageType,
    required this.data,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      messageType: json['messageType'],
      data: json['data'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'messageType': messageType,
      'data': data,
    };
  }

  bool get isAdvertisement => messageType == 'advertisement';
  bool get isAck => messageType == 'ack';
  bool get isMessage => messageType == 'message';
  bool get isHeartbeat => messageType == 'heartbeat';
  bool get isOffline => messageType == 'offline';
}

class ChatMessage {
  final String messageId;
  final String content;
  final String senderId;
  final String receiverId;
  final String sendTime;
  final bool read;

  ChatMessage({
    required this.messageId,
    required this.content,
    required this.senderId,
    required this.receiverId,
    required this.sendTime,
    required this.read,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      messageId: json['messageId']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      receiverId: json['receiverId']?.toString() ?? '',
      sendTime: json['sendTime']?.toString() ?? DateTime.now().toIso8601String(),
      read: json['read'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'messageId': messageId,
      'content': content,
      'senderId': senderId,
      'receiverId': receiverId,
      'sendTime': sendTime,
      'read': read,
    };
  }
}

class Advertisement {
  final String advertisementId;
  final String advertisementType;
  final String content;
  final String entityId;
  final String entityType;
  final String imageUrl;
  final String link;
  final String title;

  Advertisement({
    required this.advertisementId,
    required this.advertisementType,
    required this.content,
    required this.entityId,
    required this.entityType,
    required this.imageUrl,
    required this.link,
    required this.title,
  });

  factory Advertisement.fromJson(Map<String, dynamic> json) {
    return Advertisement(
      advertisementId: json['advertisementId']?.toString() ?? '',
      advertisementType: json['advertisementType']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      entityId: json['entityId']?.toString() ?? '',
      entityType: json['entityType']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString() ?? '',
      link: json['link']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
    );
  }
}

class MessageAck {
  final String message;
  final String messageId;
  final String status;

  MessageAck({
    required this.message,
    required this.messageId,
    required this.status,
  });

  factory MessageAck.fromJson(Map<String, dynamic> json) {
    return MessageAck(
      message: json['message']?.toString() ?? '',
      messageId: json['messageId']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
    );
  }
} 