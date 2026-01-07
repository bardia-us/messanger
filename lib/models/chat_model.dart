import 'package:flutter/cupertino.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';

class ConversationItem {
  final String id;
  final String address;    // شماره واقعی
  final String displayId;  // شماره نرمال شده (برای گروه‌بندی)
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

enum MsgType { text, voice, image, date }

class ChatBubbleModel {
  final String id;
  final String text;
  final int date;
  final bool isMe;
  final MsgType type;
  final String? audioPath; // مسیر فایل صوتی (اگر ویس باشد)

  ChatBubbleModel({
    required this.id,
    required this.text,
    required this.date,
    required this.isMe,
    this.type = MsgType.text,
    this.audioPath,
  });

  // فکتوری برای تبدیل SMS معمولی به مدل چت
  factory ChatBubbleModel.fromSms(SmsMessage msg) {
    bool me = msg.kind == SmsMessageKind.sent;
    String body = msg.body ?? "";
    
    // تشخیص نوع پیام از روی متن (چون SMS دیتا ندارد)
    MsgType type = MsgType.text;
    String? path;

    if (body.startsWith("[Voice:")) {
       type = MsgType.voice;
       // در سناریوی واقعی باید فایل را دانلود کنید، اینجا فقط نشانگر است
    } else if (body.startsWith("[Image:")) {
       type = MsgType.image;
    }

    return ChatBubbleModel(
      id: msg.id.toString(),
      text: body,
      date: msg.date ?? 0,
      isMe: me,
      type: type,
      audioPath: path,
    );
  }
}
