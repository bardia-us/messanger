import 'package:flutter/services.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/cupertino.dart';

class SmsRepository {
  static const platform = MethodChannel('com.example.messages/sms');
  final SmsQuery _query = SmsQuery();
  final Map<String, String> _contactCache = {};

  // --- نرمال‌سازی شماره (حل مشکل 09 و +98) ---
  String normalizePhone(String phone) {
    // حذف تمام کاراکترهای غیر عددی به جز +
    String clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    
    // اگر با +98 شروع میشه، بکنش 0
    if (clean.startsWith('+98')) {
      clean = '0${clean.substring(3)}';
    }
    // اگر با 98 (بدون مثبت) شروع میشه
    else if (clean.startsWith('98')) {
      clean = '0${clean.substring(2)}';
    }
    // اگر مستقیم با 9 شروع میشه (مثلا 912)
    else if (clean.startsWith('9')) {
      clean = '0$clean';
    }
    
    return clean;
  }

  // درخواست دسترسی‌ها + دیفالت اپ
  Future<bool> requestPermissions() async {
    // اول پرمیشن‌های خطرناک
    Map<Permission, PermissionStatus> statuses = await [
      Permission.sms,
      Permission.contacts,
      Permission.phone,
      Permission.microphone, // برای ویس
      Permission.notification, // برای نوتیفیکیشن
    ].request();

    bool essentialGranted = (statuses[Permission.sms]?.isGranted ?? false) &&
                            (statuses[Permission.contacts]?.isGranted ?? false);

    if (essentialGranted) {
      // حالا چک کن ببین دیفالت هستیم یا نه
      bool isDefault = await platform.invokeMethod('isDefaultSms');
      if (!isDefault) {
        try {
          await platform.invokeMethod('requestDefaultSms');
        } catch (e) {
          print("Error requesting default SMS: $e");
        }
      }
      return true;
    }
    return false;
  }

  Future<List<SmsMessage>> getMessages({String? address}) async {
    // اگر آدرس خاصی خواستیم، باید حواسمان به فرمت‌های مختلف باشد
    // اما کتابخانه filter روی آدرس دقیق دارد. پس بهتره همه رو بگیریم و فیلتر کنیم
    // یا اینکه بگذاریم خود کتابخانه کارش را بکند.
    
    List<SmsMessage> messages = await _query.querySms(
      kinds: [SmsQueryKind.inbox, SmsQueryKind.sent],
      address: address, // اگر نال باشد همه را می‌دهد
      sort: true,
    );
    return messages;
  }

  Future<void> sendSms(String address, String body, int? subId) async {
    try {
      await platform.invokeMethod('sendSms', {
        'address': address,
        'body': body,
        'subId': subId,
      });
    } on PlatformException catch (e) {
      print("Failed to send SMS via Native: ${e.message}");
      throw e; // خطا را پرتاب کن تا در UI بفهمیم
    }
  }

  Future<List<Map<String, dynamic>>> getSimCards() async {
    try {
      final List result = await platform.invokeMethod('getSimCards');
      return result.cast<Map<String, dynamic>>();
    } on PlatformException catch (e) {
      print("Failed to get SIM cards: ${e.message}");
      return [];
    }
  }

  Future<String?> getContactName(String address) async {
    String normalizedAddr = normalizePhone(address);
    if (_contactCache.containsKey(normalizedAddr)) return _contactCache[normalizedAddr];

    try {
      // این بخش سنگین است، بهتر است یک بار کش شود
      final contact = await FlutterContacts.getContact(normalizedAddr);
      if (contact != null) {
         _contactCache[normalizedAddr] = contact.displayName;
         return contact.displayName;
      }
    } catch (e) {
      // خطا در گرفتن کانتکت
    }
    return null;
  }

  Color generateColor(String address) {
    final colors = [
      CupertinoColors.systemIndigo, CupertinoColors.systemPink, CupertinoColors.systemGreen,
      CupertinoColors.systemTeal, CupertinoColors.systemOrange, CupertinoColors.systemPurple,
      CupertinoColors.systemBlue, CupertinoColors.systemRed
    ];
    return colors[normalizePhone(address).hashCode % colors.length];
  }
}
