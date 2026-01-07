import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:telephony/telephony.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/chat_model.dart';

// هندلر بک‌گراند (باید تاپ-لول باشد)
@pragma('vm:entry-point')
void onBackgroundMessage(SmsMessage message) {
  debugPrint("Background SMS: ${message.body}");
}

class SmsService {
  final Telephony telephony = Telephony.instance;

  // کش کردن نام مخاطبین برای سرعت بالا
  final Map<String, String> _contactCache = {};

  // درخواست تمام مجوزها
  Future<bool> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.sms,
      Permission.contacts,
      Permission.phone,
    ].request();

    return statuses[Permission.sms]!.isGranted &&
        statuses[Permission.contacts]!.isGranted;
  }

  // راه‌اندازی لیسنر دریافت پیام
  void initListener(Function(SmsMessage) onMessageReceived) {
    telephony.listenIncomingSms(
      onNewMessage: onMessageReceived,
      onBackgroundMessage: onBackgroundMessage,
    );
  }

  // دریافت نام مخاطب از روی شماره
  Future<String?> getContactName(String address) async {
    // نرمال‌سازی شماره (حذف +98 و 0 و ...) برای مقایسه دقیق‌تر نیاز به منطق پیچیده دارد
    // اما اینجا ساده عمل می‌کنیم.
    if (_contactCache.containsKey(address)) {
      return _contactCache[address];
    }

    // جستجو در مخاطبین
    final contact = await FlutterContacts.getContact(address);
    if (contact != null) {
      _contactCache[address] = contact.displayName;
      return contact.displayName;
    }
    return null;
  }

  // دریافت لیست مکالمات (Inbox)
  Future<List<ConversationItem>> getConversations() async {
    List<SmsMessage> messages = await telephony.getInboxSms(
      columns: [
        SmsColumn.ADDRESS,
        SmsColumn.BODY,
        SmsColumn.DATE,
        SmsColumn.READ,
      ],
      sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
    );

    // گروه‌بندی پیام‌ها بر اساس شماره
    Map<String, SmsMessage> uniqueMsgs = {};
    for (var msg in messages) {
      if (msg.address != null && !uniqueMsgs.containsKey(msg.address)) {
        uniqueMsgs[msg.address!] = msg;
      }
    }

    List<ConversationItem> conversations = [];
    for (var msg in uniqueMsgs.values) {
      String? name = await getContactName(msg.address!);
      conversations.add(
        ConversationItem(
          address: msg.address!,
          name: name,
          message: msg.body ?? "",
          date: msg.date ?? DateTime.now().millisecondsSinceEpoch,
          isRead: msg.read == 1, // در اندروید 1 یعنی خوانده شده
          avatarColor: _generateColor(msg.address!),
        ),
      );
    }
    return conversations;
  }

  // دریافت پیام‌های یک چت خاص
  Future<List<ChatMessage>> getChatMessages(String address) async {
    List<SmsMessage> inbox = await telephony.getInboxSms(
      filter: SmsFilter.where(SmsColumn.ADDRESS).equals(address),
    );
    List<SmsMessage> sent = await telephony.getSentSms(
      filter: SmsFilter.where(SmsColumn.ADDRESS).equals(address),
    );

    List<SmsMessage> all = [...inbox, ...sent];
    // مرتب‌سازی زمانی
    all.sort((a, b) => (a.date ?? 0).compareTo(b.date ?? 0));

    return all
        .map(
          (e) => ChatMessage(
            id: e.id.toString(),
            text: e.body ?? "",
            isMe: e.type == SmsType.MESSAGE_TYPE_SENT,
            date: e.date ?? 0,
          ),
        )
        .toList();
  }

  // ارسال پیام
  Future<void> sendSMS(
    String address,
    String body,
    Function(SendStatus) onStatus,
  ) async {
    await telephony.sendSms(
      to: address,
      message: body,
      statusListener: onStatus,
    );
  }

  // تولید رنگ تصادفی ثابت برای هر شماره
  Color _generateColor(String address) {
    final colors = [
      CupertinoColors.systemIndigo,
      CupertinoColors.systemPink,
      CupertinoColors.systemGreen,
      CupertinoColors.systemTeal,
      CupertinoColors.systemOrange,
      CupertinoColors.systemPurple,
    ];
    return colors[address.length % colors.length];
  }
}
