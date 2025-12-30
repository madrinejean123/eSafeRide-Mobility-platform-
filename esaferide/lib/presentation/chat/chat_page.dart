import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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

class _ChatPageState extends State<ChatPage> {
  final _chat = ChatService();
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  String? _myUid;

  @override
  void initState() {
    super.initState();
    _myUid = FirebaseAuth.instance.currentUser?.uid;
    // mark unseen as seen when opening
    if (_myUid != null) {
      _chat.markSeen(widget.chatId, _myUid!);
    }
  }

  Future<void> _sendText() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _myUid == null) return;
    await _chat.sendMessage(
      chatId: widget.chatId,
      senderId: _myUid!,
      text: text,
    );
    _ctrl.clear();
    _setTyping(false);
    _scrollToBottom();
  }

  Future<void> _setTyping(bool t) async {
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

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              child: Text(
                widget.otherUserName?.isNotEmpty == true
                    ? widget.otherUserName![0].toUpperCase()
                    : '?',
              ),
            ),
            const SizedBox(width: 8),
            Text(widget.otherUserName ?? 'Chat'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chat.streamMessages(widget.chatId),
              builder: (context, snap) {
                if (snap.hasError) return const Center(child: Text('Error'));
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs;
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _scrollToBottom(),
                );
                return ListView.builder(
                  controller: _scroll,
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final d = docs[i].data() as Map<String, dynamic>;
                    final sender = d['senderId'] as String? ?? '';
                    final isMe = sender == _myUid;
                    final text = (d['text'] as String?) ?? '';
                    final imageUrl = (d['imageUrl'] as String?) ?? '';
                    final seen = d['seen'] as bool? ?? false;
                    final ts = d['timestamp'];
                    final timeStr = ts is Timestamp
                        ? _timeLabel(ts.toDate())
                        : '';
                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.green[100] : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (imageUrl.isNotEmpty)
                              Image.network(
                                imageUrl,
                                width: 200,
                                height: 200,
                                fit: BoxFit.cover,
                              ),
                            if (text.isNotEmpty) Text(text),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  timeStr,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                if (isMe)
                                  Icon(
                                    seen ? Icons.done_all : Icons.check,
                                    size: 14,
                                    color: seen ? Colors.blue : Colors.black45,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: Colors.white,
            child: Row(
              children: [
                IconButton(
                  onPressed: _pickImageAndSend,
                  icon: const Icon(Icons.attach_file),
                ),
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    onChanged: (v) => _setTyping(v.isNotEmpty),
                    decoration: const InputDecoration.collapsed(
                      hintText: 'Message',
                    ),
                  ),
                ),
                IconButton(onPressed: _sendText, icon: const Icon(Icons.send)),
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
}
