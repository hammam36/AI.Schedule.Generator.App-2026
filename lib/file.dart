// membuat file untuk menampilkan data dari API
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class File extends StatefulWidget {
  const File({Key? key}) : super(key: key); // Constructor untuk widget File

  @override
  _FileState createState() => _FileState(); // Membuat state untuk widget File
} // class File ends here
// membuat state untuk widget File
class _FileState extends State<File> {
  List data = []; // List untuk menyimpan data dari API

  @override
  void initState() {
    super.initState();
    fetchData(); // Memanggil fungsi fetchData saat state diinisialisasi
  }

  Future<void> fetchData() async {
    final response = await http.get(Uri.parse('https://jsonplaceholder.typicode.com/posts'));
    if (response.statusCode == 200) {
      setState(() {
        data = json.decode(response.body); // Mengubah response body menjadi list
      });
    } else {
      throw Exception('Failed to load data'); // Menangani error jika request gagal
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data dari API'),
      ),
      body: ListView.builder(
        itemCount: data.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(data[index]['title'].toString()),
            subtitle: Text(data[index]['body'].toString()),
          );
        },
      ),
    );
  }
}