import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'typing_indicator.dart';

class ChatPanel extends StatefulWidget {
  const ChatPanel({
    super.key,
    required this.roomId,
    required this.myProfileId,
    required this.myDisplayName,
  });

  final String roomId;
  final String myProfileId;
  final String myDisplayName;

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final _msg = TextEditingController();
  Timer? _typingDebounce;

  CollectionReference<Map<String, dynamic>> get _messages =>
      FirebaseFirestore.instance.collection("gameRooms").doc(widget.roomId).collection("messages");

  DocumentReference<Map<String, dynamic>> get _presenceRef =>
      FirebaseFirestore.instance.collection("gameRooms").doc(widget.roomId).collection("presence").doc(widget.myProfileId);

  Stream<List<Map<String, dynamic>>> get _presenceStream =>
      FirebaseFirestore.instance.collection("gameRooms").doc(widget.roomId).collection("presence")
          .snapshots().map((s) => s.docs.map((d) => d.data()).toList());

  Future<void> _setTyping(bool v) async {
    await _presenceRef.set({
      "profileId": widget.myProfileId,
      "displayName": widget.myDisplayName,
      "typing": v,
      "lastActiveAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();
    _setTyping(false);
    _msg.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder(
            stream: _messages.orderBy("createdAt", descending: true).limit(60).snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snap.data!.docs;
              return ListView.builder(
                reverse: true,
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final d = docs[i].data();
                  final name = (d["displayName"] ?? "??") as String;
                  final text = (d["text"] ?? "") as String;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: RichText(
                      text: TextSpan(
                        style: DefaultTextStyle.of(context).style.copyWith(fontSize: 13),
                        children: [
                          TextSpan(
                            text: "$name: ",
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(text: text),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),

        StreamBuilder(
          stream: _presenceStream,
          builder: (context, snap) {
            if (!snap.hasData) return const SizedBox.shrink();
            final list = snap.data!;
            final others = list.where((p) {
              final pid = (p["profileId"] ?? "") as String;
              final typing = (p["typing"] ?? false) == true;
              return pid.isNotEmpty && pid != widget.myProfileId && typing;
            }).toList();

            if (others.isEmpty) return const SizedBox.shrink();

            final text = others.length == 1
                ? "${others.first["displayName"] ?? "Alguien"} está escribiendo"
                : "${others.length} personas están escribiendo";

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: TypingIndicator(text: text),
            );
          },
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _msg,
                  decoration: const InputDecoration(
                    hintText: "Escribe…",
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) {
                    _setTyping(true);
                    _typingDebounce?.cancel();
                    _typingDebounce = Timer(
                      const Duration(milliseconds: 1800),
                      () => _setTyping(false),
                    );
                  },
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: () async {
                  final text = _msg.text.trim();
                  if (text.isEmpty) return;
                  _msg.clear();
                  await _messages.add({
                    "profileId": widget.myProfileId,
                    "displayName": widget.myDisplayName,
                    "text": text,
                    "createdAt": FieldValue.serverTimestamp(),
                  });
                  await _setTyping(false);
                },
              ),
            ],
          ),
        )
      ],
    );
  }
}
