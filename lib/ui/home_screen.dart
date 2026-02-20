import 'package:flutter/material.dart';
import 'package:ai_schedule_generator/services/gemini_service.dart'; // Service untuk memanggil AI
import 'schedule_result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Menyimpan daftar tugas dalam bentuk List of Map
  final List<Map<String, dynamic>> tasks = [];
  // Controller untuk mengambil input dari TextField
  final TextEditingController taskController = TextEditingController();
  final TextEditingController durationController = TextEditingController();
  String? priority; // Menyimpan nilai dropdown
  bool isLoading = false; // Status loading saat proses AI berjalan

  @override
  void dispose() {
    // Controller harus dibersihkan agar tidak memory leak
    taskController.dispose();
    durationController.dispose();
    super.dispose();
  }

  // ... (methods & build di step berikutnya)
  void _addTask() {
    // Validasi sederhana: semua field harus terisi
    if (taskController.text.isNotEmpty &&
        durationController.text.isNotEmpty &&
        priority != null) {
      setState(() {
        // Tambahkan data ke list
        tasks.add({
          "name": taskController.text,
          "priority": priority!,
          "duration": int.tryParse(durationController.text) ?? 30,
        });
      });
      // Reset form setelah input berhasil
      taskController.clear();
      durationController.clear();
      setState(() => priority = null);
    }
  }

  void _generateSchedule() async {
    // Jika belum ada tugas, tampilkan peringatan
    if (tasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠ Harap tambahkan tugas dulu!")),
      );
      return;
    }
    setState(() => isLoading = true); // Aktifkan loading
    try {
      // Proses asynchronous ke AI service
      String schedule = await GeminiService.generateSchedule(tasks);
      if (!mounted) return; // Pastikan widget masih aktif
      // Navigasi ke halaman hasil
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ScheduleResultScreen(scheduleResult: schedule),
        ),
      );
    } catch (e) {
      // Tampilkan error jika gagal
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      // Loading dimatikan baik sukses maupun gagal
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: const Text("AI Schedule Generator")),
    body: Column(
      children: [
        // FORM INPUT TUGAS
        Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: taskController,
                  decoration: const InputDecoration(
                    labelText: "Nama Tugas",
                    prefixIcon: Icon(Icons.task),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // Input durasi
                    Expanded(
                      child: TextField(
                        controller: durationController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Durasi (Menit)",
                          prefixIcon: Icon(Icons.timer),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Dropdown prioritas
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        // ignore: deprecated_member_use
                        value: priority,
                        decoration: const InputDecoration(
                          labelText: "Prioritas",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.flag),
                        ),
                        items: ["Tinggi", "Sedang", "Rendah"]
                            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (val) => setState(() => priority = val),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Tombol tambah tugas
                SizedBox(
                  height: 50,
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _addTask,
                    icon: const Icon(Icons.add),
                    label: const Text("Tambah ke Daftar"),
                  ),
                ),
              ],
            ),
          ),
        ),
        // LIST TUGAS
        Expanded(
          child: tasks.isEmpty
              ? const Center(
                  child: Text(
                    "Belum ada tugas.Tambahkan tugas di atas!",
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    // Dismissible = swipe untuk hapus
                    return Dismissible(
                      key: Key(task['name']),
                      background: Container(color: Colors.red),
                      onDismissed: (_) => setState(() => tasks.removeAt(index)),
                      child: Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          // Avatar warna berdasarkan prioritas
                          leading: CircleAvatar(
                            backgroundColor: _getColor(task['priority']),
                            child: Text(
                              task['name'][0].toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(
                            task['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            "${task['duration']} Menit • ${task['priority']}",
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => setState(() => tasks.removeAt(index)),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    ),
    // FAB GENERATE AI
    floatingActionButton: FloatingActionButton.extended(
      onPressed: isLoading ? null : _generateSchedule,
      icon: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(color: Colors.white),
            )
          : const Icon(Icons.auto_awesome),
      label: Text(isLoading ? "Memproses..." : "Buat Jadwal AI"),
    ),
  );
}
Color _getColor(String priority) {
  if (priority == "Tinggi") return Colors.red;
  if (priority == "Sedang") return Colors.orange;
  return Colors.green;
}
}
