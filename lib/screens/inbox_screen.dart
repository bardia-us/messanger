import 'dart:ui';
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
  List<ConversationDisplayItem> _filteredConversations = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

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

  // اگر کاربر رفت بیرون و پرمیشن داد و برگشت، لیست رفرش بشه
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadConversations();
    }
  }

  Future<void> _initAndLoad() async {
    // درخواست مجوز و دیفالت شدن
    await _repo.requestPermissions();
    await _loadConversations();
  }

  Future<void> _loadConversations() async {
    setState(() => _isLoading = true);
    
    try {
      final msgs = await _repo.getMessages();
      
      // استفاده از Map برای گروه‌بندی بر اساس شماره نرمال شده
      final Map<String, SmsMessage> grouped = {};
      
      for (var msg in msgs) {
        if (msg.address == null) continue;
        
        String normalized = _repo.normalizePhone(msg.address!);
        
        if (!grouped.containsKey(normalized)) {
          grouped[normalized] = msg;
        } else {
          // اگر این پیام جدیدتر بود، جایگزین کن
          int current = (msg.date as int?) ?? 0;
          int saved = (grouped[normalized]!.date as int?) ?? 0;
          if (current > saved) {
            grouped[normalized] = msg;
          }
        }
      }

      List<ConversationDisplayItem> loaded = [];
      for (var key in grouped.keys) {
        var msg = grouped[key]!;
        String? name = await _repo.getContactName(key); // جستجو با شماره نرمال
        
        loaded.add(ConversationDisplayItem(
          originalAddress: msg.address!, // آدرس واقعی (شاید +98 باشه)
          normalizedAddress: key, // آدرس نرمال (09...)
          name: name,
          message: msg.body ?? "",
          date: (msg.date as int?) ?? 0,
          isRead: msg.read ?? false,
          avatarColor: _repo.generateColor(key),
        ));
      }

      // مرتب سازی زمانی (جدیدترین بالا)
      loaded.sort((a, b) => b.date.compareTo(a.date));

      if (mounted) {
        setState(() {
          _conversations = loaded;
          _filteredConversations = _searchController.text.isEmpty 
              ? loaded 
              : _filterList(loaded, _searchController.text);
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading inbox: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<ConversationDisplayItem> _filterList(List<ConversationDisplayItem> list, String query) {
    return list.where((conv) {
      return conv.displayName.toLowerCase().contains(query.toLowerCase()) || 
             conv.normalizedAddress.contains(query);
    }).toList();
  }

  void _onSearch(String query) {
    setState(() {
      _filteredConversations = _filterList(_conversations, query);
    });
  }

  void _showComposeDialog() {
    showCupertinoDialog(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return CupertinoAlertDialog(
          title: const Text("New Message"),
          content: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: CupertinoTextField(
              controller: controller,
              placeholder: "0912...",
              keyboardType: TextInputType.phone,
              autofocus: true,
            ),
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text("Cancel"),
              onPressed: () => Navigator.pop(ctx),
            ),
            CupertinoDialogAction(
              child: const Text("Next"),
              onPressed: () {
                Navigator.pop(ctx);
                if (controller.text.isNotEmpty) {
                  Navigator.push(context, CupertinoPageRoute(
                    builder: (_) => ChatScreen(
                      address: controller.text, 
                      name: controller.text
                    )
                  )).then((_) => _loadConversations());
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final isDark = themeManager.themeMode == ThemeMode.dark;

    return CupertinoPageScaffold(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text("Messages"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: Icon(isDark ? CupertinoIcons.sun_max_fill : CupertinoIcons.moon_fill),
                  onPressed: themeManager.toggleTheme,
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _showComposeDialog,
                  child: const Icon(CupertinoIcons.square_pencil),
                ),
              ],
            ),
          ),
          
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: CupertinoSearchTextField(
                controller: _searchController,
                onChanged: _onSearch,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
            ),
          ),
          
          CupertinoSliverRefreshControl(
            onRefresh: _loadConversations,
          ),

          if (_isLoading)
            const SliverFillRemaining(child: Center(child: CupertinoActivityIndicator()))
          else if (_filteredConversations.isEmpty)
            const SliverFillRemaining(child: Center(child: Text("No messages", style: TextStyle(color: CupertinoColors.systemGrey))))
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final conv = _filteredConversations[index];
                  return _buildItem(conv, isDark);
                },
                childCount: _filteredConversations.length,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItem(ConversationDisplayItem conv, bool isDark) {
    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push(
          CupertinoPageRoute(builder: (context) => ChatScreen(address: conv.originalAddress, name: conv.displayName)),
        );
        _loadConversations();
      },
      child: Container(
        color: isDark ? const Color(0xFF000000) : CupertinoColors.white,
        padding: const EdgeInsets.only(left: 16, top: 10, bottom: 10),
        child: Row(
          children: [
            if (!conv.isRead)
              Container(
                margin: const EdgeInsets.only(right: 8),
                width: 10, height: 10,
                decoration: const BoxDecoration(color: CupertinoColors.activeBlue, shape: BoxShape.circle),
              ),
            
            CircleAvatar(
              radius: 26,
              backgroundColor: conv.avatarColor,
              child: Text(conv.initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            
            const SizedBox(width: 12),
            
            Expanded(
              child: Container(
                padding: const EdgeInsets.only(right: 16, bottom: 12, top: 2),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA), width: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            conv.displayName, 
                            maxLines: 1, 
                            overflow: TextOverflow.ellipsis, 
                            style: TextStyle(
                              fontWeight: conv.isRead ? FontWeight.w400 : FontWeight.w700, 
                              fontSize: 17, 
                              color: isDark ? Colors.white : Colors.black
                            )
                          ),
                        ),
                        Text(
                          _formatDateShort(conv.date),
                          style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      conv.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? Colors.grey : CupertinoColors.systemGrey, 
                        fontSize: 15, 
                        height: 1.3,
                        fontWeight: conv.isRead ? FontWeight.normal : FontWeight.w500
                      ),
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

  String _formatDateShort(int millis) {
    final date = DateTime.fromMillisecondsSinceEpoch(millis);
    final now = DateTime.now();
    if (now.day == date.day) return DateFormat('HH:mm').format(date);
    if (now.difference(date).inDays < 7) return DateFormat('EEEE').format(date);
    return DateFormat('yy/MM/dd').format(date);
  }
}
