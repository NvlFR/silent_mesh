import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'signaling_service.dart';

class WebRTCService {
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  final SignalingService _signaling = SignalingService();

  String? _myPublicKey;

  // Callback ke UI
  Function(String message)? onMessageReceived;
  Function(String status)? onConnectionState;

  // Konfigurasi STUN Server (Google Gratisan) - Ini KUNCI menembus NAT
  final Map<String, dynamic> _config = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ]
  };

  // 1. START SERVICE
  Future<void> init(String myPublicKey) async {
    _myPublicKey = myPublicKey;

    // Sambungkan status signaling ke UI
    _signaling.onStatusChange = (status) => onConnectionState?.call(status);

    await _signaling.connect(myPublicKey);

    // Logic Salaman (Handshake)
    _signaling.onSignalReceived = (data) async {
      String type = data['type'];
      String sender = data['sender'];

      if (type == 'offer') {
        // Ada telpon masuk!
        onConnectionState?.call("📞 Incoming connection from peer...");
        await _handleOffer(data['sdp'], sender);
      } else if (type == 'answer') {
        // Jawaban diterima
        onConnectionState?.call("✅ Handshake Accepted!");
        await _handleAnswer(data['sdp']);
      } else if (type == 'candidate') {
        // Jalan tikus jaringan ditemukan
        if (_peerConnection != null) {
          var candidate = RTCIceCandidate(
              data['candidate'], data['sdpMid'], data['sdpMLineIndex']);
          await _peerConnection!.addCandidate(candidate);
        }
      }
    };
  }

  // 2. KITA YANG NELPON (Caller)
  Future<void> connectToPeer(String targetPublicKey) async {
    onConnectionState?.call("⏳ Initiating connection...");
    _peerConnection = await createPeerConnection(_config);

    // Buat Pipa Data (Chat)
    RTCDataChannelInit dataChannelDict = RTCDataChannelInit();
    _dataChannel =
        await _peerConnection!.createDataChannel("chat", dataChannelDict);
    _setupDataChannelEvents(_dataChannel!);

    // Kirim Kandidat Jaringan (ICE)
    _peerConnection!.onIceCandidate = (candidate) {
      _signaling.sendSignal(targetPublicKey, {
        'type': 'candidate',
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
        'sender': _myPublicKey
      });
    };

    // Buat Offer (Tawaran)
    RTCSessionDescription offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    // Kirim Offer via MQTT
    _signaling.sendSignal(targetPublicKey,
        {'type': 'offer', 'sdp': offer.sdp, 'sender': _myPublicKey});
  }

  // 3. KITA YANG DITELPON (Callee)
  Future<void> _handleOffer(String sdp, String senderKey) async {
    _peerConnection = await createPeerConnection(_config);

    // Kalau ditelpon, kita tunggu Pipa Data terbuka
    _peerConnection!.onDataChannel = (channel) {
      _dataChannel = channel;
      _setupDataChannelEvents(channel);
    };

    _peerConnection!.onIceCandidate = (candidate) {
      _signaling.sendSignal(senderKey, {
        'type': 'candidate',
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
        'sender': _myPublicKey
      });
    };

    await _peerConnection!
        .setRemoteDescription(RTCSessionDescription(sdp, 'offer'));

    // Buat Jawaban
    RTCSessionDescription answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    _signaling.sendSignal(senderKey,
        {'type': 'answer', 'sdp': answer.sdp, 'sender': _myPublicKey});
  }

  Future<void> _handleAnswer(String sdp) async {
    await _peerConnection!
        .setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
  }

  void _setupDataChannelEvents(RTCDataChannel channel) {
    channel.onMessage = (RTCDataChannelMessage message) {
      if (onMessageReceived != null) {
        onMessageReceived!(message.text);
      }
    };
    channel.onDataChannelState = (RTCDataChannelState state) {
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        onConnectionState?.call("🚀 P2P TUNNEL READY (SECURE)");
      }
    };
  }

  void sendMessage(String message) {
    if (_dataChannel != null &&
        _dataChannel!.state == RTCDataChannelState.RTCDataChannelOpen) {
      _dataChannel!.send(RTCDataChannelMessage(message));
    } else {
      print("⚠️ Data Channel not open");
    }
  }

  void dispose() {
    _dataChannel?.close();
    _peerConnection?.close();
  }
}
