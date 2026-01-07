import 'package:flutter/cupertino.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';

class ConversationItem {
  final String id;
  final String address;
  final String displayId;
  final String? name;
  final String snippet;
  final int date;
  bool isRead;
  final Color color;

  ConversationItem({
    required this.id,
    required this.address,
    required this.displayId,
    this.name,
    required this.snippet,
    required this.date,
    required this.isRead,
    required this.color,
  });

  String get title => (name != null && name!.isNotEmpty) ? name! : address;
  
  String get initials {
    if (name != null && name!.isNotEmpty) {
       var parts = name!.trim().split(' ');
       if (parts.length > 1 && parts[1].isNotEmpty) {
         return (parts[0][0] + parts[1][0]).toUpperCase();
       }
       return name![0].toUpperCase();
    }
    return "?";
  }
}

enum MsgType { text, voice, image }

class ChatBubbleModel {
  final String id;
  final String text;
  final int date;
  final bool isMe;
  final MsgType type;
  final String? audioPath;

  ChatBubbleModel({
    required this.id,
    required this.text,
    required this.date,
    required this.isMe,
    this.type = MsgType.text,
    this.audioPath,
  });

  factory ChatBubbleModel.fromSms(SmsMessage msg) {
    bool me = msg.kind == SmsMessageKind.sent;
    String body = msg.body ?? "";
    
    MsgType type = MsgType.text;
    
    if (body.contains("[Voice Message:")) {
       type = MsgType.voice;
    } else if (body.contains("[Image Sent:") || body.contains("[Photo Shared]")) {
       type = MsgType.image;
    }

    return ChatBubbleModel(
      id: msg.id.toString(),
      text: body,
      date: (msg.date as int?) ?? 0,
      isMe: me,
      type: type,
    );
  }
}
