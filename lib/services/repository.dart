import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/cupertino.dart';

class SmsRepository {
  static const platform = MethodChannel('com.example.messages/sms');
  final SmsQuery _query = SmsQuery();
  
  // کش برای سرعت بالا
  static final Map<String, String> _nameCache = {};

  String normalize(String phone) {
    String p = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (p.startsWith('+98')) return '0${p.substring(3)}';
    if (p.startsWith('98') && p.length > 10) return '0${p.substring(2)}';
    if (p.startsWith('9') && p.length == 10) return '0$p';
    return p;
  }

  Future<bool> checkAndRequestPermissions() async {
    // لیست دقیق پرمیشن‌ها
    var statuses = await [
      Permission.sms,
      Permission.contacts,
      Permission.phone,
      Permission.microphone,
      Permission.notification,
    ].request();

    bool sms = statuses[Permission.sms]?.isGranted ?? false;
    bool contacts = statuses[Permission.contacts]?.isGranted ?? false;

    if (sms) {
      try {
        bool isDef = await platform.invokeMethod('isDefaultSms');
        if (!isDef) await platform.invokeMethod('requestDefaultSms');
      } catch (e) {
        debugPrint("Default SMS Error: $e");
      }
    }
    return sms && contacts;
  }

  Future<List<ConversationItem>> getConversations() async {
    try {
      final msgs = await _query.querySms(
        kinds: [SmsQueryKind.inbox, SmsQueryKind.sent],
        sort: true,
      );

      Map<String, SmsMessage> threads = {};
      
      for (var m in msgs) {
        if (m.address == null) continue;
        String key = normalize(m.address!);
        
        // فقط جدیدترین پیام هر شخص
        if (!threads.containsKey(key)) {
          threads[key] = m;
        }
      }

      List<ConversationItem> items = [];
      for (var key in threads.keys) {
        var m = threads[key]!;
        String? name = await _getName(key);
        
        items.add(ConversationItem(
          id: m.id.toString(),
          address: m.address!,
          displayId: key,
          name: name,
          snippet: m.body ?? "",
          date: m.date ?? 0,
          isRead: m.read ?? false,
          color: _getColor(key),
        ));
      }
      
      // مرتب‌سازی زمانی
      items.sort((a, b) => b.date.compareTo(a.date));
      return items;
      
    } catch (e) {
      return [];
    }
  }

  Future<List<ChatBubbleModel>> getChatDetails(String address) async {
    final all = await _query.querySms(
      kinds: [SmsQueryKind.inbox, SmsQueryKind.sent],
      sort: true,
    );
    
    String target = normalize(address);
    List<SmsMessage> filtered = all.where((m) => 
      m.address != null && normalize(m.address!) == target
    ).toList();

    return filtered.map((m) => ChatBubbleModel.fromSms(m)).toList();
  }

  Future<void> sendSms(String address, String text) async {
    await platform.invokeMethod('sendSms', {
      'address': address,
      'body': text,
      'subId': null,
    });
  }

  Future<String?> _getName(String phone) async {
    if (_nameCache.containsKey(phone)) return _nameCache[phone];
    try {
      final c = await FlutterContacts.getContact(phone);
      if (c != null) {
        _nameCache[phone] = c.displayName;
        return c.displayName;
      }
    } catch (_) {}
    return null;
  }

  Color _getColor(String key) {
    final colors = [
       CupertinoColors.systemBlue, CupertinoColors.systemIndigo, 
       CupertinoColors.systemPink, CupertinoColors.systemTeal
    ];
    return colors[key.hashCode % colors.length];
  }
}
