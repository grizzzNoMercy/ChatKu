import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/call_log_model.dart';
import '../services/auth_service.dart';
import '../services/call_log_service.dart';
import '../utils/avatar_helper.dart';

class CallLogPage extends StatelessWidget {
  const CallLogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUid = context.read<AuthService>().currentUid ?? '';
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Log Panggilan',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Color(0xFF111111),
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded,
                color: Color(0xFF111111)),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            onSelected: (v) async {
              if (v == 'clear') {
                final ok = await _confirmClear(context);
                if (ok && context.mounted) {
                  await CallLogService.clearAllLogs(currentUid);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Semua log panggilan dihapus'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep_rounded,
                        color: Color(0xFFFF3B30), size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Hapus Semua',
                      style: TextStyle(color: Color(0xFFFF3B30)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<CallLogModel>>(
        stream: CallLogService.logsStream(currentUid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF111111),
                strokeWidth: 2,
              ),
            );
          }

          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 48, color: Color(0xFFFF3B30)),
                    const SizedBox(height: 12),
                    Text(
                      'Gagal memuat log: ${snap.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF999999),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final logs = snap.data ?? [];

          if (logs.isEmpty) {
            return _EmptyState();
          }

          // Group logs by date
          final grouped = _groupByDate(logs);
          final keys = grouped.keys.toList();

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: keys.length,
            itemBuilder: (context, i) {
              final dateLabel = keys[i];
              final dayLogs = grouped[dateLabel]!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DateHeader(label: dateLabel),
                  ...dayLogs.map((log) => _CallLogTile(
                        log: log,
                        currentUid: currentUid,
                        onDelete: () async {
                          await CallLogService.deleteLog(log.id);
                        },
                      )),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Map<String, List<CallLogModel>> _groupByDate(List<CallLogModel> logs) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final result = <String, List<CallLogModel>>{};
    for (final log in logs) {
      final d = log.timestamp.toDate();
      final day = DateTime(d.year, d.month, d.day);
      String label;
      if (day == today) {
        label = 'Hari Ini';
      } else if (day == yesterday) {
        label = 'Kemarin';
      } else {
        label =
            '${_dayName(d.weekday)}, ${d.day} ${_monthName(d.month)} ${d.year}';
      }
      result.putIfAbsent(label, () => []).add(log);
    }
    return result;
  }

  static String _dayName(int w) {
    const n = ['', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    return n[w];
  }

  static String _monthName(int m) {
    const n = [
      '',
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    return n[m];
  }

  Future<bool> _confirmClear(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24)),
            title: const Text(
              'Hapus Semua Log?',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: Color(0xFF111111),
              ),
            ),
            content: const Text(
              'Semua riwayat panggilan akan dihapus secara permanen.',
              style: TextStyle(fontSize: 14, color: Color(0xFF666666)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF3B30),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28)),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Hapus'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

// ── Empty State ───────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(
              color: Color(0xFFF0F0F0),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.phone_missed_rounded,
              size: 44,
              color: Color(0xFFCCCCCC),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Belum ada log panggilan',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF999999),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Riwayat panggilan akan muncul di sini',
            style: TextStyle(fontSize: 13, color: Color(0xFFBBBBBB)),
          ),
        ],
      ),
    );
  }
}

// ── Date Header ───────────────────────────────────────────────────────────
class _DateHeader extends StatelessWidget {
  final String label;
  const _DateHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF999999),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── Call Log Tile ─────────────────────────────────────────────────────────
class _CallLogTile extends StatelessWidget {
  final CallLogModel log;
  final String currentUid;
  final VoidCallback onDelete;

  const _CallLogTile({
    required this.log,
    required this.currentUid,
    required this.onDelete,
  });

  bool get _isCaller => log.callerId == currentUid;

  CallLogStatus get _myStatus {
    if (log.status == CallLogStatus.missed && !_isCaller) {
      return CallLogStatus.missed;
    }
    return _isCaller ? CallLogStatus.outgoing : CallLogStatus.incoming;
  }

  IconData get _directionIcon {
    switch (_myStatus) {
      case CallLogStatus.outgoing:
        return Icons.call_made_rounded;
      case CallLogStatus.incoming:
        return Icons.call_received_rounded;
      case CallLogStatus.missed:
        return Icons.call_missed_rounded;
    }
  }

  Color get _directionColor {
    switch (_myStatus) {
      case CallLogStatus.outgoing:
        return const Color(0xFF34C759);
      case CallLogStatus.incoming:
        return const Color(0xFF007AFF);
      case CallLogStatus.missed:
        return const Color(0xFFFF3B30);
    }
  }

  String get _directionLabel {
    switch (_myStatus) {
      case CallLogStatus.outgoing:
        return 'Panggilan Keluar';
      case CallLogStatus.incoming:
        return 'Panggilan Masuk';
      case CallLogStatus.missed:
        return 'Panggilan Tak Terjawab';
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = log.otherName(currentUid);
    final photo = log.otherPhotoUrl(currentUid);
    final time = _formatTime(log.timestamp);

    return Dismissible(
      key: Key(log.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: const Color(0xFFFF3B30),
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.white, size: 24),
      ),
      confirmDismiss: (_) async {
        return await _confirmDelete(context);
      },
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AvatarHelper.backgroundColor(name),
                backgroundImage:
                    photo.isNotEmpty ? NetworkImage(photo) : null,
                child: photo.isEmpty
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: AvatarHelper.textColor(name),
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      )
                    : null,
              ),
              // call type badge
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF5F5F5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    log.type == CallLogType.video
                        ? Icons.videocam_rounded
                        : Icons.phone_rounded,
                    size: 11,
                    color: const Color(0xFF111111),
                  ),
                ),
              ),
            ],
          ),
          title: Text(
            name,
            style: TextStyle(
              fontWeight: _myStatus == CallLogStatus.missed
                  ? FontWeight.w700
                  : FontWeight.w600,
              fontSize: 15,
              color: _myStatus == CallLogStatus.missed
                  ? const Color(0xFFFF3B30)
                  : const Color(0xFF111111),
            ),
          ),
          subtitle: Row(
            children: [
              Icon(_directionIcon, size: 13, color: _directionColor),
              const SizedBox(width: 4),
              Text(
                _directionLabel,
                style: TextStyle(fontSize: 12, color: _directionColor),
              ),
              if (log.durationText.isNotEmpty) ...[
                const Text(
                  ' · ',
                  style:
                      TextStyle(fontSize: 12, color: Color(0xFF999999)),
                ),
                Text(
                  log.durationText,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF999999)),
                ),
              ],
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                time,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFBBBBBB),
                ),
              ),
              const SizedBox(height: 6),
              Icon(
                log.type == CallLogType.video
                    ? Icons.videocam_outlined
                    : Icons.phone_outlined,
                size: 16,
                color: const Color(0xFF007AFF),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: const Text('Hapus log ini?'),
            content: const Text('Entri log panggilan ini akan dihapus.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Hapus',
                  style: TextStyle(color: Color(0xFFFF3B30)),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  String _formatTime(Timestamp ts) {
    final d = ts.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(d.year, d.month, d.day);
    if (date == today) {
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    return '${d.day}/${d.month}';
  }
}
