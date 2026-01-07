import 'package:flutter/cupertino.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';

class ConversationDisplayItem {
  final String originalAddress; // آدرس اصلی برای ارسال پیام
  final String normalizedAddress; // آدرس یکسان شده برای گروه‌بندی
  final String? name;
  final String message;
  final int date;
  bool isRead;
  final Color avatarColor;

  ConversationDisplayItem({
    required this.originalAddress,
    required this.normalizedAddress,
    this.name,
    required this.message,
    required this.date,
    required this.isRead,
    required this.avatarColor,
  });

  String get initials {
    if (name != null && name!.isNotEmpty) {
      if(name!.codeUnitAt(0) > 128) return name![0];
      var parts = name!.split(' ');
      if (parts.length > 1) return (parts[0][0] + parts[1][0]).toUpperCase();
      return name![0].toUpperCase();
    }
    return normalizedAddress.length > 1 ? normalizedAddress.substring(0, 2) : "#";
  }
  
  String get displayName => (name != null && name!.isNotEmpty) ? name! : originalAddress;
}

enum MessageItemType { message, dateDivider }

class ChatMessageDisplay {
  final SmsMessage? smsMessage;
  final MessageItemType type;
  final String? customText;
  
  // وضعیت ارسال (فقط برای نمایش در UI ما)
  bool isSending = false;
  bool isFailed = false;

  ChatMessageDisplay.message(this.smsMessage) 
      : type = MessageItemType.message, customText = null;

  ChatMessageDisplay.divider(String text) 
      : type = MessageItemType.dateDivider, customText = text, smsMessage = null;

  String get id => smsMessage?.id.toString() ?? "";
  String get text => customText ?? smsMessage?.body ?? "";
  int get date => (smsMessage?.date as int?) ?? 0;
  bool get isMe => smsMessage?.kind == SmsMessageKind.sent;
}
