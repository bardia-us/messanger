import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:image_picker/image_picker.dart';
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
  
  List<ChatMessageDisplay> _messages = [];
  bool _isComposing = false;
  bool _isPlusOpen = false;
  
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

  @override
  void dispose() {
    _plusController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _loadMessages() async {
    final rawMsgs = await _repo.getThread(widget.address);
    if (!mounted) return;
    setState(() {
      _messages = _processMessages(rawMsgs);
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    });
  }

  List<ChatMessageDisplay> _processMessages(List<SmsMessage> raw) {
    List<ChatMessageDisplay> result = [];
    raw.sort((a, b) => ((a.date as int?) ?? 0).compareTo((b.date as int?) ?? 0));
    
    DateTime? lastDate;
    for (var msg in raw) {
      final date = DateTime.fromMillisecondsSinceEpoch((msg.date as int?) ?? 0);
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
      Future.delayed(const Duration(seconds: 2), _loadMessages);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed"), backgroundColor: Colors.red));
    }
  }

  Future<void> _openCamera() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo != null) _sendMessage(customBody: "[Image Sent: ${photo.name}]");
    } catch (e) { print(e); }
  }

  Future<void> _openGallery() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) _sendMessage(customBody: "[Photo Shared]");
    } catch (e) { print(e); }
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
          
          // دکمه ارسال همیشه نمایش داده می‌شود (میکروفون حذف شد)
          CupertinoButton(
            padding: EdgeInsets.zero,
            child: const Icon(CupertinoIcons.arrow_up_circle_fill, size: 34),
            onPressed: _isComposing ? () => _sendMessage(text: _textController.text) : null,
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
}
