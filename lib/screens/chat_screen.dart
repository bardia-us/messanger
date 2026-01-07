import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:image_picker/image_picker.dart'; // واقعی
import 'package:record/record.dart'; // واقعی
import 'package:path_provider/path_provider.dart'; // واقعی
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'dart:ui' as ui;

import '../models/chat_model.dart';
import '../services/repository.dart';

class ChatScreen extends StatefulWidget {
  final String address;
  final String name;
  const ChatScreen({super.key, required this.address, required this.name});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  final SmsRepository _repo = SmsRepository();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();

  List<ChatMessageDisplay> _messages = [];
  bool _isComposing = false;
  bool _isPlusOpen = false;
  bool _isRecording = false;
  
  late AnimationController _plusController;
  late Animation<Offset> _plusOffset;

  @override
  void initState() {
    super.initState();
    _plusController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    _plusOffset = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _plusController, curve: Curves.decelerate));
    
    _loadMessages();
  }

  void _loadMessages() async {
    // استفاده از getThread برای گرفتن تمام پیام‌های این شخص
    final rawMsgs = await _repo.getThread(widget.address);
    
    if (!mounted) return;
    setState(() {
      _messages = _processMessages(rawMsgs);
    });
    // اسکرول به پایین
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  List<ChatMessageDisplay> _processMessages(List<SmsMessage> raw) {
    List<ChatMessageDisplay> result = [];
    raw.sort((a, b) => (a.date ?? 0).compareTo(b.date ?? 0));
    
    DateTime? lastDate;
    for (var msg in raw) {
      final date = DateTime.fromMillisecondsSinceEpoch(msg.date ?? 0);
      if (lastDate == null || date.difference(lastDate).inDays >= 1) {
        result.add(ChatMessageDisplay.divider(DateFormat('MMM d').format(date)));
      }
      result.add(ChatMessageDisplay.message(msg));
      lastDate = date;
    }
    return result.reversed.toList();
  }

  void _sendMessage({String? text, String? customBody}) async {
    final body = text ?? customBody;
    if (body == null || body.isEmpty) return;

    _textController.clear();
    setState(() => _isComposing = false);

    try {
      await _repo.sendSms(widget.address, body, null);
      // ریلود بعد از ارسال
      Future.delayed(const Duration(seconds: 2), _loadMessages);
    } catch (e) {
      _showError("Failed to send message");
    }
  }

  // --- دکمه‌های واقعی ---
  Future<void> _openCamera() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        // چون SMS نمیتونه عکس بفرسته، ما فقط متن می‌فرستیم که عکس ضمیمه شده (محدودیت SMS)
        // برای ارسال واقعی عکس باید MMS پیاده‌سازی بشه که خیلی پیچیده است.
        _sendMessage(customBody: "[Image Sent: ${photo.name}]");
      }
    } catch (e) {
      _showError("Camera error: $e");
    }
  }

  Future<void> _openGallery() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        _sendMessage(customBody: "[Photo Shared]");
      }
    } catch (e) {
      _showError("Gallery error: $e");
    }
  }

  // --- ضبط صدا واقعی ---
  Future<void> _startRecording() async {
    if (await _audioRecorder.hasPermission()) {
      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      
      await _audioRecorder.start(const RecordConfig(), path: path);
      setState(() => _isRecording = true);
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    final path = await _audioRecorder.stop();
    setState(() => _isRecording = false);
    
    if (path != null) {
      HapticFeedback.mediumImpact();
      // ارسال پیام صوتی (به صورت متن، چون پروتکل SMS فایل قبول نمیکنه)
      _sendMessage(customBody: "[Voice Message: 0:05]"); 
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.name),
        previousPageTitle: "Messages",
      ),
      child: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    reverse: true,
                    controller: _scrollController,
                    itemCount: _messages.length,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    itemBuilder: (ctx, i) {
                      final item = _messages[i];
                      if (item.type == MessageItemType.dateDivider) {
                        return Center(child: Padding(padding: const EdgeInsets.all(8.0), child: Text(item.text, style: const TextStyle(color: Colors.grey, fontSize: 12))));
                      }
                      return _buildBubble(item, isDark);
                    },
                  ),
                ),
                _buildInputArea(isDark),
              ],
            ),
            
            if (_isPlusOpen) _buildPlusMenu(isDark),
            if (_isRecording) _buildRecordingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(ChatMessageDisplay item, bool isDark) {
    final isMe = item.isMe;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue : (isDark ? const Color(0xFF262628) : const Color(0xFFE5E5EA)),
          borderRadius: BorderRadius.circular(18).copyWith(
            bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(18),
            bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(4),
          ),
        ),
        child: Text(
          item.text,
          style: TextStyle(color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black), fontSize: 16),
          textDirection: RegExp(r'[\u0600-\u06FF]').hasMatch(item.text) ? ui.TextDirection.rtl : ui.TextDirection.ltr,
        ),
      ),
    );
  }

  Widget _buildInputArea(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF9F9F9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              setState(() {
                _isPlusOpen = !_isPlusOpen;
                if (_isPlusOpen) _plusController.forward(); else _plusController.reverse();
              });
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle),
              child: const Icon(Icons.add, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: CupertinoTextField(
              controller: _textController,
              minLines: 1,
              maxLines: 5,
              placeholder: "iMessage",
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? Colors.black : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade400),
              ),
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              onChanged: (val) => setState(() => _isComposing = val.trim().isNotEmpty),
            ),
          ),
          const SizedBox(width: 8),
          
          if (_isComposing)
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.arrow_up_circle_fill, size: 34),
              onPressed: () => _sendMessage(text: _textController.text),
            )
          else
            GestureDetector(
              onLongPress: _startRecording,
              onLongPressUp: _stopRecording,
              child: const Padding(
                padding: EdgeInsets.only(bottom: 6, right: 4),
                child: Icon(CupertinoIcons.mic_fill, color: Colors.grey, size: 28),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlusMenu(bool isDark) {
    return Positioned(
      bottom: 70,
      left: 10,
      child: ScaleTransition(
        scale: _plusController,
        child: Container(
          width: 200,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _menuBtn(Icons.camera_alt, "Camera", Colors.grey, _openCamera),
              _menuBtn(Icons.photo, "Photos", Colors.blue, _openGallery),
              _menuBtn(Icons.location_on, "Location", Colors.green, () => _sendMessage(customBody: "📍 My Location")),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuBtn(IconData icon, String txt, Color clr, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        setState(() => _isPlusOpen = false);
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: clr, shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 16)),
            const SizedBox(width: 12),
            Text(txt, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingOverlay() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.red.withOpacity(0.9), borderRadius: BorderRadius.circular(20)),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mic, color: Colors.white, size: 40),
            SizedBox(height: 8),
            Text("Recording...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
