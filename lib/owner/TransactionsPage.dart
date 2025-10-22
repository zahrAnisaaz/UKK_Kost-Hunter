import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  final supabase = Supabase.instance.client;
  List<dynamic> payments = [];
  List<dynamic> kostList = [];
  bool loading = true;
  String? selectedKostId;
  DateTimeRange? filterRange;

  @override
  void initState() {
    super.initState();
    loadAll();
  }

  Future<void> loadAll() async {
    setState(() => loading = true);
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      // Ambil semua kost milik owner
      final k = await supabase.from('kost').select().eq('owner_id', user.id);
      setState(() {
        kostList = k;
        selectedKostId = kostList.isNotEmpty ? kostList[0]['id'].toString() : null;
      });
      await fetchPayments();
    } catch (e) {
      debugPrint('Error loadAll: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> fetchPayments() async {
    if (selectedKostId == null) {
      setState(() => payments = []);
      return;
    }

    setState(() => loading = true);
    try {
      // Ambil semua pembayaran + data booking terkait
      final resp = await supabase
          .from('payments')
          .select('*, booking:booking_id(*)')
          .order('created_at', ascending: false);

      // Filter manual berdasarkan kost_id
      List filtered = (resp as List).where((p) {
        final booking = p['booking'];
        return booking != null && booking['kost_id'].toString() == selectedKostId.toString();
      }).toList();

      // Filter tambahan berdasarkan rentang tanggal (jika ada)
      if (filterRange != null) {
        filtered = filtered.where((p) {
          final dateStr = p['payment_date'] ?? p['created_at'];
          if (dateStr == null) return false;
          final date = DateTime.parse(dateStr.toString());
          return date.isAfter(filterRange!.start.subtract(const Duration(days: 1))) &&
              date.isBefore(filterRange!.end.add(const Duration(days: 1)));
        }).toList();
      }

      setState(() => payments = filtered);
    } catch (e) {
      debugPrint('Error fetchPayments: $e');
      setState(() => payments = []);
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> approvePayment(String paymentId, String bookingId, bool approved) async {
    try {
      await supabase
          .from('payments')
          .update({'payment_status': approved ? 'approved' : 'rejected'})
          .eq('id', paymentId);

      // Ubah status booking juga
      await supabase
          .from('bookings')
          .update({'status': approved ? 'diterima' : 'ditolak'})
          .eq('id', bookingId);

      await fetchPayments();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approved ? 'Pembayaran disetujui ✅' : 'Pembayaran ditolak ❌')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
    }
  }

  Future<void> pickFilterRange() async {
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1, now.day);

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      initialDateRange: filterRange ?? DateTimeRange(start: lastMonth, end: now),
    );

    if (picked != null) {
      setState(() => filterRange = picked);
      await fetchPayments();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaksi & Pembayaran'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt),
            onPressed: pickFilterRange,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            DropdownButton<String>(
              value: selectedKostId,
              hint: const Text('Pilih Kost'),
              items: kostList
                  .map((k) => DropdownMenuItem(
                        value: k['id'].toString(),
                        child: Text(k['nama_kost']),
                      ))
                  .toList(),
              onChanged: (v) async {
                setState(() => selectedKostId = v);
                await fetchPayments();
              },
            ),
            const SizedBox(height: 10),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : payments.isEmpty
                      ? const Center(child: Text('Belum ada transaksi'))
                      : ListView.builder(
                          itemCount: payments.length,
                          itemBuilder: (context, i) {
                            final p = payments[i];
                            final booking = p['booking'] ?? {};
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(12),
                                leading: (p['bukti_url'] ?? '').toString().isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          p['bukti_url'],
                                          width: 64,
                                          height: 64,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : const Icon(Icons.receipt_long, size: 40),
                                title: Text(
                                  'Rp ${p['amount'] ?? '-'}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  'Metode: ${p['payment_method'] ?? '-'}\n'
                                  'Status: ${p['payment_status'] ?? 'pending'}\n'
                                  'Booking ID: ${booking['id'] ?? '-'}',
                                ),
                                isThreeLine: true,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.check_circle, color: Colors.green),
                                      onPressed: () => approvePayment(
                                        p['id'].toString(),
                                        (booking['id'] ?? p['booking_id']).toString(),
                                        true,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.cancel, color: Colors.red),
                                      onPressed: () => approvePayment(
                                        p['id'].toString(),
                                        (booking['id'] ?? p['booking_id']).toString(),
                                        false,
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
        ),
      ),
    );
  }
}
