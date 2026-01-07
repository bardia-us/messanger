import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart'; // نسخه 5
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart';

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
  
  // در نسخه 5 نام کلاس AudioRecorder است
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  List<ChatBubbleModel> _messages = [];
  bool _isComposing = false;
  bool _showPlusMenu = false;
  bool _isRecording = false;
  
  late AnimationController _animController;
  late Animation<double> _rotationAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(duration: const Duration(milliseconds: 200), vsync: this);
    _rotationAnim = Tween<double>(begin: 0, end: 0.125).animate(CurvedAnimation(parent: _animController, curve: Curves.easeInOut));
    
    _loadMessages();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _animController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final msgs = await _repo.getChatDetails(widget.address);
    if (!mounted) return;
    setState(() {
      _messages = msgs.reversed.toList();
    });
  }

  void _sendMessage({String? text}) async {
    final body = text ?? _textController.text;
    if (body.trim().isEmpty) return;

    _textController.clear();
    setState(() => _isComposing = false);

    try {
      await _repo.sendSms(widget.address, body);
      
      setState(() {
        _messages.insert(0, ChatBubbleModel(
          id: "temp",
          text: body,
          date: DateTime.now().millisecondsSinceEpoch,
          isMe: true,
        ));
      });
      
      Future.delayed(const Duration(seconds: 2), _loadMessages);
    } catch (e) {
      // Error handling
    }
  }

  // --- Voice Logic (نسخه 5) ---
  Future<void> _startRecording() async {
    if (await _audioRecorder.hasPermission()) {
      Vibration.vibrate(duration: 50);
      
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      
      // سینتکس نسخه 5:
      await _audioRecorder.start(const RecordConfig(), path: path);
      setState(() => _isRecording = true);
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    
    final path = await _audioRecorder.stop();
    setState(() => _isRecording = false);
    Vibration.vibrate(duration: 50);
    
    if (path != null) {
      _sendMessage(text: "[Voice Message: ${path.split('/').last}]");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;

    return CupertinoPageScaffold(
      backgroundColor: bgColor,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: bgColor.withOpacity(0.9),
        border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2))),
        middle: Column(
          children: [
            const SizedBox(height: 8),
            CircleAvatar(radius: 12, backgroundColor: Colors.grey, child: Text(widget.name.isNotEmpty ? widget.name[0] : "?", style: const TextStyle(fontSize: 10, color: Colors.white))),
            Text(widget.name, style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black)),
          ],
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.phone),
          onPressed: () => launchUrl(Uri.parse("tel:${widget.address}")),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                reverse: true,
                controller: _scrollController,
                itemCount: _messages.length,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                itemBuilder: (ctx, i) => _buildBubble(_messages[i], isDark),
              ),
            ),
            
            _buildInputBar(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(ChatBubbleModel item, bool isDark) {
    final isMe = item.isMe;
    final bubbleColor = isMe 
        ? const Color(0xFF007AFF) 
        : (isDark ? const Color(0xFF262628) : const Color(0xFFE9E9EB));

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(18).copyWith(
             bottomRight: isMe ? const Radius.circular(2) : const Radius.circular(18),
             bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(2),
          ),
        ),
        child: Text(
          item.text,
          style: TextStyle(
            color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black),
            fontSize: 16.5,
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF0F0F0),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  _showPlusMenu = !_showPlusMenu;
                  _showPlusMenu ? _animController.forward() : _animController.reverse();
                });
              },
              child: RotationTransition(
                turns: _rotationAnim,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle),
                  child: const Icon(Icons.add, color: Colors.white, size: 20),
                ),
              ),
            ),
            
            const SizedBox(width: 10),
            
            Expanded(
              child: CupertinoTextField(
                controller: _textController,
                minLines: 1,
                maxLines: 5,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                placeholder: "iMessage",
                placeholderStyle: const TextStyle(color: Colors.grey),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                ),
                style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 17),
                onChanged: (v) => setState(() => _isComposing = v.isNotEmpty),
              ),
            ),
            
            const SizedBox(width: 10),
            
            if (_isComposing)
               GestureDetector(
                 onTap: () => _sendMessage(),
                 child: Container(
                   margin: const EdgeInsets.only(bottom: 5),
                   padding: const EdgeInsets.all(6),
                   decoration: const BoxDecoration(color: Color(0xFF007AFF), shape: BoxShape.circle),
                   child: const Icon(CupertinoIcons.arrow_up, color: Colors.white, size: 20),
                 ),
               )
            else
               GestureDetector(
                 onLongPress: _startRecording,
                 onLongPressUp: _stopRecording,
                 child: Container(
                   margin: const EdgeInsets.only(bottom: 6),
                   child: _isRecording 
                      ? const Icon(CupertinoIcons.mic_fill, color: Colors.red, size: 28) 
                      : const Icon(CupertinoIcons.mic_fill, color: Colors.grey, size: 28),
                 ),
               ),
          ],
        ),
      ),
    );
  }
}
