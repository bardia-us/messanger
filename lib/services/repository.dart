import 'package:flutter/services.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/cupertino.dart';

class SmsRepository {
  static const platform = MethodChannel('com.example.messages/sms');
  final SmsQuery _query = SmsQuery();
  final Map<String, String> _contactCache = {};

  String normalizePhone(String phone) {
    String clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (clean.startsWith('+98')) {
      return '0${clean.substring(3)}';
    } else if (clean.startsWith('98') && clean.length > 10) {
      return '0${clean.substring(2)}';
    } else if (clean.startsWith('9') && clean.length == 10) {
      return '0$clean';
    }
    return clean;
  }

  Future<bool> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.sms,
      Permission.contacts,
      Permission.phone,
      Permission.microphone,
      Permission.camera,
      Permission.notification,
    ].request();

    bool smsGranted = statuses[Permission.sms]?.isGranted ?? false;
    
    if (smsGranted) {
      try {
         bool isDefault = await platform.invokeMethod('isDefaultSms');
         if (!isDefault) {
           await platform.invokeMethod('requestDefaultSms');
         }
      } catch (e) {
        print("Error checking default SMS: $e");
      }
      return true;
    }
    return false;
  }

  // اصلاح شده: حذف count برای دریافت تمام پیام‌ها
  Future<List<SmsMessage>> getAllMessages() async {
    try {
      final messages = await _query.querySms(
        kinds: [SmsQueryKind.inbox, SmsQueryKind.sent],
        // address: null, // خودکار همه را می‌گیرد
        sort: true,
      );
      return messages;
    } catch (e) {
      print("Error fetching all messages: $e");
      return [];
    }
  }

  Future<List<SmsMessage>> getThread(String address) async {
    final all = await getAllMessages();
    final target = normalizePhone(address);
    return all.where((msg) {
      if (msg.address == null) return false;
      return normalizePhone(msg.address!) == target;
    }).toList();
  }

  Future<void> sendSms(String address, String body, int? subId) async {
    try {
      await platform.invokeMethod('sendSms', {
        'address': address,
        'body': body,
        'subId': subId,
      });
    } on PlatformException catch (e) {
      throw e;
    }
  }

  Future<List<Map<String, dynamic>>> getSimCards() async {
    try {
      final List result = await platform.invokeMethod('getSimCards');
      return result.cast<Map<String, dynamic>>();
    } on PlatformException catch (e) {
      return [];
    }
  }

  Future<String?> getContactName(String address) async {
    String normalized = normalizePhone(address);
    if (_contactCache.containsKey(normalized)) return _contactCache[normalized];
    try {
      final contact = await FlutterContacts.getContact(normalized);
      if (contact != null) {
        _contactCache[normalized] = contact.displayName;
        return contact.displayName;
      }
    } catch (e) {}
    return null;
  }

  Color generateColor(String address) {
    final colors = [
      CupertinoColors.systemIndigo, CupertinoColors.systemPink, CupertinoColors.systemGreen,
      CupertinoColors.systemTeal, CupertinoColors.systemOrange, C
