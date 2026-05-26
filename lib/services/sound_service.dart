import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Centralized service for playing in-app sound effects.
///
/// Generates WAV tones programmatically — no external audio files needed.
class SoundService {
  SoundService._();
  static final SoundService _instance = SoundService._();
  static SoundService get instance => _instance;

  AudioPlayer? _ringtonePlayer;
  AudioPlayer? _ringbackPlayer;
  AudioPlayer? _notificationPlayer;

  bool _ringtoneIsPlaying = false;
  bool _ringbackIsPlaying = false;

  // ── Ringtone (incoming call) ───────────────────────────────────────────

  /// Play a looping ringtone for incoming calls.
  /// Uses custom MP3: assets/audio/ringtone_incoming.mp3
  Future<void> playRingtone() async {
    if (_ringtoneIsPlaying) return;
    _ringtoneIsPlaying = true;

    _ringtonePlayer?.dispose();
    _ringtonePlayer = AudioPlayer();
    _ringtonePlayer!.setReleaseMode(ReleaseMode.loop);

    try {
      final byteData = await rootBundle.load('assets/audio/ringtone_incoming.mp3');
      final bytes = byteData.buffer.asUint8List();
      await _ringtonePlayer!.play(BytesSource(bytes));
    } catch (e) {
      print('⚠️ Failed to play ringtone MP3: $e');
      final bytes = _generateRingtoneWav();
      await _ringtonePlayer!.play(BytesSource(bytes));
    }
  }

  /// Stop the incoming call ringtone.
  Future<void> stopRingtone() async {
    _ringtoneIsPlaying = false;
    await _ringtonePlayer?.stop();
    _ringtonePlayer?.dispose();
    _ringtonePlayer = null;
  }

  // ── Ringback (outgoing call, waiting for answer) ───────────────────────

  /// Play a looping ringback tone while waiting for the receiver to answer.
  /// Uses custom MP3: assets/audio/ringtone_outgoing.mp3
  Future<void> playRingback() async {
    if (_ringbackIsPlaying) return;
    _ringbackIsPlaying = true;

    _ringbackPlayer?.dispose();
    _ringbackPlayer = AudioPlayer();
    _ringbackPlayer!.setReleaseMode(ReleaseMode.loop);

    try {
      final byteData = await rootBundle.load('assets/audio/ringtone_outgoing.mp3');
      final bytes = byteData.buffer.asUint8List();
      await _ringbackPlayer!.play(BytesSource(bytes));
    } catch (e) {
      print('⚠️ Failed to play ringback MP3: $e');
      final bytes = _generateRingbackWav();
      await _ringbackPlayer!.play(BytesSource(bytes));
    }
  }

  /// Stop the ringback tone.
  Future<void> stopRingback() async {
    _ringbackIsPlaying = false;
    await _ringbackPlayer?.stop();
    _ringbackPlayer?.dispose();
    _ringbackPlayer = null;
  }

  // ── Notification (new message) ─────────────────────────────────────────

  /// Play a short notification sound for new messages.
  /// Uses custom MP3: assets/audio/notifikasi_chat.mp3
  Future<void> playNotification() async {
    _notificationPlayer?.dispose();
    _notificationPlayer = AudioPlayer();
    _notificationPlayer!.setReleaseMode(ReleaseMode.release);

    try {
      final byteData = await rootBundle.load('assets/audio/notifikasi_chat.mp3');
      final bytes = byteData.buffer.asUint8List();
      await _notificationPlayer!.play(BytesSource(bytes));
    } catch (e) {
      print('⚠️ Failed to play notification MP3: $e');
      final bytes = _generateNotificationWav();
      await _notificationPlayer!.play(BytesSource(bytes));
    }
  }

  // ── Dispose ────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    await stopRingtone();
    await stopRingback();
    _notificationPlayer?.dispose();
    _notificationPlayer = null;
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  WAV Tone Generation (all audio is created in-memory)
  // ═══════════════════════════════════════════════════════════════════════

  static const int _sampleRate = 44100;
  static const int _bitsPerSample = 16;
  static const int _numChannels = 1;

  /// WhatsApp-style Ringtone: Melodic ascending note sequence.
  /// Pattern: E5 → F#5 → G#5 → B5 → pause → repeat once.
  /// Mimics WhatsApp's pleasant ascending call ringtone.
  Uint8List _generateRingtoneWav() {
    final samples = <double>[];

    // WhatsApp-like ascending melody (2 cycles)
    // Notes: E5(659), F#5(740), G#5(831), B5(988)
    const melody = [659.3, 740.0, 830.6, 987.8];
    const noteDuration = 0.15; // each note
    const noteGap = 0.06; // gap between notes
    const volume = 0.45;

    for (var cycle = 0; cycle < 2; cycle++) {
      for (var i = 0; i < melody.length; i++) {
        _addToneWithHarmonics(samples, melody[i], noteDuration, volume);
        if (i < melody.length - 1) _addSilence(samples, noteGap);
      }
      // Hold the last note a bit longer
      _addSilence(samples, 0.1);
      // Short descending callback: B5 → G#5
      _addToneWithHarmonics(samples, 987.8, 0.12, volume * 0.8);
      _addSilence(samples, 0.04);
      _addToneWithHarmonics(samples, 830.6, 0.18, volume * 0.6);

      // Pause between cycles
      _addSilence(samples, 0.8);
    }

    return _samplesToWav(samples);
  }

  /// WhatsApp-style Ringback: Standard telephony ringback tone.
  /// 425 Hz tone, 1s on → 4s off (ITU standard).
  Uint8List _generateRingbackWav() {
    final samples = <double>[];

    // Standard ITU ringback: 425Hz, 1s ring, 4s silence
    _addTone(samples, 425, 1.0, 0.3);
    _addSilence(samples, 4.0);

    return _samplesToWav(samples);
  }

  /// WhatsApp-style Notification: Iconic quick ascending "pop" sound.
  /// Two rapid notes with harmonics for a rich, recognizable tone.
  Uint8List _generateNotificationWav() {
    final samples = <double>[];

    // WhatsApp "pop" — quick ascending double-tap
    // First pop: lower
    _addToneWithHarmonics(samples, 860, 0.06, 0.35);
    _addSilence(samples, 0.015);
    // Second pop: higher (the distinctive part)
    _addToneWithHarmonics(samples, 1320, 0.09, 0.4);
    // Short tail fade
    _addToneWithHarmonics(samples, 1320, 0.04, 0.15);

    return _samplesToWav(samples);
  }

  // ── Tone with harmonics (richer, more musical sound) ───────────────────

  /// Adds a tone with overtones for a warmer, more WhatsApp-like timbre.
  void _addToneWithHarmonics(
      List<double> samples, double freq, double durationSec, double volume) {
    final numSamples = (_sampleRate * durationSec).toInt();
    const fadeSamples = (_sampleRate * 0.008) ~/ 1;
    final fadeLen =
        fadeSamples < (numSamples ~/ 3) ? fadeSamples : (numSamples ~/ 3);

    for (var i = 0; i < numSamples; i++) {
      // Fundamental + harmonics for richness
      final t = i / _sampleRate;
      double sample = sin(2.0 * pi * freq * t) * 0.6; // fundamental
      sample += sin(2.0 * pi * freq * 2 * t) * 0.25; // 2nd harmonic
      sample += sin(2.0 * pi * freq * 3 * t) * 0.10; // 3rd harmonic
      sample += sin(2.0 * pi * freq * 4 * t) * 0.05; // 4th harmonic

      // Smooth envelope (attack + decay)
      double envelope = 1.0;
      if (i < fadeLen) {
        // Smooth attack (sine curve)
        envelope = sin((i / fadeLen) * pi / 2);
      } else if (i > numSamples - fadeLen) {
        // Smooth decay (sine curve)
        envelope = sin(((numSamples - i) / fadeLen) * pi / 2);
      }

      samples.add(sample * envelope * volume);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  /// Add a sine wave tone with fade-in/fade-out envelope.
  void _addTone(List<double> samples, double freq, double durationSec,
      double volume) {
    final numSamples = (_sampleRate * durationSec).toInt();
    const fadeSamples = (_sampleRate * 0.01) ~/ 1; // ~441 samples
    final fadeLen = fadeSamples < (numSamples ~/ 4) ? fadeSamples : (numSamples ~/ 4);

    for (var i = 0; i < numSamples; i++) {
      double sample = sin(2.0 * pi * freq * i / _sampleRate);

      // Fade envelope to avoid clicks
      double envelope = 1.0;
      if (i < fadeLen) {
        envelope = i / fadeLen;
      } else if (i > numSamples - fadeLen) {
        envelope = (numSamples - i) / fadeLen;
      }

      samples.add(sample * envelope * volume);
    }
  }

  /// Add silence.
  void _addSilence(List<double> samples, double durationSec) {
    final numSamples = (_sampleRate * durationSec).toInt();
    for (var i = 0; i < numSamples; i++) {
      samples.add(0.0);
    }
  }

  /// Convert floating-point samples [-1, 1] to a WAV byte array.
  Uint8List _samplesToWav(List<double> samples) {
    final numSamples = samples.length;
    const bytesPerSample = _bitsPerSample ~/ 8;
    final dataSize = numSamples * _numChannels * bytesPerSample;
    final fileSize = 36 + dataSize;

    final buffer = ByteData(44 + dataSize);
    var offset = 0;

    // RIFF header
    buffer.setUint8(offset++, 0x52); // R
    buffer.setUint8(offset++, 0x49); // I
    buffer.setUint8(offset++, 0x46); // F
    buffer.setUint8(offset++, 0x46); // F
    buffer.setUint32(offset, fileSize, Endian.little);
    offset += 4;
    buffer.setUint8(offset++, 0x57); // W
    buffer.setUint8(offset++, 0x41); // A
    buffer.setUint8(offset++, 0x56); // V
    buffer.setUint8(offset++, 0x45); // E

    // fmt sub-chunk
    buffer.setUint8(offset++, 0x66); // f
    buffer.setUint8(offset++, 0x6D); // m
    buffer.setUint8(offset++, 0x74); // t
    buffer.setUint8(offset++, 0x20); // (space)
    buffer.setUint32(offset, 16, Endian.little); // sub-chunk size
    offset += 4;
    buffer.setUint16(offset, 1, Endian.little); // PCM format
    offset += 2;
    buffer.setUint16(offset, _numChannels, Endian.little);
    offset += 2;
    buffer.setUint32(offset, _sampleRate, Endian.little);
    offset += 4;
    buffer.setUint32(
        offset, _sampleRate * _numChannels * bytesPerSample, Endian.little);
    offset += 4;
    buffer.setUint16(offset, _numChannels * bytesPerSample, Endian.little);
    offset += 2;
    buffer.setUint16(offset, _bitsPerSample, Endian.little);
    offset += 2;

    // data sub-chunk
    buffer.setUint8(offset++, 0x64); // d
    buffer.setUint8(offset++, 0x61); // a
    buffer.setUint8(offset++, 0x74); // t
    buffer.setUint8(offset++, 0x61); // a
    buffer.setUint32(offset, dataSize, Endian.little);
    offset += 4;

    // Write samples as 16-bit signed integers
    for (var i = 0; i < numSamples; i++) {
      final clamped = samples[i].clamp(-1.0, 1.0);
      final intVal = (clamped * 32767).toInt();
      buffer.setInt16(offset, intVal, Endian.little);
      offset += 2;
    }

    return buffer.buffer.asUint8List();
  }
}
