import 'package:cloud_firestore/cloud_firestore.dart';

class ChatService {
  final CollectionReference _chats = FirebaseFirestore.instance.collection(
    'chats',
  );

  static String chatIdFor(String a, String b) {
    final parts = [a, b]..sort();
    return '${parts[0]}_${parts[1]}';
  }

  /// Ensure a chat document exists between two users and return chatId
  Future<String> createChatIfNotExists({
    required String a,
    required String b,
  }) async {
    final chatId = chatIdFor(a, b);
    final doc = _chats.doc(chatId);
    final snapshot = await doc.get();
    if (!snapshot.exists) {
      await doc.set({
        'participants': [a, b],
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'typing': {},
      });
    }
    return chatId;
  }

  Stream<QuerySnapshot> streamChatsForUser(String uid) {
    return _chats
        .where('participants', arrayContains: uid)
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> streamMessages(String chatId) {
    return _chats
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots();
  }

  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    String? text,
    String? imageUrl,
  }) async {
    final col = _chats.doc(chatId).collection('messages');
    final now = FieldValue.serverTimestamp();
    await col.add({
      'senderId': senderId,
      'text': text ?? '',
      'imageUrl': imageUrl ?? '',
      'timestamp': now,
      'seen': false,
    });
    await _chats.doc(chatId).update({
      'lastMessage': text ?? (imageUrl != null ? 'Image' : ''),
      'lastMessageTime': now,
    });
  }

  Future<void> setTyping(String chatId, String uid, bool typing) async {
    final doc = _chats.doc(chatId);
    await doc.set({
      'typing': {uid: typing},
    }, SetOptions(merge: true));
  }

  /// Mark unseen messages as seen for the user (messages sent by others)
  Future<void> markSeen(String chatId, String myUid) async {
    final col = _chats.doc(chatId).collection('messages');
    final q = await col.where('seen', isEqualTo: false).get();
    for (final d in q.docs) {
      final data = d.data();
      if (data['senderId'] == myUid) continue;
      await d.reference.update({'seen': true});
    }
  }
}
