import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/call_log_model.dart';
import '../services/auth_service.dart';
import '../services/call_log_service.dart';
import '../utils/avatar_helper.dart';

class CallLogPage extends StatefulWidget {
  const CallLogPage({super.key});

  @override
  State<CallLogPage> createState() => _CallLogPageState();
}

class _CallLogPageState extends State<CallLogPage> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final currentUid = context.read<AuthService>().currentUid ?? '';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 10, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Calls',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert_rounded,
                        color: theme.colorScheme.onSurface),
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
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: TextField(
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.toLowerCase();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search calls...',
                  hintStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF2C2C2C)
                      : Colors.grey[100],
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<CallLogModel>>(
                stream: CallLogService.logsStream(currentUid),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: theme.colorScheme.primary,
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
                              style: TextStyle(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final allLogs = snap.data ?? [];
                  final logs = allLogs.where((log) {
                    if (_searchQuery.isEmpty) return true;
                    final name = log.otherName(currentUid).toLowerCase();
                    return name.contains(_searchQuery);
                  }).toList();

                  if (logs.isEmpty) {
                    if (_searchQuery.isNotEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Text(
                            'Tidak ada hasil untuk "$_searchQuery"',
                            style: TextStyle(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.4),
                                fontSize: 14),
                          ),
                        ),
                      );
                    }
                    return const _EmptyState();
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
            ),
          ],
        ),
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
              ),
            ),
            content: const Text(
              'Semua riwayat panggilan akan dihapus secara permanen.',
              style: TextStyle(fontSize: 14),
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
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF0F0F0),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.phone_missed_rounded,
              size: 44,
              color: isDark ? const Color(0xFF555555) : const Color(0xFFCCCCCC),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Belum ada log panggilan',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Riwayat panggilan akan muncul di sini',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
            ),
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
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
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
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF333333) : const Color(0xFFF5F5F5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    log.type == CallLogType.video
                        ? Icons.videocam_rounded
                        : Icons.phone_rounded,
                    size: 11,
                    color: theme.colorScheme.onSurface,
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
                  : theme.colorScheme.onSurface,
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
                Text(
                  ' · ',
                  style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                ),
                Text(
                  log.durationText,
                  style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
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
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                ),
              ),
              const SizedBox(height: 6),
              Icon(
                log.type == CallLogType.video
                    ? Icons.videocam_outlined
                    : Icons.phone_outlined,
                size: 16,
                color: theme.colorScheme.primary,
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
