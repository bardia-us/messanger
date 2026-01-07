import 'package:flutter/services.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/cupertino.dart';

class SmsRepository {
  static const platform = MethodChannel('com.example.messages/sms');
  final SmsQuery _query = SmsQuery();
  final Map<String, String> _contactCache = {};

  // نرمال‌سازی شماره تلفن برای یکی کردن +98 و 09
  String normalizePhone(String phone) {
    String clean = phone.replaceAll(RegExp(r'[^\d+]'), ''); // حذف فاصله و خط تیره
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
    // درخواست همه دسترسی‌های لازم برای دوربین، میکروفون و اس‌مس
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
      // درخواست دیفالت شدن
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

  // گرفتن تمام پیام‌ها بدون فیلتر آدرس (برای پر شدن اینباکس)
  Future<List<SmsMessage>> getAllMessages() async {
    try {
      final messages = await _query.querySms(
        kinds: [SmsQueryKind.inbox, SmsQueryKind.sent],
        address: null, // نال یعنی همه پیام‌ها رو بده
        count: -1, // -1 یعنی محدودیت تعداد نداشته باش
        sort: true,
      );
      return messages;
    } catch (e) {
      print("Error fetching all messages: $e");
      return [];
    }
  }

  // گرفتن پیام‌های یک شخص خاص
  Future<List<SmsMessage>> getThread(String address) async {
    final all = await getAllMessages();
    final target = normalizePhone(address);
    // فیلتر دستی قدرتمند
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
      print("Native Send Error: ${e.message}");
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
      // تلاش برای پیدا کردن نام با فرمت‌های مختلف
      final contact = await FlutterContacts.getContact(normalized);
      if (contact != null) {
        _contactCache[normalized] = contact.displayName;
        return contact.displayName;
      }
    } catch (e) {
      // ignore
    }
    return null; // اگر پیدا نشد نال برگردون تا خود شماره نمایش داده بشه
  }

  Color generateColor(String address) {
    final colors = [
      CupertinoColors.systemIndigo, CupertinoColors.systemPink, CupertinoColors.systemGreen,
      CupertinoColors.systemTeal, CupertinoColors.systemOrange, CupertinoColors.systemPurple,
      const Color(0xFF007AFF), const Color(0xFFFF3B30)
    ];
    return colors[address.hashCode % colors.length];
  }
}
