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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF667eea),
              Color(0xFF764ba2),
              Color(0xFFf093fb),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom AppBar area — konsisten dengan HomeScreen
              _buildCustomAppBar(context, scheduleSection),

              // Konten utama dengan doodle background
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      image: const DecorationImage(
                        image: AssetImage('assets/images/doodle_bg.jpg'),
                        fit: BoxFit.cover,
                        opacity: 0.12,
                      ),
                    ),
                    child: _buildContent(context, scheduleSection, tipsSection),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      // Bottom button — kembali ke halaman utama
      bottomNavigationBar: _buildBottomButton(context),
    );
  }

  // ════════════════════════════════════════════════════════════
  // CUSTOM APP BAR — selaras dengan HomeScreen
  // ════════════════════════════════════════════════════════════
  Widget _buildCustomAppBar(BuildContext context, String scheduleSection) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // Tombol kembali
          _buildGlassButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 14),
          // Judul
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Hasil Jadwal Optimal",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Disusun otomatis oleh AI",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          // Tombol salin
          _buildGlassButton(
            icon: Icons.content_copy_rounded,
            onTap: () {
              Clipboard.setData(ClipboardData(text: scheduleResult));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: const [
                      Icon(Icons.check_circle_outline_rounded,
                          color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text("Semua teks berhasil disalin!"),
                    ],
                  ),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: const Color(0xFF667eea),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          // Tombol ekspor ke Google Calendar
          _buildGlassButton(
            icon: Icons.calendar_month_rounded,
            onTap: () async {
              await _ensureLoggedInAndExport(context, scheduleSection);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGlassButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // KONTEN UTAMA — scrollable, dua card
  // ════════════════════════════════════════════════════════════
  Widget _buildContent(
    BuildContext context,
    String scheduleSection,
    String tipsSection,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      children: [
        // Info banner
        _buildInfoBanner(),
        const SizedBox(height: 20),

        // Card Jadwal
        _buildSectionHeader(
          icon: Icons.event_note_rounded,
          title: "Jadwal untuk Kalender",
        ),
        const SizedBox(height: 12),
        _ScheduleCard(scheduleSection: scheduleSection),
        const SizedBox(height: 24),

        // Card Tips
        if (tipsSection.trim().isNotEmpty) ...[
          _buildSectionHeader(
            icon: Icons.lightbulb_outline_rounded,
            title: "Tips Produktif",
          ),
          const SizedBox(height: 12),
          _TipsCard(tipsSection: tipsSection),
        ],
      ],
    );
  }

  // Banner info — redesigned
  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF667eea).withOpacity(0.08),
            const Color(0xFF764ba2).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF667eea).withOpacity(0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF667eea).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFF667eea),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              "Jadwal dan tips ini disusun otomatis oleh AI berdasarkan prioritas Anda.",
              style: TextStyle(
                color: Color(0xFF4A4A6A),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Section header
  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF667eea).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF667eea), size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  // BOTTOM BUTTON — Buat Jadwal Baru
  // ════════════════════════════════════════════════════════════
  Widget _buildBottomButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
              backgroundColor: Colors.transparent,
            ),
            child: Ink(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
                    SizedBox(width: 10),
                    Text(
                      "Buat Jadwal Baru",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Card untuk bagian jadwal (tabel) — redesigned
class _ScheduleCard extends StatelessWidget {
  final String scheduleSection;
  const _ScheduleCard({required this.scheduleSection});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: MarkdownBody(
            data: scheduleSection,
            selectable: true,
            styleSheet: _markdownStyleSheet(),
          ),
        ),
      ),
    );
  }
}

/// Card untuk bagian tips — redesigned
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
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: MarkdownBody(
            data: tipsSection,
            selectable: true,
            styleSheet: _markdownStyleSheet(),
          ),
        ),
      ),
    );
  }
}

/// Style markdown yang dipakai di kedua card — warna disesuaikan
MarkdownStyleSheet _markdownStyleSheet() {
  return MarkdownStyleSheet(
    p: const TextStyle(
      fontSize: 14,
      height: 1.6,
      color: Color(0xFF2D3436),
    ),
    h1: const TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.bold,
      color: Color(0xFF667eea),
    ),
    h2: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: Color(0xFF4A4A6A),
    ),
    h3: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: Color(0xFF764ba2),
    ),
    tableBorder: TableBorder.all(
      color: const Color(0xFFE0E0E0),
      width: 1,
    ),
    tableHeadAlign: TextAlign.center,
    tablePadding: const EdgeInsets.all(8),
    tableHead: const TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 13,
      color: Color(0xFF667eea),
    ),
    tableBody: const TextStyle(
      fontSize: 13,
      color: Color(0xFF2D3436),
    ),
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

// ===================== GOOGLE CALENDAR EXPORT =======================

Future<void> _ensureLoggedInAndExport(
  BuildContext context,
  String markdownSchedule,
) async {
  try {
    if (markdownSchedule.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text('Belum ada jadwal yang bisa diekspor.'),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

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

    final authHeaders = await user.authHeaders;
    final client = _GoogleAuthClient(authHeaders);
    final calendarApi = gcal.CalendarApi(client);
    final events = _parseMarkdownToEvents(markdownSchedule);

    if (events.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.info_outline_rounded,
                    color: Colors.white, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tidak ada baris jadwal yang dikenali. Pastikan tabel jadwal terisi.',
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    for (final event in events) {
      await calendarApi.events.insert(event, 'primary');
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child:
                    Text('Berhasil ekspor ${events.length} event ke Calendar'),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF667eea),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('Gagal ekspor ke Calendar: $e')),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade400,
        ),
      );
    }
  }
}

/// Parser tabel jadwal menjadi list Event.
/// Parameter [defaultLocation] memungkinkan lokasi default untuk semua event.
List<gcal.Event> _parseMarkdownToEvents(
  String markdown, {
  String defaultLocation = 'Rumah',
}) {
  final lines = markdown.split('\n');
  final List<gcal.Event> events = [];

  final today = DateTime.now();

  for (final rawLine in lines) {
    var line = rawLine.trim();
    if (line.isEmpty) continue;

    if (!line.startsWith('|')) continue;
    if (line.contains(':---')) continue;
    if (line.contains('Waktu') && line.contains('Kegiatan')) continue;

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
        location: defaultLocation,
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
