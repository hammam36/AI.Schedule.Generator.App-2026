import 'dart:html' as html; // khusus Flutter Web

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:ai_schedule_generator/auth/google_auth.dart';

class ScheduleResultScreen extends StatelessWidget {
  final String scheduleResult;
  const ScheduleResultScreen({super.key, required this.scheduleResult});

  @override
  Widget build(BuildContext context) {
    final sections = _splitScheduleAndTips(scheduleResult);
    final scheduleSection = sections.$1;
    final tipsSection = sections.$2;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Hasil Jadwal Optimal"),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: "Salin Semua Teks",
            onPressed: () {
              Clipboard.setData(ClipboardData(text: scheduleResult));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Semua teks berhasil disalin!")),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: "Ekspor Jadwal ke Google Calendar",
            onPressed: () {
              _showExportDialog(context, scheduleSection);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // HEADER INFORMASI
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 15,
                ),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.indigo.shade100),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.auto_awesome, color: Colors.indigo),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Jadwal dan tips ini disusun otomatis oleh AI berdasarkan prioritas Anda.",
                        style: TextStyle(color: Colors.indigo, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),

              // KONTEN UTAMA: 2 card (Jadwal & Tips) berbagi tinggi
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: _ScheduleCard(scheduleSection: scheduleSection),
                    ),
                    const SizedBox(height: 16),
                    Expanded(child: _TipsCard(tipsSection: tipsSection)),
                  ],
                ),
              ),

              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.refresh),
                  label: const Text("Buat Jadwal Baru"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card untuk bagian jadwal (tabel)
class _ScheduleCard extends StatelessWidget {
  final String scheduleSection;
  const _ScheduleCard({required this.scheduleSection});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Markdown(
            data: scheduleSection,
            selectable: true,
            styleSheet: _markdownStyleSheet(),
            builders: {'table': TableBuilder()},
          ),
        ),
      ),
    );
  }
}

/// Card untuk bagian tips
class _TipsCard extends StatelessWidget {
  final String tipsSection;
  const _TipsCard({required this.tipsSection});

  @override
  Widget build(BuildContext context) {
    if (tipsSection.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Markdown(
            data: tipsSection,
            selectable: true,
            styleSheet: _markdownStyleSheet(),
          ),
        ),
      ),
    );
  }
}

/// Style markdown yang dipakai di kedua card
MarkdownStyleSheet _markdownStyleSheet() {
  return MarkdownStyleSheet(
    p: const TextStyle(fontSize: 15, height: 1.6, color: Colors.black87),
    h1: const TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: Colors.indigo,
    ),
    h2: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    h3: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: Colors.indigoAccent,
    ),
    tableBorder: TableBorder.all(color: Colors.grey, width: 1),
    tableHeadAlign: TextAlign.center,
    tablePadding: const EdgeInsets.all(8),
  );
}

/// Memisahkan hasil AI menjadi (jadwal, tips).
(String, String) _splitScheduleAndTips(String fullText) {
  final lower = fullText.toLowerCase();

  const scheduleMarker = '## jadwal untuk kalender';
  const tipsMarker = '## tips produktif';

  final idxSchedule = lower.indexOf(scheduleMarker);
  if (idxSchedule == -1) {
    return (fullText.trim(), '');
  }

  final idxTips = lower.indexOf(tipsMarker, idxSchedule);

  if (idxTips == -1) {
    final scheduleSection = fullText.substring(idxSchedule).trim();
    return (scheduleSection, '');
  }

  final scheduleSection = fullText.substring(idxSchedule, idxTips).trim();
  final tipsSection = fullText.substring(idxTips).trim();

  return (scheduleSection, tipsSection);
}

// ===================== "EXPORT" VIA GOOGLE CALENDAR URL =======================

Future<void> _ensureLoggedInAndExport(
  BuildContext context,
  String markdownSchedule,
) async {
  try {
    if (markdownSchedule.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Belum ada jadwal yang bisa diekspor (bagian jadwal kosong).',
          ),
        ),
      );
      return;
    }

    // Pastikan punya client yang sudah ter-auth
    final client = await getAuthenticatedClient();
    if (client == null) {
      // ignore: avoid_print
      print('EXPORT: getAuthenticatedClient() returned NULL');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login Google diperlukan untuk ekspor ke Calendar.'),
          ),
        );
      }
      return;
    }

    // Inisialisasi Calendar API dengan client ber-token
    final calendarApi = gcal.CalendarApi(client);

    // Parse jadwal jadi list event
    final events = _parseMarkdownToSimpleEvents(markdownSchedule);

    if (events.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tidak ada baris jadwal yang dikenali. Pastikan tabel jadwal terisi.',
            ),
          ),
        );
      }
      return;
    }

    // Insert semua event ke primary calendar
    for (final event in events) {
      await calendarApi.events.insert(event, 'primary');
    }

    if (!context.mounted) return;

    // Tampilkan dialog sukses + tombol buka Calendar (1 tab saja)
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Berhasil Ekspor'),
          content: Text(
            'Berhasil menambahkan ${events.length} kegiatan ke Google Calendar.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tutup'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                html.window.open(
                  'https://calendar.google.com/calendar/u/0/r',
                  '_blank',
                );
              },
              child: const Text('Buka di Google Calendar'),
            ),
          ],
        );
      },
    );
  } catch (e, st) {
    // print ke console untuk lihat status code / body error
    // (penting banget buat lihat apakah 401, 403, dll)
    // ignore: avoid_print
    print('EXPORT_ERROR: $e');
    // ignore: avoid_print
    print(st);

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal ekspor ke Calendar: $e')));
    }
  }
}

/// Model sederhana event untuk keperluan URL Calendar
class SimpleEvent {
  final String title;
  final DateTime start;
  final DateTime end;
  final String? description;

  SimpleEvent({
    required this.title,
    required this.start,
    required this.end,
    this.description,
  });
}

/// Parser tabel jadwal menjadi list Event Google Calendar.
/// Asumsi: kolom pertama "07:00 - 07:05" dan kolom kedua "Nama Kegiatan".
List<_ScheduleEvent> _parseMarkdownToSimpleEvents(String markdown) {
  final lines = markdown.split('\n');
  final List<_ScheduleEvent> events = [];
  final today = DateTime.now();

  for (var raw in lines) {
    var line = raw.trim();
    if (line.isEmpty) continue;
    if (!line.startsWith('|')) continue;
    if (line.contains(':---')) continue;
    if (line.contains('Waktu') && line.contains('Kegiatan')) continue;

    if (line.startsWith('|')) line = line.substring(1);
    if (line.endsWith('|')) line = line.substring(0, line.length - 1);

    final cols = line.split('|').map((c) => c.trim()).toList();
    if (cols.length < 2) continue;

    final timePart = cols[0];
    final titlePart = cols[1];
    final descPart = cols.length > 2 ? cols[2] : '';

    if (!timePart.contains('-')) continue;
    final range = timePart.split('-');
    if (range.length != 2) continue;

    try {
      final startStr = range[0].trim();
      final endStr = range[1].trim();

      final sh = int.parse(startStr.split(':')[0]);
      final sm = int.parse(startStr.split(':')[1]);
      final eh = int.parse(endStr.split(':')[0]);
      final em = int.parse(endStr.split(':')[1]);

      final start = DateTime(today.year, today.month, today.day, sh, sm);
      final end = DateTime(today.year, today.month, today.day, eh, em);

      events.add(_ScheduleEvent(
        title: titlePart,
        start: start,
        end: end,
        description: descPart,
      ));
    } catch (_) {
      continue;
    }
  }

  return events;
}

class _ScheduleEvent {
  final String title;
  final DateTime start;
  final DateTime end;
  final String description;

  _ScheduleEvent({
    required this.title,
    required this.start,
    required this.end,
    required this.description,
  });
}


class TableBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    dynamic element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    return null;
  }
}

String _buildGoogleCalendarEventUrl({
  required String title,
  required DateTime start,
  required DateTime end,
  String? description,
}) {
  // Format: YYYYMMDDTHHMMSS (tanpa zona, Google anggap pakai timezone user) [web:229]
  String fmt(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}${two(dt.month)}${two(dt.day)}T'
        '${two(dt.hour)}${two(dt.minute)}${two(dt.second)}';
  }

  final startStr = fmt(start);
  final endStr = fmt(end);

  final params = <String, String>{
    'action': 'TEMPLATE',
    'text': title,
    'dates': '$startStr/$endStr',
    if (description != null && description.trim().isNotEmpty)
      'details': description,
  };

  // encode ke query string
  final query = params.entries
      .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
      .join('&');

  return 'https://calendar.google.com/calendar/render?$query';
}

void _showExportDialog(BuildContext context, String markdownSchedule) {
  final events = _parseMarkdownToSimpleEvents(markdownSchedule);
  if (events.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tidak ada baris jadwal yang bisa diekspor.'),
      ),
    );
    return;
  }

  showModalBottomSheet(
    context: context,
    builder: (context) {
      return SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: events.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final ev = events[index];
            final timeStr =
                '${ev.start.hour.toString().padLeft(2, '0')}:${ev.start.minute.toString().padLeft(2, '0')}'
                ' - '
                '${ev.end.hour.toString().padLeft(2, '0')}:${ev.end.minute.toString().padLeft(2, '0')}';

            return ListTile(
              title: Text(ev.title),
              subtitle: Text(timeStr),
              trailing: TextButton(
                child: const Text('Tambah'),
                onPressed: () {
                  final url = _buildGoogleCalendarEventUrl(
                    title: ev.title,
                    start: ev.start,
                    end: ev.end,
                    description: ev.description,
                  );
                  html.window.open(url, '_blank'); // perlu import dart:html
                },
              ),
            );
          },
        ),
      );
    },
  );
}

