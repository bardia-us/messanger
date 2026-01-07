import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/chat_model.dart';
import '../services/repository.dart';
import '../services/theme_manager.dart'; // مطمئن شو فایل theme_manager.dart وجود دارد
import 'chat_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final SmsRepository _repo = SmsRepository();
  List<ConversationDisplayItem> _conversations = [];
  List<ConversationDisplayItem> _filteredConversations = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    bool hasPermissions = await _repo.requestPermissions();
    if (hasPermissions) {
      await _loadConversations();
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadConversations() async {
    final msgs = await _repo.getMessages();

    final Map<String, SmsMessage> uniqueMsgs = {};
    for (var msg in msgs) {
      if (msg.address != null) {
        if (!uniqueMsgs.containsKey(msg.address)) {
          uniqueMsgs[msg.address!] = msg;
        } else {
          // اصلاح مقایسه تاریخ با کست کردن به int
          int currentMsgDate = (msg.date as int?) ?? 0;
          int existingMsgDate = (uniqueMsgs[msg.address!]!.date as int?) ?? 0;

          if (currentMsgDate > existingMsgDate) {
            uniqueMsgs[msg.address!] = msg;
          }
        }
      }
    }

    List<ConversationDisplayItem> loadedConversations = [];
    for (var msg in uniqueMsgs.values) {
      String? name = await _repo.getContactName(msg.address!);
      loadedConversations.add(
        ConversationDisplayItem(
          address: msg.address!,
          name: name,
          message: msg.body ?? "",
          date: (msg.date as int?) ?? 0, // کست صحیح
          isRead: msg.read ?? false,
          avatarColor: _repo.generateColor(msg.address!),
        ),
      );
    }

    loadedConversations.sort((a, b) => b.date.compareTo(a.date));
    if (mounted) {
      setState(() {
        _conversations = loadedConversations;
        _filteredConversations = loadedConversations;
        _isLoading = false;
      });
    }
  }

  void _onSearch(String query) {
    setState(() {
      _filteredConversations = _conversations.where((conv) {
        return conv.displayName.toLowerCase().contains(query.toLowerCase()) ||
            conv.address.contains(query);
      }).toList();
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
              placeholder: "Enter number",
              keyboardType: TextInputType.phone,
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
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (_) => ChatScreen(
                        address: controller.text,
                        name: controller.text,
                      ),
                    ),
                  ).then((_) => _loadConversations());
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
    // اگر فایل theme_manager پیدا نشد، این خط را موقتا کامنت کنید تا بقیه کد اجرا شود
    final themeManager = Provider.of<ThemeManager>(context);
    final isDark = themeManager.themeMode == ThemeMode.dark;

    return CupertinoPageScaffold(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text("Messages"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: Icon(
                    isDark
                        ? CupertinoIcons.sun_max_fill
                        : CupertinoIcons.moon_fill,
                  ),
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

          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CupertinoActivityIndicator()),
            )
          else if (_filteredConversations.isEmpty)
            const SliverFillRemaining(
              child: Center(child: Text("No messages found.")),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final conv = _filteredConversations[index];
                return _buildSwipeableItem(conv, isDark);
              }, childCount: _filteredConversations.length),
            ),
        ],
      ),
    );
  }

  Widget _buildSwipeableItem(ConversationDisplayItem conv, bool isDark) {
    return GestureDetector(
      onTap: () async {
        if (!conv.isRead) {
          setState(() {
            conv.isRead = true;
          });
          // در صورت وجود متد markAsRead در آینده
          // _repo.markAsRead(conv.messageId);
        }
        await Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (context) =>
                ChatScreen(address: conv.address, name: conv.displayName),
          ),
        );
        _loadConversations();
      },
      child: Container(
        color: isDark ? const Color(0xFF000000) : CupertinoColors.white,
        padding: const EdgeInsets.only(left: 16, top: 12, bottom: 12),
        child: Row(
          children: [
            if (!conv.isRead)
              Container(
                margin: const EdgeInsets.only(right: 10),
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: CupertinoColors.activeBlue,
                  shape: BoxShape.circle,
                ),
              ),

            CircleAvatar(
              radius: 24,
              backgroundColor: conv.avatarColor,
              child: Text(
                conv.initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Container(
                padding: const EdgeInsets.only(right: 16, bottom: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? const Color(0xFF2C2C2E)
                          : const Color(0xFFE5E5EA),
                      width: 0.5,
                    ),
                  ),
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
                              fontWeight: conv.isRead
                                  ? FontWeight.w500
                                  : FontWeight.bold,
                              fontSize: 17,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                        Text(
                          _formatDateShort(conv.date),
                          style: const TextStyle(
                            color: CupertinoColors.systemGrey,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      conv.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark
                            ? Colors.grey
                            : CupertinoColors.systemGrey,
                        fontSize: 15,
                        height: 1.3,
                        fontWeight: conv.isRead
                            ? FontWeight.normal
                            : FontWeight.w600,
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
    if (now.day == date.day) return DateFormat('jm').format(date);
    if (now.difference(date).inDays < 7) return DateFormat('EEEE').format(date);
    return DateFormat('MM/dd/yy').format(date);
  }
}
