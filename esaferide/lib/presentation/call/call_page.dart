import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';

class CallPage extends StatefulWidget {
  final String channelName;
  final String chatId;
  final String? token;

  const CallPage({
    super.key,
    required this.channelName,
    required this.chatId,
    this.token,
  });

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  static const String agoraAppId = '6441c8b3672949648ec3c90de11dc1eb';

  late RtcEngine _engine;
  String? _callDocId;
  bool _joined = false;

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  Future<void> _initAgora() async {
    await [Permission.microphone].request();

    _engine = createAgoraRtcEngine();
    await _engine.initialize(const RtcEngineContext(appId: agoraAppId));

    await _engine.enableAudio();

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) async {
          setState(() => _joined = true);

          final doc = await FirebaseFirestore.instance
              .collection('chats')
              .doc(widget.chatId)
              .collection('calls')
              .add({
                'callType': 'audio',
                'status': 'ongoing',
                'channel': widget.channelName,
                'startedAt': FieldValue.serverTimestamp(),
              });

          _callDocId = doc.id;
        },
      ),
    );

    await _engine.joinChannel(
      token: widget.token ?? '',
      channelId: widget.channelName,
      uid: 0,
      options: const ChannelMediaOptions(),
    );
  }

  Future<void> _endCall() async {
    if (_callDocId != null) {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('calls')
          .doc(_callDocId)
          .update({'status': 'ended', 'endedAt': FieldValue.serverTimestamp()});
    }

    await _engine.leaveChannel();
    await _engine.release();

    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _engine.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Audio Call'),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_end, color: Colors.red),
            onPressed: _endCall,
          ),
        ],
      ),
      body: Center(
        child: Text(
          _joined ? 'Connected' : 'Connecting...',
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
    );
  }
}
