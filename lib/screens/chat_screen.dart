import 'dart:ui' as ui;
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../models/chat_model.dart';
import '../services/repository.dart';

ui.TextDirection getDirection(String text) {
  return RegExp(r'[\u0600-\u06FF]').hasMatch(text) ? ui.TextDirection.rtl : ui.TextDirection.ltr;
}

class ChatScreen extends StatefulWidget {
  final String address;
  final String name;
  const ChatScreen({super.key, required this.address, required this.name});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  final SmsRepository _repo = SmsRepository();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<ChatMessageDisplay> _messages = [];
  List<Map<String, dynamic>> _simCards = [];
  int? _selectedSubId;
  
  late AnimationController _plusController;
  late Animation<Offset> _plusOffset;
  
  bool _isPlusOpen = false;
  bool _isComposing = false;
  bool _isRecording = false; // وضعیت ضبط صدا

  @override
  void initState() {
    super.initState();
    _plusController = AnimationController(duration: const Duration(milliseconds: 400), vsync: this);
    _plusOffset = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _plusController, curve: Curves.elasticOut));
    
    _loadSims();
    _loadChat();
  }

  void _loadSims() async {
    final sims = await _repo.getSimCards();
    if (sims.isNotEmpty) {
      setState(() {
        _simCards = sims;
        _selectedSubId = sims[0]['id'];
      });
    }
  }

  void _loadChat() async {
    final rawMsgs = await _repo.getMessages();
    // فیلتر کردن دستی چون آدرس ممکن است فرمت‌های مختلف داشته باشد
    final targetNormal = _repo.normalizePhone(widget.address);
    
    final filtered = rawMsgs.where((m) => 
      m.address != null && _repo.normalizePhone(m.address!) == targetNormal
    ).toList();

    if (mounted) {
      setState(() {
        _messages = _processRawMessages(filtered);
      });
       // اسکرول به پایین با کمی تاخیر برای لود شدن لیست
       Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    }
  }

  List<ChatMessageDisplay> _processRawMessages(List<SmsMessage> rawMsgs) {
    List<ChatMessageDisplay> processed = [];
    DateTime? lastMessageDate;
    
    rawMsgs.sort((a, b) => ((a.date as int?) ?? 0).compareTo((b.date as int?) ?? 0));
    
    for (var msg in rawMsgs) {
      int dateMillis = (msg.date as int?) ?? 0;
      DateTime currentMessageDate = DateTime.fromMillisecondsSinceEpoch(dateMillis);
      
      if (lastMessageDate == null || currentMessageDate.difference(lastMessageDate).inHours >= 1) {
        processed.add(ChatMessageDisplay.divider(_formatDateForDivider(currentMessageDate)));
      }
      processed.add(ChatMessageDisplay.message(msg));
      lastMessageDate = currentMessageDate;
    }
    return processed.reversed.toList();
  }

  String _formatDateForDivider(DateTime date) {
    final now = DateTime.now();
    if (now.day == date.day && now.month == date.month && now.year == date.year) return "Today";
    if (now.day - date.day == 1 && now.month == date.month && now.year == date.year) return "Yesterday";
    return DateFormat('MMM d, yyyy').format(date);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  void _sendMessage() async {
    final text = _controller.text;
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    
    _controller.clear();
    setState(() => _isComposing = false);
    
    try {
      await _repo.sendSms(widget.address, text, _selectedSubId);
      
      // آپدیت سریع UI (خوش‌بینانه)
      // توجه: پیام واقعی بعد از چند ثانیه توسط لودر اصلی گرفته می‌شود
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Sending...", style: TextStyle(color: Colors.white)),
        backgroundColor: CupertinoColors.activeBlue,
        duration: Duration(seconds: 1),
      ));
      
      Future.delayed(const Duration(seconds: 3), _loadChat);
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Failed to send: $e"),
        backgroundColor: Colors.red,
      ));
    }
  }

  // --- منطق ضبط صدا ---
  void _startRecording() async {
    if (await Permission.microphone.request().isGranted) {
      HapticFeedback.heavyImpact();
      setState(() => _isRecording = true);
      // اینجا باید منطق ضبط صدا قرار گیرد (فعلا UI)
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Microphone permission needed")));
    }
  }

  void _stopRecording() {
    if (_isRecording) {
      HapticFeedback.lightImpact();
      setState(() => _isRecording = false);
      // اینجا فایل ضبط شده باید ارسال شود
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Voice Recorded (Simulation)")));
    }
  }

  void _togglePlusMenu() {
    HapticFeedback.selectionClick();
    setState(() {
      _isPlusOpen = !_isPlusOpen;
      if (_isPlusOpen) _plusController.forward(); else _plusController.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 12, 
              backgroundColor: Colors.grey, 
              child: Text(widget.name.isNotEmpty ? widget.name[0] : "#", style: const TextStyle(fontSize: 10, color: Colors.white))
            ),
            const SizedBox(height: 2),
            Text(widget.name, style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black)),
          ],
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => launchUrl(Uri(scheme: 'tel', path: widget.address)),
          child: const Icon(CupertinoIcons.phone),
        ),
        previousPageTitle: 'Messages',
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msgDisplay = _messages[index];
                      if (msgDisplay.type == MessageItemType.dateDivider) {
                        return _buildDateDivider(msgDisplay.text);
                      }
                      return _buildBubble(msgDisplay, isDark);
                    },
                  ),
                ),
                
                _buildInputBar(isDark),
              ],
            ),
            
            if (_isPlusOpen) _buildPlusPanel(isDark),
            
            if (_isRecording) _buildRecordingOverlay(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingOverlay(bool isDark) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.mic_fill, color: Colors.red, size: 50),
            SizedBox(height: 10),
            Text("Recording...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildDateDivider(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(text, style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildBubble(ChatMessageDisplay msgDisplay, bool isDark) {
    final isMe = msgDisplay.isMe;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
             const CircleAvatar(radius: 14, backgroundColor: CupertinoColors.systemGrey4, child: Icon(CupertinoIcons.person_fill, size: 16, color: Colors.white)),
             const SizedBox(width: 6),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () {
                HapticFeedback.selectionClick();
                Clipboard.setData(ClipboardData(text: msgDisplay.text));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied"), duration: Duration(milliseconds: 500)));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: isMe 
                    ? const LinearGradient(colors: [Color(0xFF389BFF), Color(0xFF007AFF)], begin: Alignment.topLeft, end: Alignment.bottomRight) 
                    : LinearGradient(colors: isDark ? [const Color(0xFF262628), const Color(0xFF262628)] : [const Color(0xFFE9E9EB), const Color(0xFFE9E9EB)]),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(4),
                    bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      msgDisplay.text,
                      style: TextStyle(fontSize: 17, color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black)),
                      textDirection: getDirection(msgDisplay.text),
                    ),
                    if (isMe) 
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Icon(Icons.done_all, size: 12, color: Colors.white.withOpacity(0.7)),
                      )
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xCC1E1E1E) : const Color(0xCCF9F9F9),
        border: Border(top: BorderSide(color: isDark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA))),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: _togglePlusMenu,
                child: AnimatedRotation(
                  turns: _isPlusOpen ? 0.125 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 5, right: 10),
                    width: 32, height: 32,
                    decoration: const BoxDecoration(color: Color(0xFFC7C7CC), shape: BoxShape.circle),
                    child: const Icon(CupertinoIcons.add, color: CupertinoColors.white, size: 22),
                  ),
                ),
              ),
              Expanded(
                child: CupertinoTextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 5,
                  placeholder: "iMessage",
                  placeholderStyle: const TextStyle(color: CupertinoColors.systemGrey),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2C2E) : CupertinoColors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFC7C7CC), width: 0.5),
                  ),
                  style: TextStyle(fontSize: 17, color: isDark ? Colors.white : Colors.black),
                  onChanged: (text) => setState(() => _isComposing = text.trim().isNotEmpty),
                ),
              ),
              const SizedBox(width: 6),
              if (_isComposing)
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    width: 32, height: 32,
                    decoration: const BoxDecoration(color: CupertinoColors.activeBlue, shape: BoxShape.circle),
                    child: const Icon(CupertinoIcons.arrow_up, color: Colors.white, size: 20),
                  ),
                )
              else
                 GestureDetector(
                   onLongPress: _startRecording,
                   onLongPressUp: _stopRecording,
                   child: const Padding(
                     padding: EdgeInsets.only(bottom: 6, right: 2),
                     child: Icon(CupertinoIcons.mic_fill, color: Color(0xFF8E8E93)), // آیکون ویس
                   ),
                 ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlusPanel(bool isDark) {
    return Positioned(
      bottom: 60,
      left: 10,
      child: SlideTransition(
        position: _plusOffset,
        child: Container(
          width: 250,
          decoration: BoxDecoration(
            color: (isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF2F2F7)).withOpacity(0.98),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20)],
          ),
          child: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               _menuItem(CupertinoIcons.camera_fill, "Camera", Colors.grey, isDark, () {
                 // اینجا کدهای باز کردن دوربین
               }),
               _menuItem(CupertinoIcons.photo_fill, "Photos", CupertinoColors.activeBlue, isDark, () {
                 // اینجا کدهای باز کردن گالری
               }),
               _menuItem(CupertinoIcons.location_solid, "Location", CupertinoColors.systemGreen, isDark, () {
                 // اینجا کدهای لوکیشن
               }),
             ],
          ),
        ),
      ),
    );
  }

  Widget _menuItem(IconData icon, String title, Color color, bool isDark, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$title selected"), duration: const Duration(milliseconds: 500)));
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2)))),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color, shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 18)),
            const SizedBox(width: 12),
            Text(title, style: TextStyle(fontSize: 17, color: isDark ? Colors.white : Colors.black)),
          ],
        ),
      ),
    );
  }
}
