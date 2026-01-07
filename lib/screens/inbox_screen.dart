import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
  List<ConversationItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    await _repo.checkAndRequestPermissions();
    final data = await _repo.getConversations();
    if (mounted) setState(() { _items = data; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeManager>(context).themeMode == ThemeMode.dark;
    
    return CupertinoPageScaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF2F2F7), // رنگ پس‌زمینه استاندارد iOS
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text("Messages"),
            leading: CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Text("Edit", style: TextStyle(color: CupertinoColors.activeBlue)),
              onPressed: () {},
            ),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.compose),
              onPressed: () {
                 // باز کردن صفحه چت خالی
                 Navigator.push(context, CupertinoPageRoute(
                   builder: (_) => const ChatScreen(address: "", name: "New Message")
                 ));
              },
            ),
          ),
          
          if (_loading)
            const SliverFillRemaining(child: Center(child: CupertinoActivityIndicator()))
          else if (_items.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("No Messages", style: TextStyle(fontSize: 18, color: Colors.grey)),
                    const SizedBox(height: 10),
                    CupertinoButton.filled(
                      child: const Text("Refresh"),
                      onPressed: _refresh,
                    )
                  ],
                ),
              )
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildRow(_items[index], isDark),
                childCount: _items.length,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRow(ConversationItem item, bool isDark) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, CupertinoPageRoute(
          builder: (_) => ChatScreen(address: item.address, name: item.title),
        )).then((_) => _refresh());
      },
      child: Container(
        color: isDark ? Colors.black : Colors.white,
        padding: const EdgeInsets.only(left: 20),
        child: Row(
          children: [
            if (!item.isRead)
               Container(
                 margin: const EdgeInsets.only(right: 10),
                 width: 10, height: 10,
                 decoration: const BoxDecoration(color: CupertinoColors.activeBlue, shape: BoxShape.circle),
               ),
            
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                color: item.name == null ? Colors.grey[400] : item.color,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(item.initials, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500)),
            ),
            
            const SizedBox(width: 15),
            
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2), width: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                         Text(item.title, style: TextStyle(
                           color: isDark ? Colors.white : Colors.black,
                           fontSize: 17,
                           fontWeight: FontWeight.w600,
                         )),
                         Padding(
                           padding: const EdgeInsets.only(right: 15),
                           child: Text(_formatDate(item.date), style: const TextStyle(
                             color: Colors.grey, fontSize: 14
                           )),
                         ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(right: 20),
                      child: Text(
                        item.snippet,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.grey, fontSize: 15, height: 1.2),
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

  String _formatDate(int millis) {
    if (millis == 0) return "";
    final date = DateTime.fromMillisecondsSinceEpoch(millis);
    final now = DateTime.now();
    if (now.difference(date).inDays == 0 && now.day == date.day) return DateFormat('h:mm a').format(date);
    if (now.difference(date).inDays < 7) return DateFormat('EEEE').format(date);
    return DateFormat('M/d/yy').format(date);
  }
}
