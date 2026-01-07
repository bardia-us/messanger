import 'package:flutter/services.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/cupertino.dart';

class SmsRepository {
  static const platform = MethodChannel('com.example.messages/sms');
  final SmsQuery _query = SmsQuery();
  final Map<String, String> _contactCache = {};

  Future<bool> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.sms,
      Permission.contacts,
      Permission.phone,
      Permission.notification,
    ].request();

    bool smsGranted = statuses[Permission.sms]?.isGranted ?? false;
    bool contactsGranted = statuses[Permission.contacts]?.isGranted ?? false;
    bool phoneGranted = statuses[Permission.phone]?.isGranted ?? false;

    if (smsGranted && contactsGranted && phoneGranted) {
      try {
        await platform.invokeMethod('requestDefaultSms');
      } catch (e) {
        print("Error requesting default SMS: $e");
      }
      return true;
    }
    return false;
  }

  // اصلاح kinds: استفاده از SmsQueryKind
  Future<List<SmsMessage>> getMessages({String? address}) async {
    return await _query.querySms(
      address: address,
      kinds: [SmsQueryKind.inbox, SmsQueryKind.sent],
      sort: true,
    );
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

  // اصلاح جستجوی مخاطب: حذف پارامتر query که وجود نداشت
  Future<String?> getContactName(String address) async {
    // نرمال‌سازی شماره (حذف +98 یا 0 اول برای مقایسه بهتر)
    String normalize(String phone) {
      return phone
          .replaceAll(' ', '')
          .replaceAll('-', '')
          .replaceAll('+98', '0');
    }

    if (_contactCache.containsKey(address)) return _contactCache[address];

    try {
      // این روش همه کانتکت‌ها را می‌گیرد که سنگین است، اما تنها راه با این پکیج است
      // برای بهینه‌سازی باید این لیست را در شروع برنامه یک بار بگیرید
      List<Contact> contacts = await FlutterContacts.getContacts(
        withProperties: true,
      );

      String target = normalize(address);

      for (var contact in contacts) {
        for (var phone in contact.phones) {
          if (normalize(phone.number) == target || phone.number == address) {
            String name = contact.displayName;
            _contactCache[address] = name;
            return name;
          }
        }
      }
    } catch (e) {
      print("Error fetching contact: $e");
    }
    return null;
  }

  Color generateColor(String address) {
    final colors = [
      CupertinoColors.systemIndigo,
      CupertinoColors.systemPink,
      CupertinoColors.systemGreen,
      CupertinoColors.systemTeal,
      CupertinoColors.systemOrange,
      CupertinoColors.systemPurple,
    ];
    return colors[address.hashCode % colors.length];
  }

  // اصلاح markAsRead: استفاده از متد نیتیو چون SmsQuery این قابلیت را ندارد
  Future<void> markAsRead(String messageId) async {
    try {
      await platform.invokeMethod('markAsRead', {'id': messageId});
    } catch (e) {
      print("Error marking as read: $e");
    }
  }
}
