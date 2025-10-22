import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentPage extends StatefulWidget {
  final Map booking;
  const PaymentPage({super.key, required this.booking});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  String? selectedMethod;
  File? proofImage;
  bool isLoading = false;

  // ✅ fungsi pilih gambar
  Future<void> pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => proofImage = File(picked.path));
    }
  }

  // ✅ fungsi upload pembayaran ke Supabase
  Future<void> uploadPayment() async {
    if (selectedMethod == null || proofImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pilih metode & unggah bukti pembayaran dulu.")),
      );
      return;
    }

    setState(() => isLoading = true);
    final supabase = Supabase.instance.client;

    try {
      // nama file unik (timestamp)
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${proofImage!.path.split('/').last}';

      // ✅ upload ke storage bucket "payments"
      await supabase.storage.from('payments').upload(fileName, proofImage!);

      // dapatkan URL publik untuk ditampilkan di aplikasi / disimpan ke DB
      final imageUrl = supabase.storage.from('payments').getPublicUrl(fileName);

      // ✅ simpan data pembayaran ke tabel "payments"
      await supabase.from('payments').insert({
        'booking_id': widget.booking['id'], // dari data booking sebelumnya
        'metode': selectedMethod,
        'jumlah': widget.booking['total'],
        'bukti_url': imageUrl,
        'status': 'pending', // default masih nunggu verifikasi owner
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pembayaran berhasil dikirim! Menunggu verifikasi.")),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pembayaran")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Total Bayar: Rp${widget.booking['total']}",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            const Text("Pilih Metode Pembayaran:"),
            DropdownButton<String>(
              isExpanded: true,
              value: selectedMethod,
              hint: const Text("Pilih metode"),
              items: const [
                DropdownMenuItem(value: "Transfer Bank", child: Text("Transfer Bank")),
                DropdownMenuItem(value: "QRIS", child: Text("QRIS")),
                DropdownMenuItem(value: "E-Wallet", child: Text("E-Wallet")),
              ],
              onChanged: (value) => setState(() => selectedMethod = value),
            ),
            const SizedBox(height: 20),

            const Text("Upload Bukti Pembayaran:"),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: pickImage,
              child: Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: proofImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(proofImage!, fit: BoxFit.cover),
                      )
                    : const Icon(Icons.camera_alt, size: 50, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 30),

            ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_outline),
              label: Text(isLoading ? "Mengirim..." : "Kirim Pembayaran"),
              onPressed: isLoading ? null : uploadPayment,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
