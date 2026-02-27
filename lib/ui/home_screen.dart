// lib/ui/home_screen.dart
import 'package:ai_schedule_generator/auth/google_auth.dart';
import 'package:flutter/material.dart';
import 'package:ai_schedule_generator/services/gemini_service.dart';
import 'schedule_result_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ★ simpan user yang sedang login
  GoogleSignInAccount? _currentUser;

  final List<Map<String, dynamic>> tasks = [];
  final TextEditingController taskController = TextEditingController();
  final TextEditingController durationController = TextEditingController();
  String? priority;
  bool isLoading = false;

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
    super.dispose();
  }

  void _addTask() {
    if (taskController.text.isNotEmpty &&
        durationController.text.isNotEmpty &&
        priority != null) {
      setState(() {
        tasks.add({
          "name": taskController.text,
          "priority": priority!,
          "duration": int.tryParse(durationController.text) ?? 30,
        });
      });
      taskController.clear();
      durationController.clear();
      setState(() => priority = null);
    }
  }

  void _generateSchedule() async {
    if (tasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠ Harap tambahkan tugas dulu!")),
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
          builder: (context) => ScheduleResultScreen(scheduleResult: schedule),
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

  // ★ AppBar sekarang punya tombol login / profil
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Schedule Generator"),
        actions: [
          if (_currentUser == null)
            IconButton(
              icon: const Icon(Icons.login),
              tooltip: 'Login dengan Google',
              onPressed: () async {
                final account = await signInWithGoogle();
                if (!mounted) return;

                if (account == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Login dibatalkan')),
                  );
                  return;
                }

                setState(() {
                  _currentUser = account;
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Halo, ${account.displayName ?? account.email}',
                    ),
                  ),
                );
              },
            )
          else
            PopupMenuButton<String>(
              icon: const Icon(Icons.account_circle),
              onSelected: (value) async {
                if (value == 'logout') {
                  await signOutFromGoogle();
                  if (!mounted) return;
                  setState(() {
                    _currentUser = null;
                  });
                }
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
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: priority,
                          decoration: const InputDecoration(
                            labelText: "Prioritas",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.flag),
                          ),
                          items: ["Tinggi", "Sedang", "Rendah"]
                              .map(
                                (e) =>
                                    DropdownMenuItem(value: e, child: Text(e)),
                              )
                              .toList(),
                          onChanged: (val) => setState(() => priority = val),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
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
                      return Dismissible(
                        key: Key(task['name']),
                        background: Container(color: Colors.red),
                        onDismissed: (_) =>
                            setState(() => tasks.removeAt(index)),
                        child: Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getColor(task['priority']),
                              child: Text(
                                task['name'][0].toUpperCase(),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(
                              task['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              "${task['duration']} Menit • ${task['priority']}",
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () =>
                                  setState(() => tasks.removeAt(index)),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
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
