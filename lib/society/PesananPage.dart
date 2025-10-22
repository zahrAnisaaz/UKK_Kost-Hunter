import 'package:flutter/material.dart';
import 'package:kost_hunter/society/BookingPage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kost_hunter/society/DetailKostPage.dart';

class PesananPage extends StatefulWidget {
  const PesananPage({super.key});

  @override
  State<PesananPage> createState() => _PesananPageState();
}

class _PesananPageState extends State<PesananPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> pesananList = [];
  bool isLoading = true;
  RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    fetchPesanan();
    setupRealtime();
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }

  // 🔹 Ambil semua pesanan user
  Future<void> fetchPesanan() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => isLoading = true);

    final data = await supabase
        .from('bookings')
        .select(
            'id, status, tanggal_booking, nama_penyewa, nomor_hp, kost(id, nama_kost, gambar, alamat)')
        .eq('user_id', userId)
        .order('tanggal_booking', ascending: false);

    setState(() {
      pesananList = List<Map<String, dynamic>>.from(data);
      isLoading = false;
    });
  }

  // 🔹 Realtime listener (insert/update/delete)
  void setupRealtime() {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    _subscription = supabase.channel('realtime:bookings')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'bookings',
        callback: (payload) {
          final newUserId = payload.newRecord['user_id'];
          if (newUserId == userId) fetchPesanan();
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'bookings',
        callback: (payload) {
          final updatedUserId = payload.newRecord['user_id'];
          if (updatedUserId == userId) fetchPesanan();
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.delete,
        schema: 'public',
        table: 'bookings',
        callback: (payload) {
          final deletedUserId = payload.oldRecord['user_id'];
          if (deletedUserId == userId) fetchPesanan();
        },
      )
      ..subscribe();
  }

  // 🔹 Hapus booking
  Future<void> deleteBooking(String bookingId) async {
    try {
      await supabase.from('bookings').delete().eq('id', bookingId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking berhasil dihapus'),
          backgroundColor: Colors.green,
        ),
      );
      fetchPesanan();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menghapus booking: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = supabase.auth.currentUser?.id ?? '';

    return Scaffold(
        appBar: AppBar(
          title: const Text('Status Pesanan'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : pesananList.isEmpty
                ? const Center(child: Text('Belum ada pesanan 📭'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: pesananList.length,
                    itemBuilder: (context, index) {
                      final pesanan = pesananList[index];
                      final kost = pesanan['kost'] ?? {};
                      final status = pesanan['status'] ?? 'menunggu';

                      Color statusColor;
                      switch (status) {
                        case 'diterima':
                          statusColor = Colors.green;
                          break;
                        case 'ditolak':
                          statusColor = Colors.red;
                          break;
                        default:
                          statusColor = Colors.grey;
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 3,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Gambar Kost
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  kost['gambar'] ??
                                      'https://via.placeholder.com/150?text=No+Image',
                                  width: 70,
                                  height: 70,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Informasi dan tombol
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      kost['nama_kost'] ?? '-',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(kost['alamat'] ?? '-'),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Status: $status',
                                      style: TextStyle(
                                        color: statusColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Penyewa: ${pesanan['nama_penyewa'] ?? '-'} | HP: ${pesanan['nomor_hp'] ?? '-'}',
                                    ),
                                    const SizedBox(height: 8),

                                    // Tombol-tombol aksi
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: [
                                        ElevatedButton(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => DetailKostPage(
                                                  kost: kost,
                                                  userId: userId,
                                                ),
                                              ),
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue,
                                            foregroundColor: Colors.white,
                                            minimumSize: const Size(90, 36),
                                          ),
                                          child: const Text('Detail'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => BookingPage(
                                                  kost: kost,
                                                  userId: userId,
                                                  existingBooking: pesanan,
                                                ),
                                              ),
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.orange,
                                            foregroundColor: Colors.white,
                                            minimumSize: const Size(90, 36),
                                          ),
                                          child: const Text('Edit'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (_) => AlertDialog(
                                                title:
                                                    const Text('Hapus Booking'),
                                                content: const Text(
                                                    'Apakah kamu yakin ingin menghapus booking ini?'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(context),
                                                    child: const Text('Batal'),
                                                  ),
                                                  ElevatedButton(
                                                    onPressed: () {
                                                      Navigator.pop(context);
                                                      deleteBooking(
                                                          pesanan['id']
                                                              .toString());
                                                    },
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                            backgroundColor:
                                                                Colors.red),
                                                    child: const Text('Hapus'),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                            minimumSize: const Size(90, 36),
                                          ),
                                          child: const Text('Hapus'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }));
  }
}
