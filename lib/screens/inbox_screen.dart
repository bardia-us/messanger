import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/chat_model.dart';
import '../services/repository.dart';
import '../services/theme_manager.dart';
import 'chat_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> with WidgetsBindingObserver {
  final SmsRepository _repo = SmsRepository();
  List<ConversationDisplayItem> _conversations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initAndLoad();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadConversations();
    }
  }

  Future<void> _initAndLoad() async {
    await _repo.requestPermissions();
    await _loadConversations();
  }

  Future<void> _loadConversations() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final messages = await _repo.getAllMessages();
      
      Map<String, SmsMessage> threads = {};
      
      for (var msg in messages) {
        if (msg.address == null || msg.address!.isEmpty) continue;
        
        String key = _repo.normalizePhone(msg.address!);
        
        if (!threads.containsKey(key)) {
          threads[key] = msg;
        } else {
          // *** FIX: Cast explicit برای رفع ارور Object ***
          int current = (msg.date as int?) ?? 0;
          int saved = (threads[key]!.date as int?) ?? 0;
          
          if (current > saved) {
            threads[key] = msg;
          }
        }
      }

      List<ConversationDisplayItem> result = [];
      for (var key in threads.keys) {
        var msg = threads[key]!;
        String? name = await _repo.getContactName(key);
        
        result.add(ConversationDisplayItem(
          originalAddress: msg.address!,
          normalizedAddress: key,
          name: name,
          message: msg.body ?? "",
          // *** FIX: Cast explicit ***
          date: (msg.date as int?) ?? 0,
          isRead: msg.read ?? false,
          avatarColor: _repo.generateColor(key),
        ));
      }

      result.sort((a, b) => b.date.compareTo(a.date));

      if (mounted) {
        setState(() {
          _conversations = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error in inbox: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final isDark = themeManager.themeMode == ThemeMode.dark;

    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text("Messages"),
            leading: CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Text("Edit"),
              onPressed: () {},
            ),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.square_pencil),
              onPressed: () {
                Navigator.of(context).push(CupertinoPageRoute(
                  builder: (_) => const ChatScreen(address: "", name: "New Message")
                )).then((_) => _loadConversations());
              },
            ),
          ),
          
          if (_isLoading)
            const SliverFillRemaining(child: Center(child: CupertinoActivityIndicator()))
          else if (_conversations.isEmpty)
             SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("No Messages", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    CupertinoButton.filled(
                      child: const Text("Refresh"),
                      onPressed: _initAndLoad,
                    )
                  ],
                ),
              )
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return _buildConversationItem(_conversations[index], isDark);
                },
                childCount: _conversations.length,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConversationItem(ConversationDisplayItem item, bool isDark) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (_) => ChatScreen(address: item.originalAddress, name: item.displayName),
          ),
        );
        _loadConversations();
      },
      child: Container(
        color: isDark ? Colors.black : Colors.white,
        padding: const EdgeInsets.only(left: 16, top: 12, bottom: 12),
        child: Row(
          children: [
            if (!item.isRead)
              Container(
                margin: const EdgeInsets.only(right: 8),
                width: 10, height: 10,
                decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
              ),
            
            CircleAvatar(
              radius: 24,
              backgroundColor: item.avatarColor,
              child: Text(item.initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.only(bottom: 12, right: 16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(item.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black))),
                        Text(_formatDate(item.date), style: const TextStyle(color: Colors.grey, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.message, 
                      maxLines: 2, 
                      overflow: TextOverflow.ellipsis, 
                      style: const TextStyle(color: Colors.grey, fontSize: 15)
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(int millis) {
    if (millis == 0) return "";
    final date = DateTime.fromMillisecondsSinceEpoch(millis);
    final now = DateTime.now();
    if (now.day == date.day) return DateFormat('HH:mm').format(date);
    return DateFormat('MM/dd').format(date);
  }
}
