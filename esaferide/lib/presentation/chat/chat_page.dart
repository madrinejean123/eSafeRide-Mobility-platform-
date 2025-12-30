import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import '../call/call_page.dart';
import '../../data/services/chat_service.dart';

class ChatPage extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String? otherUserName;

  const ChatPage({
    super.key,
    required this.chatId,
    required this.otherUserId,
    this.otherUserName,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage>
    with SingleTickerProviderStateMixin {
  final _chat = ChatService();
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  String? _myUid;
  bool _isTyping = false;
  String? _replyToId;
  Map<String, dynamic>? _replyToData;
  bool _isRecording = false;
  final _recorder = Record();

  late AnimationController _sendAnimController;

  @override
  void initState() {
    super.initState();
    _myUid = FirebaseAuth.instance.currentUser?.uid;

    // mark unseen as seen when opening
    if (_myUid != null) {
      _chat.markSeen(widget.chatId, _myUid!);
    }

    _sendAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    _sendAnimController.dispose();
    super.dispose();
  }

  Future<void> _sendText() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _myUid == null) return;
    final Map<String, dynamic>? reply = _replyToId != null
        ? {
            'id': _replyToId,
            'text': _replyToData?['text'] ?? '',
            'senderId': _replyToData?['senderId'] ?? '',
          }
        : null;

    await _chat.sendMessage(
      chatId: widget.chatId,
      senderId: _myUid!,
      text: text,
      replyTo: reply,
    );
    _ctrl.clear();
    _setTyping(false);
    _scrollToBottom();

    // clear reply state after sending
    setState(() {
      _replyToId = null;
      _replyToData = null;
    });

    _sendAnimController.forward(from: 0.0);
  }

  Future<void> _setTyping(bool t) async {
    setState(() => _isTyping = t);
    if (_myUid == null) return;
    await _chat.setTyping(widget.chatId, _myUid!, t);
  }

  Future<void> _pickImageAndSend() async {
    if (_myUid == null) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    if (picked == null) return;
    final file = File(picked.path);
    final ref = FirebaseStorage.instance
        .ref()
        .child('chat_images')
        .child(widget.chatId)
        .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
    final uploadTask = ref.putFile(file);
    final snap = await uploadTask.whenComplete(() {});
    final url = await snap.ref.getDownloadURL();
    await _chat.sendMessage(
      chatId: widget.chatId,
      senderId: _myUid!,
      imageUrl: url,
    );
    _scrollToBottom();
  }

  Future<void> _recordAndSend() async {
    if (_myUid == null) return;
    try {
      // start/stop recording
      if (!_isRecording) {
        final id = const Uuid().v4();
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/voice_$id.m4a';
        await _recorder.start(path: path);
        setState(() => _isRecording = true);
        return;
      } else {
        final path = await _recorder.stop();
        setState(() => _isRecording = false);
        if (path == null) return;
        // upload to storage
        final file = File(path);
        final ref = FirebaseStorage.instance
            .ref()
            .child('chat_audio')
            .child(widget.chatId)
            .child('${DateTime.now().millisecondsSinceEpoch}.m4a');
        final uploadTask = ref.putFile(file);
        final snap = await uploadTask.whenComplete(() {});
        final audioUrl = await snap.ref.getDownloadURL();
        await _chat.sendMessage(
          chatId: widget.chatId,
          senderId: _myUid!,
          audioUrl: audioUrl,
        );
        _scrollToBottom();
      }
    } catch (e) {
      // ignore for now
      setState(() => _isRecording = false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200], // light grey background
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.green[300],
              child: Text(
                widget.otherUserName?.isNotEmpty == true
                    ? widget.otherUserName![0].toUpperCase()
                    : '?',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              widget.otherUserName ?? 'Chat',
              style: const TextStyle(color: Colors.black87),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.call, color: Colors.green),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CallPage(
                    channelName: widget.chatId,
                    chatId: widget.chatId,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chat.streamMessages(widget.chatId),
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Center(child: Text('Error'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs;
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _scrollToBottom(),
                );

                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 8,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final d = docs[i].data() as Map<String, dynamic>;
                    final sender = d['senderId'] as String? ?? '';
                    final isMe = sender == _myUid;
                    final text = (d['text'] as String?) ?? '';
                    final imageUrl = (d['imageUrl'] as String?) ?? '';
                    final seen = d['seen'] as bool? ?? false;
                    final ts = d['timestamp'];
                    final DateTime? dt = ts is Timestamp ? ts.toDate() : null;
                    final timeStr = dt != null ? _timeLabel(dt) : '';

                    // date separator: show if first message or date differs from previous
                    Widget? dateSeparator;
                    if (dt != null) {
                      bool show = false;
                      if (i == 0) {
                        show = true;
                      } else {
                        final prevTs =
                            docs[i - 1].data() as Map<String, dynamic>;
                        final prev = prevTs['timestamp'];
                        if (prev is Timestamp) {
                          final prevDt = prev.toDate();
                          if (!_isSameDate(prevDt, dt)) {
                            show = true;
                          }
                        } else {
                          show = true;
                        }
                      }
                      if (show) {
                        final label = _dateLabel(dt);
                        dateSeparator = Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                label,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                    }

                    // message bubble builder
                    Widget messageBubble() {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        alignment: isMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.7,
                          ),
                          child: GestureDetector(
                            onLongPress: () =>
                                _onMessageLongPress(docs[i].id, d),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? Colors.green[100]
                                    : Colors.grey[300],
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(12),
                                  topRight: const Radius.circular(12),
                                  bottomLeft: Radius.circular(isMe ? 12 : 0),
                                  bottomRight: Radius.circular(isMe ? 0 : 12),
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 2,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (imageUrl.isNotEmpty)
                                    GestureDetector(
                                      onTap: () => _openImageLightbox(imageUrl),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          imageUrl,
                                          width: 200,
                                          height: 200,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  if (text.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        text,
                                        style: const TextStyle(fontSize: 15),
                                      ),
                                    ),
                                  const SizedBox(height: 6),
                                  // reactions (if any)
                                  if (d['reactions'] != null &&
                                      (d['reactions'] as Map).isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 4.0,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: _buildReactions(
                                          d['reactions']
                                              as Map<String, dynamic>,
                                        ),
                                      ),
                                    ),
                                  // timestamp and read ticks under the message
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        timeStr,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      if (isMe)
                                        Icon(
                                          seen ? Icons.done_all : Icons.check,
                                          size: 14,
                                          color: seen
                                              ? Colors.blue
                                              : Colors.black45,
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    // wrap in Dismissible to enable swipe-to-reply gesture
                    final msgWidget = Dismissible(
                      key: ValueKey(docs[i].id),
                      direction: DismissDirection.horizontal,
                      confirmDismiss: (direction) async {
                        // trigger reply UI (simple inline placeholder)
                        _showReplyBanner(docs[i].id, d);
                        return false; // don't actually dismiss
                      },
                      child: messageBubble(),
                    );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (dateSeparator != null) dateSeparator,
                        msgWidget,
                      ],
                    );
                  },
                );
              },
            ),
          ),
          // inline reply banner when replying to a specific message
          if (_replyToId != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 2),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Replying to',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _replyToData?['text']?.toString() ?? '[media]',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _cancelReply,
                      icon: const Icon(Icons.close, size: 20),
                    ),
                  ],
                ),
              ),
            ),
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  CircleAvatar(radius: 12, backgroundColor: Colors.grey[500]),
                  const SizedBox(width: 6),
                  AnimatedDots(), // animated typing dots
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: Colors.white,
            child: Row(
              children: [
                IconButton(
                  onPressed: _pickImageAndSend,
                  icon: const Icon(Icons.attach_file, color: Colors.grey),
                ),
                IconButton(
                  onPressed: _recordAndSend,
                  icon: Icon(
                    _isRecording ? Icons.mic_off : Icons.mic,
                    color: Colors.blue,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    onChanged: (v) => _setTyping(v.isNotEmpty),
                    decoration: const InputDecoration.collapsed(
                      hintText: 'Message',
                      hintStyle: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
                ScaleTransition(
                  scale: Tween<double>(begin: 1, end: 1.2).animate(
                    CurvedAnimation(
                      parent: _sendAnimController,
                      curve: Curves.easeInOut,
                    ),
                  ),
                  child: IconButton(
                    onPressed: _sendText,
                    icon: const Icon(Icons.send, color: Colors.green),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeLabel(DateTime dt) {
    final t = TimeOfDay.fromDateTime(dt);
    return t.format(context);
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    if (_isSameDate(d, today)) {
      return 'Today';
    }
    if (_isSameDate(d, today.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
    // simple readable date
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month]} ${dt.day}, ${dt.year}';
  }

  Future<void> _openImageLightbox(String url) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.of(ctx).pop(),
          child: InteractiveViewer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildReactions(Map<String, dynamic> reactions) {
    final List<Widget> widgets = [];
    reactions.forEach((emoji, val) {
      int count = 0;
      if (val is Map) count = val.keys.length;
      if (val is int) count = val;
      widgets.add(
        Container(
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              Text(count.toString(), style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      );
    });
    return widgets;
  }

  Future<void> _onMessageLongPress(
    String messageId,
    Map<String, dynamic> data,
  ) async {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.reply),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showReplyBanner(messageId, data);
                },
              ),
              ListTile(
                leading: const Icon(Icons.emoji_emotions_outlined),
                title: const Text('React'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  // show quick reaction row
                  final emoji = await showModalBottomSheet<String?>(
                    context: context,
                    builder: (ctx2) => Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: ['❤️', '😂', '👍', '👎', '😮']
                            .map(
                              (e) => GestureDetector(
                                onTap: () => Navigator.of(ctx2).pop(e),
                                child: Text(
                                  e,
                                  style: const TextStyle(fontSize: 28),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  );
                  if (emoji != null) {
                    await _toggleReaction(messageId, emoji);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Delete'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (dctx) => AlertDialog(
                      title: const Text('Delete message?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dctx).pop(false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(dctx).pop(true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) {
                    try {
                      await FirebaseFirestore.instance
                          .collection('chats')
                          .doc(widget.chatId)
                          .collection('messages')
                          .doc(messageId)
                          .delete();
                    } catch (_) {
                      // ignore
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleReaction(String messageId, String emoji) async {
    final ref = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .doc(messageId);
    final myUid = _myUid;
    if (_myUid == null) return;
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      final reactions =
          (data?['reactions'] as Map?)?.cast<String, dynamic>() ?? {};
      final emojiMap =
          (reactions[emoji] as Map?)?.cast<String, dynamic>() ?? {};
      final already = emojiMap.containsKey(myUid);
      if (already) {
        // remove
        tx.update(ref, {'reactions.$emoji.$myUid': FieldValue.delete()});
      } else {
        tx.update(ref, {'reactions.$emoji.$myUid': true});
      }
    });
  }

  void _showReplyBanner(String messageId, Map<String, dynamic> data) {
    setState(() {
      _replyToId = messageId;
      _replyToData = data;
    });
  }

  void _cancelReply() {
    setState(() {
      _replyToId = null;
      _replyToData = null;
    });
  }
}

/// Animated typing dots widget
class AnimatedDots extends StatefulWidget {
  const AnimatedDots({super.key});

  @override
  State<AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<AnimatedDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation1;
  late Animation<double> _animation2;
  late Animation<double> _animation3;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _animation1 = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    _animation2 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 1.0, curve: Curves.easeInOut),
      ),
    );
    _animation3 = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeInOut),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FadeTransition(opacity: _animation1, child: const Dot()),
        const SizedBox(width: 2),
        FadeTransition(opacity: _animation2, child: const Dot()),
        const SizedBox(width: 2),
        FadeTransition(opacity: _animation3, child: const Dot()),
      ],
    );
  }
}

class Dot extends StatelessWidget {
  const Dot({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 6,
      height: 6,
      child: DecoratedBox(
        decoration: BoxDecoration(color: Colors.grey, shape: BoxShape.circle),
      ),
    );
  }
}
