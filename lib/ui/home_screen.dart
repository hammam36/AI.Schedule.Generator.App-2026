// lib/ui/home_screen.dart
import 'package:flutter/material.dart';
import 'package:ai_schedule_generator/services/gemini_service.dart';
import 'schedule_result_screen.dart';
import 'package:ai_schedule_generator/auth/google_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // ★ simpan user yang sedang login
  GoogleSignInAccount? _currentUser;

  final List<Map<String, dynamic>> tasks = [];
  final TextEditingController taskController = TextEditingController();
  final TextEditingController durationController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  String? priority;
  bool isLoading = false;

  // ★ Kontrol tampilan form (slide-down animation)
  bool _showForm = false;

  // ★ Saved tasks: daftar tugas yang disimpan untuk digunakan ulang
  final List<Map<String, dynamic>> savedTasks = [];

  // ★ Track tugas mana yang sudah disimpan (berdasarkan index di tasks)
  final Set<int> _savedTaskIndices = {};

  @override
  void initState() {
    super.initState();
    // ★ pantau perubahan user login
    googleSignIn.onCurrentUserChanged.listen((account) {
      setState(() => _currentUser = account);
    });
    // ★ coba restore login sebelumnya (silent sign in)
    googleSignIn.signInSilently();
  }

  @override
  void dispose() {
    taskController.dispose();
    durationController.dispose();
    locationController.dispose();
    super.dispose();
  }

  // ★ Tambah tugas baru, termasuk field lokasi
  void _addTask() {
    if (taskController.text.isNotEmpty &&
        durationController.text.isNotEmpty &&
        priority != null) {
      setState(() {
        tasks.add({
          "name": taskController.text,
          "priority": priority!,
          "duration": int.tryParse(durationController.text) ?? 30,
          // ★ Lokasi opsional, default "Rumah"
          "location": locationController.text.isEmpty
              ? "Rumah"
              : locationController.text,
        });
      });
      taskController.clear();
      durationController.clear();
      locationController.clear();
      setState(() => priority = null);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Expanded(child: Text("Isi nama tugas, durasi, dan prioritas!")),
            ],
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ★ Simpan tugas ke savedTasks
  void _toggleSaveTask(int index) {
    setState(() {
      if (_savedTaskIndices.contains(index)) {
        _savedTaskIndices.remove(index);
        savedTasks.removeWhere((t) => t['name'] == tasks[index]['name']);
      } else {
        _savedTaskIndices.add(index);
        savedTasks.add(Map<String, dynamic>.from(tasks[index]));
      }
    });
  }

  // ★ Duplikat (ulangi) tugas
  void _repeatTask(int index) {
    setState(() {
      tasks.add(Map<String, dynamic>.from(tasks[index]));
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.replay_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text('"${tasks[index]['name']}" ditambahkan lagi!')),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF6C63FF),
      ),
    );
  }

  // ★ Tambah saved task kembali ke daftar
  void _addSavedTaskToList(Map<String, dynamic> task) {
    setState(() {
      tasks.add(Map<String, dynamic>.from(task));
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text('"${task['name']}" ditambahkan dari tugas tersimpan!')),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF6C63FF),
      ),
    );
  }

  void _generateSchedule() async {
    if (tasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Expanded(child: Text("Harap tambahkan tugas dulu!")),
            ],
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => isLoading = true);
    try {
      String schedule = await GeminiService.generateSchedule(tasks);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ScheduleResultScreen(scheduleResult: schedule),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ★ Warna gradien berdasarkan prioritas
  List<Color> _getPriorityGradient(String priority) {
    switch (priority) {
      case 'Tinggi':
        return [const Color(0xFFFF6B6B), const Color(0xFFEE5A24)];
      case 'Sedang':
        return [const Color(0xFFFFBE76), const Color(0xFFF0932B)];
      default:
        return [const Color(0xFF55E6C1), const Color(0xFF1ABC9C)];
    }
  }

  // ★ Format hari dalam bahasa Indonesia
  String _getFormattedDate() {
    final now = DateTime.now();
    const days = [
      'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'
    ];
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    final dayName = days[now.weekday - 1];
    final monthName = months[now.month - 1];
    return '$dayName, ${now.day} $monthName ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ★ Background gradien utama
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF667eea), // biru ungu
              Color(0xFF764ba2), // ungu
              Color(0xFFf093fb), // pink lembut
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ★ Custom AppBar area
              _buildCustomAppBar(),

              // Konten utama (scrollable) dengan doodle background
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
                    child: _buildMainContent(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      // ★ Tombol utama "Buat Jadwal AI" — wide button style
      bottomNavigationBar: _buildBottomButton(),
    );
  }

  // ════════════════════════════════════════════════════════════
  // CUSTOM APP BAR
  // ════════════════════════════════════════════════════════════
  Widget _buildCustomAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // ★ Logo & Branding
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "AI Schedule Assistant",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _getFormattedDate(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),

          // ★ Tombol login / profil
          if (_currentUser == null)
            _buildGlassButton(
              icon: Icons.login_rounded,
              onTap: () async {
                final account = await signInWithGoogle();
                if (!mounted) return;
                if (account == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Login dibatalkan')),
                  );
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text('Halo, ${account.displayName ?? account.email}'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            )
          else
            PopupMenuButton<String>(
              icon: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.account_circle_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              onSelected: (value) async {
                if (value == 'logout') await signOutFromGoogle();
              },
              itemBuilder: (context) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  enabled: false,
                  child: Text(_currentUser!.email),
                ),
                const PopupMenuItem<String>(
                  enabled: false,
                  child: Text('Sudah login'),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Text('Logout'),
                ),
              ],
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
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // MAIN CONTENT — uses a single ListView to avoid nested scroll
  // ════════════════════════════════════════════════════════════
  Widget _buildMainContent() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      children: [
        // ★ EMPTY STATE / HERO CARD — saat belum ada tugas
        // Menggunakan AnimatedSwitcher untuk transisi halus
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SizeTransition(sizeFactor: animation, child: child),
          ),
          child: tasks.isEmpty && !_showForm
              ? _buildHeroCard()
              : const SizedBox.shrink(key: ValueKey('empty')),
        ),

        // ★ FORM INPUT — AnimatedSize untuk slide-down/up halus
        AnimatedSize(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          child: _showForm || tasks.isNotEmpty
              ? _buildFormCard()
              : const SizedBox.shrink(),
        ),

        const SizedBox(height: 16),

        // ★ SAVED TASKS CHIPS — tampil jika ada tugas tersimpan
        if (savedTasks.isNotEmpty) ...[
          _buildSavedTasksSection(),
          const SizedBox(height: 16),
        ],

        // ★ DAFTAR TUGAS — AnimatedSwitcher untuk transisi kosong → isi
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: tasks.isNotEmpty
              ? _buildTaskList()
              : const SizedBox.shrink(key: ValueKey('no-tasks')),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  // HERO CARD — empty state yang menarik
  // ════════════════════════════════════════════════════════════
  Widget _buildHeroCard() {
    return Container(
      key: const ValueKey('hero'),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF667eea),
            Color(0xFF764ba2),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // ★ Ilustrasi hero
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                size: 48,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Susun Jadwal Pintar\ndengan AI",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Tambahkan tugasmu, biarkan AI\nmengatur waktu terbaikmu.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          // ★ Tombol utama tambah tugas
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => setState(() => _showForm = true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF667eea),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 22),
              label: const Text("Tambah Tugas Pertama"),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // FORM CARD — input tugas modern
  // ════════════════════════════════════════════════════════════
  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ★ Header form
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF667eea).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.edit_note_rounded,
                  color: Color(0xFF667eea),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                "Tambah Tugas Baru",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2D3436),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ★ Nama Tugas
          _buildStyledTextField(
            controller: taskController,
            label: "Nama Tugas",
            hint: "contoh: Belajar Matematika",
            icon: Icons.task_alt_rounded,
          ),
          const SizedBox(height: 14),

          // ★ Durasi & Prioritas berdampingan
          Row(
            children: [
              Expanded(
                child: _buildStyledTextField(
                  controller: durationController,
                  label: "Durasi (Menit)",
                  hint: "30",
                  icon: Icons.timer_outlined,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStyledDropdown(),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ★ Lokasi (opsional)
          _buildStyledTextField(
            controller: locationController,
            label: "Lokasi (opsional)",
            hint: "default: Rumah",
            icon: Icons.location_on_outlined,
          ),
          const SizedBox(height: 20),

          // ★ Tombol tambah
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _addTask,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667eea),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text("Tambah ke Daftar"),
            ),
          ),
        ],
      ),
    );
  }

  // ★ TextField dengan styling modern
  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF667eea)),
        filled: true,
        fillColor: const Color(0xFFF8F9FE),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF667eea), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      ),
    );
  }

  // ★ Dropdown prioritas dengan styling modern
  Widget _buildStyledDropdown() {
    return DropdownButtonFormField<String>(
      value: priority,
      style: const TextStyle(fontSize: 15, color: Colors.black87),
      decoration: InputDecoration(
        labelText: "Prioritas",
        prefixIcon: const Icon(Icons.flag_rounded,
            size: 20, color: Color(0xFF667eea)),
        filled: true,
        fillColor: const Color(0xFFF8F9FE),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF667eea), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
      ),
      items: ["Tinggi", "Sedang", "Rendah"]
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: (val) => setState(() => priority = val),
    );
  }

  // ════════════════════════════════════════════════════════════
  // SAVED TASKS SECTION — horizontal chips
  // ════════════════════════════════════════════════════════════
  Widget _buildSavedTasksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.bookmark_rounded,
                size: 18, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(
              "Tugas Tersimpan",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // ★ Horizontal scroll chips untuk saved tasks
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: savedTasks.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final task = savedTasks[index];
              final gradColors = _getPriorityGradient(task['priority']);
              return GestureDetector(
                onTap: () => _addSavedTaskToList(task),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      gradColors[0].withOpacity(0.15),
                      gradColors[1].withOpacity(0.08),
                    ]),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: gradColors[0].withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_circle_outline_rounded,
                          size: 16, color: gradColors[0]),
                      const SizedBox(width: 6),
                      Text(
                        task['name'],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: gradColors[0],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  // TASK LIST — daftar tugas yang sudah ditambahkan
  // ════════════════════════════════════════════════════════════
  Widget _buildTaskList() {
    return Column(
      key: const ValueKey('task-list'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ★ Header section
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF667eea).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.checklist_rounded,
                color: Color(0xFF667eea),
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              "Daftar Tugas",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF667eea).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "${tasks.length} tugas",
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF667eea),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ★ List tugas (tidak pakai ListView.builder karena di dalam ListView utama)
        ...List.generate(tasks.length, (index) {
          final task = tasks[index];
          final isSaved = _savedTaskIndices.contains(index);
          final gradColors = _getPriorityGradient(task['priority']);

          return Dismissible(
            key: UniqueKey(),
            background: Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.red.shade400,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.delete_rounded, color: Colors.white),
            ),
            direction: DismissDirection.endToStart,
            onDismissed: (_) {
              setState(() {
                _savedTaskIndices.remove(index);
                tasks.removeAt(index);
              });
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    // ★ Avatar dengan gradient prioritas
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: gradColors,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          task['name'][0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // ★ Info tugas
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task['name'],
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2D3436),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${task['duration']} menit • ${task['priority']}",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          // Tampilkan lokasi dengan icon Material
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined,
                                  size: 13, color: Colors.grey.shade400),
                              const SizedBox(width: 3),
                              Text(
                                task['location'],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // ★ Tombol Simpan & Ulangi
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Tombol Simpan (bookmark)
                        GestureDetector(
                          onTap: () => _toggleSaveTask(index),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isSaved
                                  ? const Color(0xFF667eea).withOpacity(0.1)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isSaved
                                  ? Icons.bookmark_rounded
                                  : Icons.bookmark_border_rounded,
                              size: 20,
                              color: isSaved
                                  ? const Color(0xFF667eea)
                                  : Colors.grey.shade400,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Tombol Ulangi (repeat)
                        GestureDetector(
                          onTap: () => _repeatTask(index),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.replay_rounded,
                              size: 20,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  // BOTTOM BUTTON — Buat Jadwal AI (wide style)
  // ════════════════════════════════════════════════════════════
  Widget _buildBottomButton() {
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
            onPressed: isLoading ? null : _generateSchedule,
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
              backgroundColor: Colors.transparent,
              disabledBackgroundColor: Colors.grey.shade300,
            ),
            child: Ink(
              decoration: BoxDecoration(
                gradient: isLoading
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                      ),
                color: isLoading ? Colors.grey.shade300 : null,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isLoading)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    else
                      const Icon(Icons.auto_awesome_rounded,
                          color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      isLoading ? "Sedang Memproses..." : "Buat Jadwal AI",
                      style: const TextStyle(
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