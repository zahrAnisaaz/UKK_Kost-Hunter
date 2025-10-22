import 'package:flutter/material.dart';
import 'package:kost_hunter/society/ChatPage.dart';
import 'package:kost_hunter/society/BookingPage.dart';
import 'package:kost_hunter/society/ReviewPage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DetailKostPage extends StatefulWidget {
  final Map<String, dynamic> kost;
   final String userId; // ⬅️ Tambahkan ini

  const DetailKostPage({
    super.key,
    required this.kost,
    required this.userId, // ⬅️ Dan ubah jadi this.userId
  });

  @override
  State<DetailKostPage> createState() => _DetailKostPageState();
}

class _DetailKostPageState extends State<DetailKostPage> {
  late final SupabaseClient supabase;
  String? userId;

  @override
  void initState() {
    super.initState();
    supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    userId = user?.id;
    print('Current user ID: $userId');
  }

  void _openChat(BuildContext context) {
    if (userId == null) {
      _showLoginAlert();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          kostId: widget.kost['id'].toString(),
          kostName: widget.kost['nama_kost'] ?? '',
        ),
      ),
    );
  }

  void _goToBooking(BuildContext context) {
    if (userId == null) {
      _showLoginAlert();
      return;
    }

    // 👉 Tidak ada insert ke tabel booking di sini!
    // Langsung navigasi ke BookingPage.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookingPage(
          userId: userId!,
          kost: widget.kost,
        ),
      ),
    );
  }

  void _showLoginAlert() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Silakan login terlebih dahulu.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kost = widget.kost;
    final isWide = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(kost['nama_kost'] ?? 'Detail Kost'),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// --- Gambar utama ---
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: isWide ? 21 / 9 : 16 / 9,
                    child: Image.network(
                      kost['gambar'] ?? '',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey[300],
                        child: const Center(
                          child: Icon(Icons.image_not_supported, size: 80),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                /// --- Info Kost ---
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          kost['nama_kost'] ?? '',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.location_on,
                                color: Colors.redAccent, size: 18),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                kost['alamat'] ?? 'Alamat tidak tersedia',
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.attach_money, color: Colors.green),
                            const SizedBox(width: 4),
                            Text(
                              "Rp${kost['harga']}/bulan",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 30),
                        Text(
                          "Fasilitas",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[800],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          kost['fasilitas'] ?? 'Tidak ada data fasilitas.',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Deskripsi",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[800],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          kost['deskripsi'] ?? 'Belum ada deskripsi.',
                          style: const TextStyle(fontSize: 16, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                /// --- Tombol Chat & Booking ---
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _openChat(context),
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text(
                          "Chat Pemilik",
                          style: TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orangeAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _goToBooking(context),
                        icon: const Icon(Icons.book_online),
                        label: const Text(
                          "Booking Kost",
                          style: TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                /// --- Review Section ---
                ReviewSection(
                  kostId: kost['id'].toString(),
                  userId: userId,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
