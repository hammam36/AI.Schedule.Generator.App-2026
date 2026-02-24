import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:http/http.dart' as http;
import 'package:ai_schedule_generator/auth/google_auth.dart';

class ScheduleResultScreen extends StatelessWidget {
  final String scheduleResult;
  const ScheduleResultScreen({super.key, required this.scheduleResult});

  @override
  Widget build(BuildContext context) {
    // Pisahkan hasil AI menjadi dua bagian: jadwal & tips
    debugPrint('=== RAW SCHEDULE RESULT ===');
    debugPrint(scheduleResult);

    final sections = _splitScheduleAndTips(scheduleResult);
    final scheduleSection = sections.$1;
    final tipsSection = sections.$2;

    debugPrint('=== SCHEDULE SECTION ===');
    debugPrint(scheduleSection);
    debugPrint('=== TIPS SECTION ===');
    debugPrint(tipsSection);

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
            onPressed: () async {
              await _ensureLoggedInAndExport(context, scheduleSection);
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

              // KONTEN UTAMA (2 CARD) DALAM SCROLL
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

/// Card untuk bagian jadwal (tabel) yang bisa diekspor ke Calendar
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
/// Asumsi: ada heading '## JADWAL UNTUK KALENDER' dan '## TIPS PRODUKTIF'.
(String, String) _splitScheduleAndTips(String fullText) {
  // Pakai lowercase untuk pencarian, supaya tidak sensitif huruf besar/kecil
  final lower = fullText.toLowerCase();

  const scheduleMarker = '## jadwal untuk kalender';
  const tipsMarker = '## tips produktif';

  final idxSchedule = lower.indexOf(scheduleMarker);
  if (idxSchedule == -1) {
    // Tidak ada marker, anggap seluruh teks sebagai jadwal
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

// ===================== GOOGLE CALENDAR EXPORT =======================

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

    // Pastikan sudah login
    var user = googleSignIn.currentUser;
    if (user == null) {
      user = await signInWithGoogle();
      if (user == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login diperlukan untuk ekspor')),
          );
        }
        return;
      }
    }

    // Ambil auth headers dari user yang login
    final authHeaders = await user.authHeaders;

    // Buat http.Client yang otomatis menambahkan header auth
    final client = _GoogleAuthClient(authHeaders);

    // Inisialisasi Calendar API
    final calendarApi = gcal.CalendarApi(client);

    // Parse teks jadwal AI jadi list Event
    final events = _parseMarkdownToEvents(markdownSchedule);

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

    // Insert setiap event ke calendar "primary"
    for (final event in events) {
      await calendarApi.events.insert(event, 'primary');
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Berhasil ekspor ${events.length} event ke Calendar'),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal ekspor ke Calendar: $e')));
    }
  }
}

/// Parser tabel jadwal menjadi list Event.
/// Asumsi: tabel dengan kolom pertama "07:00 - 07:05" dan kolom kedua "Nama Kegiatan".
List<gcal.Event> _parseMarkdownToEvents(String markdown) {
  final lines = markdown.split('\n');
  final List<gcal.Event> events = [];

  final today = DateTime.now();

  for (final rawLine in lines) {
    var line = rawLine.trim();
    if (line.isEmpty) continue;

    // Proses hanya baris tabel, bukan header/separator
    if (!line.startsWith('|')) continue;
    if (line.contains(':---')) continue;
    if (line.contains('Waktu') && line.contains('Kegiatan')) continue;

    // Buang '|' di awal/akhir lalu pecah
    if (line.startsWith('|')) {
      line = line.substring(1);
    }
    if (line.endsWith('|')) {
      line = line.substring(0, line.length - 1);
    }

    final cols = line.split('|').map((c) => c.trim()).toList();
    if (cols.length < 2) continue;

    final timePart = cols[0];
    final titlePart = cols[1];

    if (!timePart.contains('-')) continue;

    final timeRange = timePart.split('-');
    if (timeRange.length != 2) continue;

    try {
      final startStr = timeRange[0].trim();
      final endStr = timeRange[1].trim();

      final startHour = int.parse(startStr.split(':')[0]);
      final startMin = int.parse(startStr.split(':')[1]);
      final endHour = int.parse(endStr.split(':')[0]);
      final endMin = int.parse(endStr.split(':')[1]);

      final startDateTime = DateTime(
        today.year,
        today.month,
        today.day,
        startHour,
        startMin,
      );

      final endDateTime = DateTime(
        today.year,
        today.month,
        today.day,
        endHour,
        endMin,
      );

      final event = gcal.Event(
        summary: titlePart,
        start: gcal.EventDateTime(dateTime: startDateTime),
        end: gcal.EventDateTime(dateTime: endDateTime),
      );

      events.add(event);
    } catch (_) {
      continue;
    }
  }

  return events;
}

class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
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
