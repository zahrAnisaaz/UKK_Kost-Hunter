import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReviewSection extends StatefulWidget {
  final String kostId;
  const ReviewSection({super.key, required this.kostId, required userId});

  @override
  _ReviewPageState createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewSection> {
  final supabase = Supabase.instance.client;
  final TextEditingController _commentController = TextEditingController();
  int _rating = 0;
  List<Map<String, dynamic>> _reviews = [];

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    final response = await supabase
        .from('reviews')
        .select('*, user_id')
        .eq('kost_id', widget.kostId)
        .order('created_at', ascending: false);

    setState(() {
      _reviews = List<Map<String, dynamic>>.from(response);
    });
  }

  Future<void> _submitReview() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Kamu harus login untuk memberi review.')));
      return;
    }

    if (_rating == 0 || _commentController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Isi rating dan komentar dulu!')));
      return;
    }

    await supabase.from('reviews').insert({
      'kost_id': widget.kostId,
      'user_id': user.id,
      'rating': _rating,
      'komentar': _commentController.text,
    });

    _commentController.clear();
    setState(() => _rating = 0);
    await _loadReviews();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Ulasan Pengguna",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // Daftar review
            if (_reviews.isEmpty)
              const Text("Belum ada review.", style: TextStyle(color: Colors.grey))
            else
              Column(
                children: _reviews.map((r) {
                  return ListTile(
                    leading: Icon(Icons.person, color: Colors.blueAccent),
                    title: Row(
                      children: [
                        ...List.generate(5, (i) {
                          return Icon(
                            i < r['rating'] ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 18,
                          );
                        }),
                      ],
                    ),
                    subtitle: Text(r['komentar']),
                  );
                }).toList(),
              ),
            const Divider(height: 30),

            // Form tambah review
            const Text("Beri Ulasan:", style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (i) {
                return IconButton(
                  icon: Icon(
                    i < _rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                  ),
                  onPressed: () => setState(() => _rating = i + 1),
                );
              }),
            ),
            TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                hintText: "Tulis komentar kamu...",
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _submitReview,
              child: const Text("Kirim Review"),
            ),
          ],
        ),
      ),
    );
  }
}
