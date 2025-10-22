import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:ui' as ui;
import 'package:qr/qr.dart';

class BookingPage extends StatefulWidget {
  final Map<String, dynamic> kost;
  final String userId;
  final Map<String, dynamic>? existingBooking; // opsional untuk edit

  const BookingPage({
    super.key,
    required this.kost,
    required this.userId,
    this.existingBooking,
  });

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  String namaLengkap = '';
  String nomorHp = '';
  String catatan = '';
  String paymentMethod = 'Transfer Bank';
  DateTime? tanggalMasuk;
  bool isBooking = false;
  bool isLoading = true;
  bool hasBooking = false;
  Map<String, dynamic>? bookingData;

  @override
  void initState() {
    super.initState();
    if (widget.existingBooking != null) {
      // Edit booking
      namaLengkap = widget.existingBooking!['nama_penyewa'] ?? '';
      nomorHp = widget.existingBooking!['nomor_hp'] ?? '';
      catatan = widget.existingBooking!['catatan'] ?? '';
      tanggalMasuk =
          DateTime.parse(widget.existingBooking!['tanggal_masuk']);
      paymentMethod =
          widget.existingBooking!['payment_method'] ?? 'Transfer Bank';
      hasBooking = true;
      bookingData = widget.existingBooking;
      isLoading = false;
    } else {
      Future.delayed(Duration.zero, () => checkUserBooking());
    }
  }

  Future<void> checkUserBooking() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final response = await supabase
          .from('bookings')
          .select(
              'id, nama_penyewa, nomor_hp, tanggal_masuk, catatan, payment_method')
          .eq('user_id', user.id)
          .eq('kost_id', widget.kost['id'])
          .maybeSingle();

      if (mounted) {
        setState(() {
          hasBooking = response != null;
          bookingData =
              response != null ? response as Map<String, dynamic> : null;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      print('Error check booking: $e');
    }
  }

  Future<void> pickTanggalMasuk() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: tanggalMasuk ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => tanggalMasuk = picked);
    }
  }

  Future<void> saveBooking() async {
    if (!_formKey.currentState!.validate()) return;
    if (tanggalMasuk == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih tanggal masuk dulu ya!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    _formKey.currentState!.save();
    setState(() => isBooking = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      if (widget.existingBooking != null || hasBooking) {
        // Update booking
        final id = widget.existingBooking != null
            ? widget.existingBooking!['id']
            : bookingData!['id'];

        await supabase.from('bookings').update({
          'nama_penyewa': namaLengkap,
          'nomor_hp': nomorHp,
          'tanggal_masuk': tanggalMasuk!.toIso8601String(),
          'catatan': catatan,
          'payment_method': paymentMethod,
        }).eq('id', id);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking berhasil diperbarui! 🎉'),
            backgroundColor: Colors.green,
          ),
        );
        bookingData = {
          'id': id,
          'nama_penyewa': namaLengkap,
          'nomor_hp': nomorHp,
          'tanggal_masuk': tanggalMasuk!.toIso8601String(),
          'catatan': catatan,
          'payment_method': paymentMethod,
        };
        setState(() => hasBooking = true);
      } else {
        // Insert baru
        final bookingResponse = await supabase
            .from('bookings')
            .insert({
              'society_id': widget.kost['owner_id'],
              'user_id': user.id,
              'kost_id': widget.kost['id'],
              'nama_penyewa': namaLengkap,
              'nomor_hp': nomorHp,
              'tanggal_masuk': tanggalMasuk!.toIso8601String(),
              'catatan': catatan,
              'total_price': widget.kost['harga'],
              'status': 'booked',
            })
            .select()
            .single();

        final bookingId = bookingResponse['id'];

        await supabase.from('payments').insert({
          'booking_id': bookingId,
          'payment_method': paymentMethod,
          'payment_status': 'pending',
          'amount': widget.kost['harga'],
        });

        bookingData = {
          ...bookingResponse,
          'payment_method': paymentMethod,
          'total_price': widget.kost['harga'],
        };
        setState(() => hasBooking = true);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking berhasil! 🎉'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan booking: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isBooking = false);
    }
  }

  Future<void> printBookingReceipt() async {
    if (bookingData == null) return;

    final pdf = pw.Document();

    final qrValidation = QrValidator.validate(
      data: 'bookingId:${bookingData!['id']}',
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.Q,
    );
    final qrCode = qrValidation.qrCode!;
    final qrImage = await QrPainter.withQr(
      qr: qrCode,
      color: const ui.Color(0xFF000000),
      emptyColor: const ui.Color(0xFFFFFFFF),
      gapless: true,
    ).toImageData(200);

    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Bukti Pemesanan',
                style:
                    pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 16),
            pw.Text(widget.kost['nama_kost'] ?? '-',
                style:
                    pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.Text('Alamat: ${widget.kost['alamat']}'),
            pw.Text('Nama Penyewa: ${bookingData!['nama_penyewa']}'),
            pw.Text('Nomor HP: ${bookingData!['nomor_hp']}'),
            pw.Text(
                'Tanggal Masuk: ${bookingData!['tanggal_masuk'].toString().split('T')[0]}'),
            pw.Text('Metode Pembayaran: ${bookingData!['payment_method']}'),
            pw.Text('Total Harga: Rp${bookingData!['total_price']}'),
            pw.SizedBox(height: 20),
            pw.Center(
              child: pw.Image(
                pw.MemoryImage(qrImage!.buffer.asUint8List()),
                width: 150,
                height: 150,
              ),
            ),
            pw.Center(child: pw.Text('Scan QR untuk cek booking online')),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    final kost = widget.kost;

    return Scaffold(
      appBar: AppBar(
        title: Text(kost['nama_kost'] ?? 'Booking Kost'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blueAccent, Colors.indigo],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 4,
      ),
      body: isLoading && !hasBooking
          ? const Center(child: CircularProgressIndicator())
          : hasBooking
              ? buildBookingInfo()
              : buildBookingForm(),
    );
  }

  Widget buildBookingInfo() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Kamu sudah booking kost ini 🏡\nSilakan cek bukti pemesanan di bawah.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.edit),
              label: const Text('Edit Booking'),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BookingPage(
                      kost: widget.kost,
                      userId: widget.userId,
                      existingBooking: bookingData,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.receipt_long),
              label: const Text('Lihat & Cetak Bukti Pemesanan'),
              onPressed: printBookingReceipt,
            ),
          ],
        ),
      ),
    );
  }

  Widget buildBookingForm() {
    final kost = widget.kost;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth < 600 ? double.infinity : 500,
              ),
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            kost['gambar'] ??
                                'https://via.placeholder.com/400x200?text=No+Image',
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          kost['nama_kost'] ?? '-',
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          kost['alamat'] ?? '-',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Rp${kost['harga']}/bulan",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                        const Divider(height: 30),
                        TextFormField(
                          initialValue: namaLengkap,
                          decoration: const InputDecoration(
                            labelText: 'Nama Lengkap',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                          validator: (v) =>
                              v!.isEmpty ? 'Isi nama lengkap dulu' : null,
                          onSaved: (v) => namaLengkap = v!,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          initialValue: nomorHp,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Nomor HP',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.phone),
                          ),
                          validator: (v) =>
                              v!.isEmpty ? 'Nomor HP wajib diisi' : null,
                          onSaved: (v) => nomorHp = v!,
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: pickTanggalMasuk,
                          icon: const Icon(Icons.calendar_today),
                          label: Text(tanggalMasuk == null
                              ? 'Pilih Tanggal Masuk'
                              : 'Tanggal Masuk: ${tanggalMasuk!.toLocal().toString().split(' ')[0]}'),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: paymentMethod,
                          items: const [
                            DropdownMenuItem(
                                value: 'Transfer Bank',
                                child: Text('Transfer Bank')),
                            DropdownMenuItem(
                                value: 'E-Wallet',
                                child: Text('E-Wallet (OVO/Gopay)')),
                            DropdownMenuItem(
                                value: 'COD', child: Text('Bayar di Tempat')),
                          ],
                          onChanged: (value) =>
                              setState(() => paymentMethod = value!),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Metode Pembayaran',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          initialValue: catatan,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Catatan Tambahan (Opsional)',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                          onSaved: (v) => catatan = v ?? '',
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: isBooking ? null : saveBooking,
                            icon: const Icon(Icons.book_online),
                            label: isBooking
                                ? const Text('Memproses...')
                                : Text(widget.existingBooking != null ||
                                        hasBooking
                                    ? 'Update Booking'
                                    : 'Booking Sekarang'),
                            style: ElevatedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: Colors.indigo,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Center(
                          child: Text(
                            'Status pembayaran akan pending sampai dikonfirmasi pemilik kost.',
                            style: TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}






// import 'package:flutter/material.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:pdf/widgets.dart' as pw;
// import 'package:printing/printing.dart';
// import 'package:qr_flutter/qr_flutter.dart';
// import 'dart:ui' as ui;
// import 'package:qr/qr.dart';

// class BookingPage extends StatefulWidget {
//   final Map<String, dynamic> kost;
//   final String userId;

//   const BookingPage({
//     super.key,
//     required this.kost,
//     required this.userId,
//   });

//   @override
//   State<BookingPage> createState() => _BookingPageState();
// }

// class _BookingPageState extends State<BookingPage> {
//   final supabase = Supabase.instance.client;
//   final _formKey = GlobalKey<FormState>();

//   String namaLengkap = '';
//   String nomorHp = '';
//   String catatan = '';
//   String paymentMethod = 'Transfer Bank';
//   DateTime? tanggalMasuk;
//   bool isBooking = false;
//   bool isLoading = true;
//   bool hasBooking = false;
//   Map<String, dynamic>? bookingData;

//   @override
//   void initState() {
//     super.initState();
//     Future.delayed(Duration.zero, () => checkUserBooking());
//   }

//   Future<void> checkUserBooking() async {
//     final user = supabase.auth.currentUser;
//     if (user == null) return;

//     try {
//       final response = await supabase
//           .from('bookings')
//           .select('id, nama_penyewa, nomor_hp, tanggal_masuk')
//           .eq('user_id', user.id)
//           .eq('kost_id', widget.kost['id'])
//           .maybeSingle();

//       if (mounted) {
//         setState(() {
//           hasBooking = response != null;
//           bookingData =
//               response != null ? response as Map<String, dynamic> : null;
//           isLoading = false;
//         });
//       }
//     } catch (e) {
//       if (mounted) setState(() => isLoading = false);
//       print('Error check booking: $e');
//     }
//   }

//   Future<void> pickTanggalMasuk() async {
//     final picked = await showDatePicker(
//       context: context,
//       initialDate: DateTime.now(),
//       firstDate: DateTime.now(),
//       lastDate: DateTime(2100),
//     );
//     if (picked != null) {
//       setState(() => tanggalMasuk = picked);
//     }
//   }

//   Future<void> bookKost() async {
//     if (!_formKey.currentState!.validate()) return;
//     if (tanggalMasuk == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Pilih tanggal masuk dulu ya!'),
//           backgroundColor: Colors.orange,
//         ),
//       );
//       return;
//     }

//     _formKey.currentState!.save();
//     setState(() => isBooking = true);

//     try {
//       final user = supabase.auth.currentUser;
//       if (user == null) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Kamu belum login!')),
//         );
//         return;
//       }

//       final bookingResponse = await supabase
//           .from('bookings')
//           .insert({
//             'society_id': widget.kost['owner_id'],
//             'user_id': user.id,
//             'kost_id': widget.kost['id'],
//             'nama_penyewa': namaLengkap,
//             'nomor_hp': nomorHp,
//             'tanggal_masuk': tanggalMasuk!.toIso8601String(),
//             'catatan': catatan,
//             'total_price': widget.kost['harga'],
//             'status': 'booked',
//           })
//           .select()
//           .single();

//       final bookingId = bookingResponse['id'];

//       await supabase.from('payments').insert({
//         'booking_id': bookingId,
//         'payment_method': paymentMethod,
//         'payment_status': 'pending',
//         'amount': widget.kost['harga'],
//       });

//       bookingData = {
//         ...bookingResponse,
//         'payment_method': paymentMethod,
//         'total_price': widget.kost['harga'],
//       };

//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Booking berhasil! 🎉'),
//           backgroundColor: Colors.green,
//         ),
//       );

//       setState(() => hasBooking = true);
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Gagal booking: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     } finally {
//       setState(() => isBooking = false);
//     }
//   }

//   // Fungsi print PDF bukti booking + QR code
//   Future<void> printBookingReceipt() async {
//     if (bookingData == null) return;

//     final pdf = pw.Document();

//     final qrValidation = QrValidator.validate(
//       data: 'bookingId:${bookingData!['id']}',
//       version: QrVersions.auto,
//       errorCorrectionLevel: QrErrorCorrectLevel.Q,
//     );
//     final qrCode = qrValidation.qrCode!;
//     final qrImage = await QrPainter.withQr(
//       qr: qrCode,
//       color: const ui.Color(0xFF000000),
//       emptyColor: const ui.Color(0xFFFFFFFF),
//       gapless: true,
//     ).toImageData(200);

//     pdf.addPage(
//       pw.Page(
//         build: (context) => pw.Column(
//           crossAxisAlignment: pw.CrossAxisAlignment.start,
//           children: [
//             pw.Text('Bukti Pemesanan',
//                 style:
//                     pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
//             pw.SizedBox(height: 16),
//             pw.Text(widget.kost['nama_kost'] ?? '-',
//                 style:
//                     pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
//             pw.Text('Alamat: ${widget.kost['alamat']}'),
//             pw.Text('Nama Penyewa: ${bookingData!['nama_penyewa']}'),
//             pw.Text('Nomor HP: ${bookingData!['nomor_hp']}'),
//             pw.Text(
//                 'Tanggal Masuk: ${bookingData!['tanggal_masuk'].toString().split('T')[0]}'),
//             pw.Text('Metode Pembayaran: ${bookingData!['payment_method']}'),
//             pw.Text('Total Harga: Rp${bookingData!['total_price']}'),
//             pw.SizedBox(height: 20),
//             pw.Center(
//               child: pw.Image(
//                 pw.MemoryImage(qrImage!.buffer.asUint8List()),
//                 width: 150,
//                 height: 150,
//               ),
//             ),
//             pw.Center(child: pw.Text('Scan QR untuk cek booking online')),
//           ],
//         ),
//       ),
//     );

//     await Printing.layoutPdf(onLayout: (format) async => pdf.save());
//   }

//   @override
//   Widget build(BuildContext context) {
//     final kost = widget.kost;

//     return Scaffold(
//       appBar: AppBar(
//         title: Text(kost['nama_kost'] ?? 'Booking Kost'),
//         flexibleSpace: Container(
//           decoration: const BoxDecoration(
//             gradient: LinearGradient(
//               colors: [Colors.blueAccent, Colors.indigo],
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//             ),
//           ),
//         ),
//         elevation: 4,
//       ),
//       body: isLoading && !hasBooking
//           ? const Center(child: CircularProgressIndicator())
//           : hasBooking
//               ? buildBookingInfo()
//               : buildBookingForm(),
//     );
//   }

//   // Widget info booking
//   Widget buildBookingInfo() {
//     return Center(
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             const Text(
//               'Kamu sudah booking kost ini 🏡\nSilakan cek bukti pemesanan di bawah.',
//               textAlign: TextAlign.center,
//               style: TextStyle(fontSize: 16, color: Colors.grey),
//             ),
//             const SizedBox(height: 20),
//             ElevatedButton.icon(
//               icon: const Icon(Icons.receipt_long),
//               label: const Text('Lihat & Cetak Bukti Pemesanan'),
//               onPressed: () {
//                 showDialog(
//                   context: context,
//                   builder: (_) => AlertDialog(
//                     title: const Text('Bukti Pemesanan'),
//                     content: SizedBox(
//                       width: double.maxFinite,
//                       child: SingleChildScrollView(
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text('Nama Kost: ${widget.kost['nama_kost']}'),
//                             Text('Alamat: ${widget.kost['alamat']}'),
//                             Text(
//                                 'Nama Penyewa: ${bookingData!['nama_penyewa']}'),
//                             Text('Nomor HP: ${bookingData!['nomor_hp']}'),
//                             Text(
//                                 'Tanggal Masuk: ${bookingData!['tanggal_masuk'].toString().split('T')[0]}'),
//                             Text(
//                                 'Metode Pembayaran: ${bookingData!['payment_method']}'),
//                             Text(
//                                 'Total Harga: Rp${bookingData!['total_price']}'),
//                             const SizedBox(height: 20),
//                             Center(
//                               child: bookingData != null
//                                   ? QrImageView(
//                                       data:
//                                           'bookingId:${bookingData!['id'].toString()}',
//                                       size: 150,
//                                     )
//                                   : const SizedBox(),
//                             )
//                           ],
//                         ),
//                       ),
//                     ),
//                     actions: [
//                       TextButton(
//                         onPressed: () => Navigator.pop(context),
//                         child: const Text('Tutup'),
//                       ),
//                       ElevatedButton.icon(
//                         icon: const Icon(Icons.print),
//                         label: const Text('Cetak PDF'),
//                         onPressed: () {
//                           Navigator.pop(context);
//                           printBookingReceipt();
//                         },
//                       ),
//                     ],
//                   ),
//                 );
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // Widget form booking
//   Widget buildBookingForm() {
//     final kost = widget.kost;
//     return SingleChildScrollView(
//       padding: const EdgeInsets.all(16),
//       child: LayoutBuilder(
//         builder: (context, constraints) {
//           return Center(
//             child: ConstrainedBox(
//               constraints: BoxConstraints(
//                 maxWidth: constraints.maxWidth < 600 ? double.infinity : 500,
//               ),
//               child: Card(
//                 elevation: 6,
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(16),
//                 ),
//                 child: Padding(
//                   padding: const EdgeInsets.all(20),
//                   child: Form(
//                     key: _formKey,
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         ClipRRect(
//                           borderRadius: BorderRadius.circular(16),
//                           child: Image.network(
//                             kost['gambar'] ??
//                                 'https://via.placeholder.com/400x200?text=No+Image',
//                             height: 200,
//                             width: double.infinity,
//                             fit: BoxFit.cover,
//                           ),
//                         ),
//                         const SizedBox(height: 16),
//                         Text(
//                           kost['nama_kost'] ?? '-',
//                           style: const TextStyle(
//                               fontSize: 22, fontWeight: FontWeight.bold),
//                         ),
//                         Text(
//                           kost['alamat'] ?? '-',
//                           style: TextStyle(color: Colors.grey[700]),
//                         ),
//                         const SizedBox(height: 10),
//                         Text(
//                           "Rp${kost['harga']}/bulan",
//                           style: const TextStyle(
//                               fontWeight: FontWeight.bold, color: Colors.green),
//                         ),
//                         const Divider(height: 30),
//                         TextFormField(
//                           decoration: const InputDecoration(
//                             labelText: 'Nama Lengkap',
//                             border: OutlineInputBorder(),
//                             prefixIcon: Icon(Icons.person),
//                           ),
//                           validator: (v) =>
//                               v!.isEmpty ? 'Isi nama lengkap dulu' : null,
//                           onSaved: (v) => namaLengkap = v!,
//                         ),
//                         const SizedBox(height: 16),
//                         TextFormField(
//                           keyboardType: TextInputType.phone,
//                           decoration: const InputDecoration(
//                             labelText: 'Nomor HP',
//                             border: OutlineInputBorder(),
//                             prefixIcon: Icon(Icons.phone),
//                           ),
//                           validator: (v) =>
//                               v!.isEmpty ? 'Nomor HP wajib diisi' : null,
//                           onSaved: (v) => nomorHp = v!,
//                         ),
//                         const SizedBox(height: 16),
//                         OutlinedButton.icon(
//                           onPressed: pickTanggalMasuk,
//                           icon: const Icon(Icons.calendar_today),
//                           label: Text(tanggalMasuk == null
//                               ? 'Pilih Tanggal Masuk'
//                               : 'Tanggal Masuk: ${tanggalMasuk!.toLocal().toString().split(' ')[0]}'),
//                         ),
//                         const SizedBox(height: 16),
//                         DropdownButtonFormField<String>(
//                           value: paymentMethod,
//                           items: const [
//                             DropdownMenuItem(
//                                 value: 'Transfer Bank',
//                                 child: Text('Transfer Bank')),
//                             DropdownMenuItem(
//                                 value: 'E-Wallet',
//                                 child: Text('E-Wallet (OVO/Gopay)')),
//                             DropdownMenuItem(
//                                 value: 'COD', child: Text('Bayar di Tempat')),
//                           ],
//                           onChanged: (value) =>
//                               setState(() => paymentMethod = value!),
//                           decoration: const InputDecoration(
//                             border: OutlineInputBorder(),
//                             labelText: 'Metode Pembayaran',
//                           ),
//                         ),
//                         const SizedBox(height: 16),
//                         TextFormField(
//                           maxLines: 3,
//                           decoration: const InputDecoration(
//                             labelText: 'Catatan Tambahan (Opsional)',
//                             border: OutlineInputBorder(),
//                             alignLabelWithHint: true,
//                           ),
//                           onSaved: (v) => catatan = v ?? '',
//                         ),
//                         const SizedBox(height: 24),
//                         SizedBox(
//                           width: double.infinity,
//                           child: ElevatedButton.icon(
//                             onPressed: isBooking ? null : bookKost,
//                             icon: const Icon(Icons.book_online),
//                             label: isBooking
//                                 ? const Text('Memproses...')
//                                 : const Text('Booking Sekarang'),
//                             style: ElevatedButton.styleFrom(
//                               padding: const EdgeInsets.symmetric(vertical: 14),
//                               backgroundColor: Colors.indigo,
//                               shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(12)),
//                             ),
//                           ),
//                         ),
//                         const SizedBox(height: 10),
//                         const Center(
//                           child: Text(
//                             'Status pembayaran akan pending sampai dikonfirmasi pemilik kost.',
//                             style: TextStyle(color: Colors.grey),
//                             textAlign: TextAlign.center,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           );
//         },
//       ),
//     );
//   }
// }


// import 'package:flutter/material.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';

// class BookingPage extends StatefulWidget {
//   final Map<String, dynamic> kost;
//   final String userId;

//   const BookingPage({
//     super.key,
//     required this.kost,
//     required this.userId,
//   });

//   @override
//   State<BookingPage> createState() => _BookingPageState();
// }

// class _BookingPageState extends State<BookingPage> {
//   final supabase = Supabase.instance.client;
//   final _formKey = GlobalKey<FormState>();

//   String namaLengkap = '';
//   String nomorHp = '';
//   String catatan = '';
//   String paymentMethod = 'Transfer Bank';
//   DateTime? tanggalMasuk;
//   bool isBooking = false;
//   bool isLoading = true;
//   bool hasBooking = false;

//   @override
//   void initState() {
//     super.initState();
//     checkUserBooking();
//   }

//   Future<void> checkUserBooking() async {
//     final user = supabase.auth.currentUser;
//     if (user == null) return;

//     final response = await supabase
//         .from('bookings')
//         .select('id')
//         .eq('user_id', user.id)
//         .eq('kost_id', widget.kost['id'])
//         .maybeSingle();

//     setState(() {
//       hasBooking = response != null;
//       isLoading = false;
//     });
//   }

//   Future<void> pickTanggalMasuk() async {
//     final picked = await showDatePicker(
//       context: context,
//       initialDate: DateTime.now(),
//       firstDate: DateTime.now(),
//       lastDate: DateTime(2100),
//     );
//     if (picked != null) {
//       setState(() => tanggalMasuk = picked);
//     }
//   }

//   Future<void> bookKost() async {
//     if (!_formKey.currentState!.validate()) return;
//     if (tanggalMasuk == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Pilih tanggal masuk dulu ya!'),
//           backgroundColor: Colors.orange,
//         ),
//       );
//       return;
//     }

//     _formKey.currentState!.save();
//     setState(() => isBooking = true);

//     try {
//       final user = Supabase.instance.client.auth.currentUser;
//       if (user == null) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Kamu belum login!')),
//         );
//         return;
//       }

//       print('Current user ID: ${user.id}');

//       // ✅ Simpan ke tabel bookings (tanpa check_out)
//       final bookingResponse = await supabase.from('bookings').insert({
//         'society_id': widget.kost['owner_id'],
//         'user_id': user.id,
//         'kost_id': widget.kost['id'],
//         'nama_penyewa': namaLengkap,
//         'nomor_hp': nomorHp,
//         'tanggal_masuk': tanggalMasuk!.toIso8601String(),
//         'catatan': catatan,
//         'total_price': widget.kost['harga'],
//         'status': 'booked',
//       }).select('id').single();
      

//       final bookingId = bookingResponse['id'];

//       await supabase.from('payments').insert({
//         'booking_id': bookingId,
//         'payment_method': paymentMethod,
//         'payment_status': 'pending',
//         'amount': widget.kost['harga'],
//       });

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: const Text('Booking berhasil! 🎉'),
//           backgroundColor: Colors.green,
//           behavior: SnackBarBehavior.floating,
//           margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(12),
//           ),
//         ),
//       );

//       setState(() => hasBooking = true);
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Gagal booking: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     } finally {
//       setState(() => isBooking = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final kost = widget.kost;

//     if (isLoading) {
//       return const Scaffold(
//         body: Center(child: CircularProgressIndicator()),
//       );
//     }

//     return Scaffold(
//       appBar: AppBar(
//         title: Text(kost['nama_kost'] ?? 'Booking Kost'),
//         flexibleSpace: Container(
//           decoration: const BoxDecoration(
//             gradient: LinearGradient(
//               colors: [Colors.blueAccent, Colors.indigo],
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//             ),
//           ),
//         ),
//         elevation: 4,
//       ),
//       body: hasBooking
//           ? const Center(
//               child: Text(
//                 'Kamu sudah booking kost ini 🏡\nSilakan cek di halaman Booking Saya.',
//                 textAlign: TextAlign.center,
//                 style: TextStyle(fontSize: 16, color: Colors.grey),
//               ),
//             )
//           : SingleChildScrollView(
//               padding: const EdgeInsets.all(16),
//               child: LayoutBuilder(
//                 builder: (context, constraints) {
//                   return Center(
//                     child: ConstrainedBox(
//                       constraints: BoxConstraints(
//                         maxWidth:
//                             constraints.maxWidth < 600 ? double.infinity : 500,
//                       ),
//                       child: Card(
//                         elevation: 6,
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(16),
//                         ),
//                         child: Padding(
//                           padding: const EdgeInsets.all(20),
//                           child: Form(
//                             key: _formKey,
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 ClipRRect(
//                                   borderRadius: BorderRadius.circular(16),
//                                   child: Image.network(
//                                     kost['gambar'] ??
//                                         'https://via.placeholder.com/400x200?text=No+Image',
//                                     height: 200,
//                                     width: double.infinity,
//                                     fit: BoxFit.cover,
//                                   ),
//                                 ),
//                                 const SizedBox(height: 16),
//                                 Text(
//                                   kost['nama_kost'] ?? '-',
//                                   style: const TextStyle(
//                                       fontSize: 22,
//                                       fontWeight: FontWeight.bold),
//                                 ),
//                                 Text(
//                                   kost['alamat'] ?? '-',
//                                   style: TextStyle(color: Colors.grey[700]),
//                                 ),
//                                 const SizedBox(height: 10),
//                                 Text(
//                                   "Rp${kost['harga']}/bulan",
//                                   style: const TextStyle(
//                                       fontWeight: FontWeight.bold,
//                                       color: Colors.green),
//                                 ),
//                                 const Divider(height: 30),

//                                 // --- FORM BOOKING ---
//                                 TextFormField(
//                                   decoration: const InputDecoration(
//                                     labelText: 'Nama Lengkap',
//                                     border: OutlineInputBorder(),
//                                     prefixIcon: Icon(Icons.person),
//                                   ),
//                                   validator: (v) => v!.isEmpty
//                                       ? 'Isi nama lengkap dulu'
//                                       : null,
//                                   onSaved: (v) => namaLengkap = v!,
//                                 ),
//                                 const SizedBox(height: 16),
//                                 TextFormField(
//                                   keyboardType: TextInputType.phone,
//                                   decoration: const InputDecoration(
//                                     labelText: 'Nomor HP',
//                                     border: OutlineInputBorder(),
//                                     prefixIcon: Icon(Icons.phone),
//                                   ),
//                                   validator: (v) =>
//                                       v!.isEmpty ? 'Nomor HP wajib diisi' : null,
//                                   onSaved: (v) => nomorHp = v!,
//                                 ),
//                                 const SizedBox(height: 16),

//                                 // 📅 Hanya tanggal masuk
//                                 OutlinedButton.icon(
//                                   onPressed: pickTanggalMasuk,
//                                   icon: const Icon(Icons.calendar_today),
//                                   label: Text(tanggalMasuk == null
//                                       ? 'Pilih Tanggal Masuk'
//                                       : 'Tanggal Masuk: ${tanggalMasuk!.toLocal().toString().split(' ')[0]}'),
//                                 ),
//                                 const SizedBox(height: 16),

//                                 DropdownButtonFormField<String>(
//                                   value: paymentMethod,
//                                   items: const [
//                                     DropdownMenuItem(
//                                         value: 'Transfer Bank',
//                                         child: Text('Transfer Bank')),
//                                     DropdownMenuItem(
//                                         value: 'E-Wallet',
//                                         child: Text('E-Wallet (OVO/Gopay)')),
//                                     DropdownMenuItem(
//                                         value: 'COD',
//                                         child: Text('Bayar di Tempat')),
//                                   ],
//                                   onChanged: (value) =>
//                                       setState(() => paymentMethod = value!),
//                                   decoration: const InputDecoration(
//                                     border: OutlineInputBorder(),
//                                     labelText: 'Metode Pembayaran',
//                                   ),
//                                 ),
//                                 const SizedBox(height: 16),

//                                 TextFormField(
//                                   maxLines: 3,
//                                   decoration: const InputDecoration(
//                                     labelText: 'Catatan Tambahan (Opsional)',
//                                     border: OutlineInputBorder(),
//                                     alignLabelWithHint: true,
//                                   ),
//                                   onSaved: (v) => catatan = v ?? '',
//                                 ),

//                                 const SizedBox(height: 24),
//                                 SizedBox(
//                                   width: double.infinity,
//                                   child: ElevatedButton.icon(
//                                     onPressed: isBooking ? null : bookKost,
//                                     icon: const Icon(Icons.book_online),
//                                     label: isBooking
//                                         ? const Text('Memproses...')
//                                         : const Text('Booking Sekarang'),
//                                     style: ElevatedButton.styleFrom(
//                                       padding: const EdgeInsets.symmetric(
//                                           vertical: 14),
//                                       backgroundColor: Colors.indigo,
//                                       shape: RoundedRectangleBorder(
//                                         borderRadius: BorderRadius.circular(12),
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                                 const SizedBox(height: 10),
//                                 const Center(
//                                   child: Text(
//                                     'Status pembayaran akan pending sampai dikonfirmasi pemilik kost.',
//                                     style: TextStyle(color: Colors.grey),
//                                     textAlign: TextAlign.center,
//                                   ),
//                                 )
//                               ],
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                   );
//                 },
//               ),
//             ),
//     );
//   }
// }




// import 'package:flutter/material.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';

// class BookingPage extends StatefulWidget {
//   final Map<String, dynamic> kost;
//   final String userId;

//   const BookingPage({
//     super.key,
//     required this.kost,
//     required this.userId,
//   });

//   @override
//   State<BookingPage> createState() => _BookingPageState();
// }

// class _BookingPageState extends State<BookingPage> {
//   final supabase = Supabase.instance.client;
//   final _formKey = GlobalKey<FormState>();

//   String namaLengkap = '';
//   String nomorHp = '';
//   String catatan = '';
//   String paymentMethod = 'Transfer Bank';
//   DateTime? checkIn;
//   DateTime? checkOut;
//   bool isBooking = false;
//   bool isLoading = true;
//   bool hasBooking = false;

//   @override
//   void initState() {
//     super.initState();
//     checkUserBooking();
//   }

//   Future<void> checkUserBooking() async {
//     final user = supabase.auth.currentUser;
//     if (user == null) return;

//     final response = await supabase
//         .from('bookings')
//         .select('id')
//         .eq('user_id', user.id)
//         .eq('kost_id', widget.kost['id'])
//         .maybeSingle();

//     setState(() {
//       hasBooking = response != null;
//       isLoading = false;
//     });
//   }

//   Future<void> bookKost() async {
//     if (!_formKey.currentState!.validate()) return;
//     if (checkIn == null || checkOut == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Pilih tanggal Check-in dan Check-out dulu ya!'),
//           backgroundColor: Colors.orange,
//         ),
//       );
//       return;
//     }

//     _formKey.currentState!.save();
//     setState(() => isBooking = true);

//     try {
//       final user = Supabase.instance.client.auth.currentUser;
//       if (user == null) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Kamu belum login!')),
//         );
//         return;
//       }

//       print('Current user ID: ${user.id}');

//       final bookingResponse = await supabase.from('bookings').insert({
//         'society_id': widget.kost['owner_id'],
//         'user_id': user.id,
//         'kost_id': widget.kost['id'],
//         'nama_penyewa': namaLengkap,
//         'nomor_hp': nomorHp,
//         'check_in': checkIn!.toIso8601String(),
//         'check_out': checkOut!.toIso8601String(),
//         'catatan': catatan,
//         'total_price': widget.kost['harga'],
//         'status': 'booked',
//       }).select('id').single();

//       final bookingId = bookingResponse['id'];

//       await supabase.from('payments').insert({
//         'booking_id': bookingId,
//         'payment_method': paymentMethod,
//         'payment_status': 'pending',
//         'amount': widget.kost['harga'],
//       });

//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: const Text('Booking berhasil! 🎉'),
//           backgroundColor: Colors.green,
//           behavior: SnackBarBehavior.floating,
//           margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(12),
//           ),
//         ),
//       );

//       setState(() => hasBooking = true);
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Gagal booking: $e'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     } finally {
//       setState(() => isBooking = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final kost = widget.kost;

//     if (isLoading) {
//       return const Scaffold(
//         body: Center(child: CircularProgressIndicator()),
//       );
//     }

//     return Scaffold(
//       appBar: AppBar(
//         title: Text(kost['nama_kost'] ?? 'Booking Kost'),
//         flexibleSpace: Container(
//           decoration: const BoxDecoration(
//             gradient: LinearGradient(
//               colors: [Colors.blueAccent, Colors.indigo],
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//             ),
//           ),
//         ),
//         elevation: 4,
//       ),
//       body: hasBooking
//           ? const Center(
//               child: Text(
//                 'Kamu sudah booking kost ini 🏡\nSilakan cek di halaman Booking Saya.',
//                 textAlign: TextAlign.center,
//                 style: TextStyle(fontSize: 16, color: Colors.grey),
//               ),
//             )
//           : SingleChildScrollView(
//               padding: const EdgeInsets.all(16),
//               child: LayoutBuilder(
//                 builder: (context, constraints) {
//                   return Center(
//                     child: ConstrainedBox(
//                       constraints: BoxConstraints(
//                         maxWidth:
//                             constraints.maxWidth < 600 ? double.infinity : 500,
//                       ),
//                       child: Card(
//                         elevation: 6,
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(16),
//                         ),
//                         child: Padding(
//                           padding: const EdgeInsets.all(20),
//                           child: Form(
//                             key: _formKey,
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 ClipRRect(
//                                   borderRadius: BorderRadius.circular(16),
//                                   child: Image.network(
//                                     kost['gambar'] ??
//                                         'https://via.placeholder.com/400x200?text=No+Image',
//                                     height: 200,
//                                     width: double.infinity,
//                                     fit: BoxFit.cover,
//                                   ),
//                                 ),
//                                 const SizedBox(height: 16),
//                                 Text(
//                                   kost['nama_kost'] ?? '-',
//                                   style: const TextStyle(
//                                       fontSize: 22,
//                                       fontWeight: FontWeight.bold),
//                                 ),
//                                 Text(
//                                   kost['alamat'] ?? '-',
//                                   style: TextStyle(color: Colors.grey[700]),
//                                 ),
//                                 const SizedBox(height: 10),
//                                 Text(
//                                   "Rp${kost['harga']}/bulan",
//                                   style: const TextStyle(
//                                       fontWeight: FontWeight.bold,
//                                       color: Colors.green),
//                                 ),
//                                 const Divider(height: 30),

//                                 // --- FORM BOOKING ---
//                                 TextFormField(
//                                   decoration: const InputDecoration(
//                                     labelText: 'Nama Lengkap',
//                                     border: OutlineInputBorder(),
//                                     prefixIcon: Icon(Icons.person),
//                                   ),
//                                   validator: (v) => v!.isEmpty
//                                       ? 'Isi nama lengkap dulu'
//                                       : null,
//                                   onSaved: (v) => namaLengkap = v!,
//                                 ),
//                                 const SizedBox(height: 16),
//                                 TextFormField(
//                                   keyboardType: TextInputType.phone,
//                                   decoration: const InputDecoration(
//                                     labelText: 'Nomor HP',
//                                     border: OutlineInputBorder(),
//                                     prefixIcon: Icon(Icons.phone),
//                                   ),
//                                   validator: (v) =>
//                                       v!.isEmpty ? 'Nomor HP wajib diisi' : null,
//                                   onSaved: (v) => nomorHp = v!,
//                                 ),
//                                 const SizedBox(height: 16),

//                                 Row(
//                                   children: [
//                                     Expanded(
//                                       child: OutlinedButton.icon(
//                                         onPressed: () => pickDate(true),
//                                         icon: const Icon(Icons.calendar_today),
//                                         label: Text(checkIn == null
//                                             ? 'Pilih Check-In'
//                                             : 'Check-In: ${checkIn!.toLocal().toString().split(' ')[0]}'),
//                                       ),
//                                     ),
//                                     const SizedBox(width: 8),
//                                     Expanded(
//                                       child: OutlinedButton.icon(
//                                         onPressed: () => pickDate(false),
//                                         icon:
//                                             const Icon(Icons.calendar_month),
//                                         label: Text(checkOut == null
//                                             ? 'Pilih Check-Out'
//                                             : 'Check-Out: ${checkOut!.toLocal().toString().split(' ')[0]}'),
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                                 const SizedBox(height: 16),

//                                 DropdownButtonFormField<String>(
//                                   value: paymentMethod,
//                                   items: const [
//                                     DropdownMenuItem(
//                                         value: 'Transfer Bank',
//                                         child: Text('Transfer Bank')),
//                                     DropdownMenuItem(
//                                         value: 'E-Wallet',
//                                         child: Text('E-Wallet (OVO/Gopay)')),
//                                     DropdownMenuItem(
//                                         value: 'COD',
//                                         child: Text('Bayar di Tempat')),
//                                   ],
//                                   onChanged: (value) =>
//                                       setState(() => paymentMethod = value!),
//                                   decoration: const InputDecoration(
//                                     border: OutlineInputBorder(),
//                                     labelText: 'Metode Pembayaran',
//                                   ),
//                                 ),
//                                 const SizedBox(height: 16),

//                                 TextFormField(
//                                   maxLines: 3,
//                                   decoration: const InputDecoration(
//                                     labelText: 'Catatan Tambahan (Opsional)',
//                                     border: OutlineInputBorder(),
//                                     alignLabelWithHint: true,
//                                   ),
//                                   onSaved: (v) => catatan = v ?? '',
//                                 ),

//                                 const SizedBox(height: 24),
//                                 SizedBox(
//                                   width: double.infinity,
//                                   child: ElevatedButton.icon(
//                                     onPressed: isBooking ? null : bookKost,
//                                     icon: const Icon(Icons.book_online),
//                                     label: isBooking
//                                         ? const Text('Memproses...')
//                                         : const Text('Booking Sekarang'),
//                                     style: ElevatedButton.styleFrom(
//                                       padding: const EdgeInsets.symmetric(
//                                           vertical: 14),
//                                       backgroundColor: Colors.indigo,
//                                       shape: RoundedRectangleBorder(
//                                         borderRadius: BorderRadius.circular(12),
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                                 const SizedBox(height: 10),
//                                 const Center(
//                                   child: Text(
//                                     'Status pembayaran akan pending sampai dikonfirmasi pemilik kost.',
//                                     style: TextStyle(color: Colors.grey),
//                                     textAlign: TextAlign.center,
//                                   ),
//                                 )
//                               ],
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                   );
//                 },
//               ),
//             ),
//     );
//   }
// }
