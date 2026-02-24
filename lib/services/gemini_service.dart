import 'dart:convert';
import 'package:ai_schedule_generator/config/secret.dart';
import 'package:http/http.dart' as http;

class GeminiService {
  // API Key - development (ingat: ini sebaiknya nanti dipindah ke file secret yang tidak di-commit)
  static const String apiKey = geminiApiKey;

  static const String baseUrl =
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent";

  static Future<String> generateSchedule(
    List<Map<String, dynamic>> tasks,
  ) async {
    try {
      final prompt = _buildPrompt(tasks);

      final url = Uri.parse('$baseUrl?key=$apiKey');

      final requestBody = {
        "contents": [
          {
            "parts": [
              {"text": prompt},
            ],
          },
        ],
        "generationConfig": {
          "temperature": 0.7,
          "topK": 40,
          "topP": 0.95,
          "maxOutputTokens": 3024,
        },
      };

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["candidates"] != null &&
            data["candidates"].isNotEmpty &&
            data["candidates"][0]["content"] != null &&
            data["candidates"][0]["content"]["parts"] != null &&
            data["candidates"][0]["content"]["parts"].isNotEmpty) {
          return data["candidates"][0]["content"]["parts"][0]["text"] as String;
        }
        return "Tidak ada jadwal yang dihasilkan dari AI.";
      } else {
        print(
          "API Error - Status: ${response.statusCode}, Body: ${response.body}",
        );
        if (response.statusCode == 429) {
          throw Exception(
            "Rate limit tercapai (429). Tunggu beberapa menit atau upgrade quota.",
          );
        }
        if (response.statusCode == 401) {
          throw Exception("API key tidak valid (401). Periksa key Anda.");
        }
        if (response.statusCode == 400) {
          throw Exception("Request salah format (400): ${response.body}");
        }
        throw Exception(
          "Gagal memanggil Gemini API (Code: ${response.statusCode})",
        );
      }
    } catch (e) {
      print("Exception saat generate schedule: $e");
      throw Exception("Error saat generate jadwal: $e");
    }
  }

  static String _buildPrompt(List<Map<String, dynamic>> tasks) {
    String taskList = tasks
        .map((e) => "- ${e['name']} (${e['duration']} menit)")
        .join("\n");

    return """
Kamu adalah asisten produktivitas yang menyusun jadwal harian yang singkat, efisien, dan menyenangkan.

Berikut daftar tugas yang harus dijadwalkan hari ini:
$taskList

Buat OUTPUT dalam format MARKDOWN dengan struktur PERSIS seperti ini:

## JADWAL UNTUK KALENDER

- HANYA berisi tabel jadwal yang akan diekspor ke Google Calendar.
- Gunakan satu tabel dengan kolom: Waktu, Kegiatan, Keterangan.
- Format kolom Waktu SELALU "HH:MM - HH:MM" (24 jam), contoh: "07:00 - 07:30".
- Kolom Kegiatan adalah nama kegiatan singkat, misalnya "Belajar Matematika", "Makan", "Jalan-jalan".
- Kolom Keterangan berisi penjelasan singkat (boleh pakai emoji).
- Jangan menulis teks lain di luar tabel pada bagian ini (tidak ada paragraf tambahan).

## TIPS PRODUKTIF

- Di bagian ini, tulis paragraf singkat dan/atau bullet point berisi tips agar pengguna makin produktif.
- Tips harus menyesuaikan dengan daftar kegiatan di tabel jadwal.
- Boleh menggunakan emoji dan gaya bahasa yang menyemangati.
""";
  }
}
