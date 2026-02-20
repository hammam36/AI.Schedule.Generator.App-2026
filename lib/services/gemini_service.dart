import 'dart:convert'; // Untuk encode/decode JSON
import 'package:http/http.dart' as http;

class GeminiService {
  // API Key - GANTI dengan milikmu (jangan hardcode di production!)
  static const String apiKey = "AIzaSyApSgU8yCxI7JMAtvCwhW__FAFmfGn1ma0";

  // Gunakan model stabil terbaru (per 2026: gemini-1.5-flash atau gemini-1.5-flash-latest)
  // Endpoint Gemini API (generateContent)
  static const String baseUrl =
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent";

  static Future<String> generateSchedule(
    List<Map<String, dynamic>> tasks,
  ) async {
    try {
      // Bangun prompt dari data tugas
      final prompt = _buildPrompt(tasks);

      // Siapkan URL dengan API key sebagai query param
      final url = Uri.parse('$baseUrl?key=$apiKey');

      // Body request sesuai spec resmi Gemini
      final requestBody = {
        "contents": [
          {
            "parts": [
              {"text": prompt},
            ],
          },
        ],
        // Optional: tambah konfigurasi (temperature, maxOutputTokens, dll)
        "generationConfig": {
          "temperature": 0.7,
          "topK": 40,
          "topP": 0.95,
          "maxOutputTokens": 1024,
        },
      };

      // Kirim POST request
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      // Handle response
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

  // Fungsi untuk membentuk prompt (Prompt Engineering)
  static String _buildPrompt(List<Map<String, dynamic>> tasks) {
    // Ubah list tugas menjadi format teks terstruktur
    String taskList = tasks
        .map((e) => "- ${e['name']} (${e['duration']} menit)")
        .join("\n");

    // Instruksi ke AI
    return """
Buatkan jadwal harian yang efisien berdasarkan tugas berikut:
$taskList

PENTING:
1. Sajikan output dalam format Markdown Table dengan kolom: Waktu, Kegiatan, Keterangan.
2. Tambahkan emoji yang relevan.
3. Berikan intro singkat semangat dan tips di bagian bawah (di luar tabel).
""";
  }
}
