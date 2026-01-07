import 'package:flutter/cupertino.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';

// مدل برای آیتم‌های لیست اصلی (اینباکس)
class ConversationDisplayItem {
  final String address;
  final String? name;
  final String message;
  final int date;
  bool isRead;
  final Color avatarColor;

  ConversationDisplayItem({
    required this.address,
    this.name,
    required this.message,
    required this.date,
    required this.isRead,
    required this.avatarColor,
  });

  String get initials {
    if (name != null && name!.isNotEmpty) {
      if (name!.codeUnitAt(0) > 128) return name![0];
      var parts = name!.split(' ');
      if (parts.length > 1) return (parts[0][0] + parts[1][0]).toUpperCase();
      return name![0].toUpperCase();
    }
    return address.length > 1 ? address.substring(0, 2) : "#";
  }

  String get displayName =>
      (name != null && name!.isNotEmpty) ? name! : address;
  bool get isNumeric =>
      double.tryParse(address.replaceAll('+', '').replaceAll(' ', '')) != null;
}

// مدل برای نمایش پیام‌ها داخل چت
enum MessageItemType { message, dateDivider }

class ChatMessageDisplay {
  final SmsMessage? smsMessage; // نال‌پذیر برای جداکننده‌ها
  final MessageItemType type;
  final String? customText; // متن برای جداکننده تاریخ

  ChatMessageDisplay.message(this.smsMessage)
    : type = MessageItemType.message,
      customText = null;

  ChatMessageDisplay.divider(String text)
    : type = MessageItemType.dateDivider,
      customText = text,
      smsMessage = null;

  String get id => smsMessage?.id.toString() ?? "";
  String get text => customText ?? smsMessage?.body ?? "";

  // رفع مشکل تایپ date با کست کردن صریح
  int get date => (smsMessage?.date as int?) ?? 0;

  bool get isMe => smsMessage?.kind == SmsMessageKind.sent;

  // استاتوس دلیوری در این نسخه حذف شد چون نیاز به پیاده‌سازی نیتیو پیچیده دارد
  bool get isSent => smsMessage?.kind == SmsMessageKind.sent;
}
