// lib/pages/owner_pages.dart
import 'package:flutter/material.dart';
import 'package:kost_hunter/owner/FacilityManagementPage.dart';
import 'package:kost_hunter/owner/KostManagementPage.dart';
import 'package:kost_hunter/owner/OwnerProfilePage.dart';
import 'package:kost_hunter/owner/RoomManagementPage.dart';
import 'package:kost_hunter/owner/TransactionsPage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OwnerDashboard extends StatefulWidget {
  const OwnerDashboard({Key? key}) : super(key: key);

  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard> {
  final supabase = Supabase.instance.client;
  int _selectedIndex = 0;

  // pages
  final List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    // build pages lazily to get fresh supabase client inside each page
    _pages.addAll([
      KostManagementPage(),
      RoomManagementPage(),
      FacilityManagementPage(),
      TransactionsPage(),
      OwnerProfilePage(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Owner Portal'),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // signal refresh by rebuilding a page (simple approach)
              setState(() {});
            },
          ),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.indigo,
        unselectedItemColor: Colors.grey[600],
        onTap: (i) => setState(() => _selectedIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_work), label: 'Kost'),
          BottomNavigationBarItem(icon: Icon(Icons.bed), label: 'Kamar'),
          BottomNavigationBarItem(icon: Icon(Icons.miscellaneous_services), label: 'Fasilitas'),
          BottomNavigationBarItem(icon: Icon(Icons.payment), label: 'Transaksi'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }
}









// import 'package:flutter/material.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';

// class OwnerDashboard extends StatefulWidget {
//   const OwnerDashboard({super.key});

//   @override
//   State<OwnerDashboard> createState() => _OwnerDashboardState();
// }

// class _OwnerDashboardState extends State<OwnerDashboard> {
//   final supabase = Supabase.instance.client;
//   int _selectedIndex = 0;
//   bool isLoading = true;

//   List<dynamic> kostList = [];
//   List<dynamic> bookingList = [];
//   List<dynamic> paymentList = [];

//   @override
//   void initState() {
//     super.initState();
//     fetchOwnerData();
//   }

//   Future<void> fetchOwnerData() async {
//     setState(() => isLoading = true);
//     try {
//       final user = supabase.auth.currentUser;
//       if (user == null) throw Exception("User belum login.");

//       // Ambil data kost
//       final kostRes =
//           await supabase.from('kost').select('*').eq('owner_id', user.id);

//       // Ambil semua booking
//       final bookingRes = await supabase
//           .from('bookings')
//           .select('*, kost:nama_kost(id, nama_kost)')
//           .in_('kost_id', kostRes.map((k) => k['id']).toList());

//       // Ambil semua pembayaran
//       final paymentRes = await supabase
//           .from('payments')
//           .select('*, bookings!inner(kost_id)')
//           .in_('bookings.kost_id', kostRes.map((k) => k['id']).toList());

//       setState(() {
//         kostList = kostRes;
//         bookingList = bookingRes;
//         paymentList = paymentRes;
//       });
//     } catch (e) {
//       ScaffoldMessenger.of(context)
//           .showSnackBar(SnackBar(content: Text("Gagal memuat data: $e")));
//     }
//     setState(() => isLoading = false);
//   }

//   Future<void> updateBookingStatus(String bookingId, String status) async {
//     try {
//       await supabase.from('bookings').update({'status': status}).eq('id', bookingId);
//       ScaffoldMessenger.of(context)
//           .showSnackBar(SnackBar(content: Text('Status booking diubah menjadi $status')));
//       fetchOwnerData();
//     } catch (e) {
//       ScaffoldMessenger.of(context)
//           .showSnackBar(SnackBar(content: Text('Gagal update status: $e')));
//     }
//   }

//   // ====================== WIDGET HALAMAN ======================

//   Widget buildKostList() => kostList.isEmpty
//       ? const Center(child: Text('Belum ada kost terdaftar.'))
//       : ListView(
//           children: kostList
//               .map((kost) => Card(
//                     margin: const EdgeInsets.symmetric(vertical: 8),
//                     child: ListTile(
//                       title: Text(kost['nama_kost'] ?? '-'),
//                       subtitle: Text(kost['alamat'] ?? '-'),
//                       trailing: const Icon(Icons.home_work),
//                     ),
//                   ))
//               .toList(),
//         );

//   Widget buildKamarList() => const Center(
//       child: Text('Fitur CRUD Kamar Kos akan ditambahkan di sini 🔧'));

//   Widget buildFasilitasList() => const Center(
//       child: Text('Fitur CRUD Fasilitas Kos akan ditambahkan di sini 🧰'));

//   Widget buildTransaksiList() => paymentList.isEmpty
//       ? const Center(child: Text('Belum ada transaksi pembayaran.'))
//       : ListView(
//           children: paymentList
//               .map((p) => Card(
//                     margin: const EdgeInsets.symmetric(vertical: 8),
//                     child: ListTile(
//                       title: Text('Metode: ${p['metode']}'),
//                       subtitle: Text('Jumlah: Rp${p['jumlah']} - Status: ${p['status']}'),
//                       trailing: p['bukti_url'] != null
//                           ? IconButton(
//                               icon: const Icon(Icons.receipt_long),
//                               onPressed: () => showDialog(
//                                 context: context,
//                                 builder: (_) => AlertDialog(
//                                   title: const Text('Bukti Pembayaran'),
//                                   content: Image.network(p['bukti_url']),
//                                 ),
//                               ),
//                             )
//                           : null,
//                     ),
//                   ))
//               .toList(),
//         );

//   Widget buildProfilPage() {
//     final user = supabase.auth.currentUser;
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(Icons.person, size: 80, color: Colors.blueAccent),
//           const SizedBox(height: 10),
//           Text(user?.email ?? 'Email tidak diketahui',
//               style: const TextStyle(fontSize: 16)),
//           const SizedBox(height: 20),
//           ElevatedButton(
//             onPressed: () async {
//               await supabase.auth.signOut();
//               if (mounted) Navigator.pushReplacementNamed(context, '/login');
//             },
//             child: const Text('Logout'),
//           ),
//         ],
//       ),
//     );
//   }

//   // ====================== BODY SESUAI TAB ======================

//   Widget getBody() {
//     if (isLoading) {
//       return const Center(child: CircularProgressIndicator());
//     }
//     switch (_selectedIndex) {
//       case 0:
//         return buildKostList();
//       case 1:
//         return buildKamarList();
//       case 2:
//         return buildFasilitasList();
//       case 3:
//         return buildTransaksiList();
//       case 4:
//         return buildProfilPage();
//       default:
//         return const Center(child: Text("Halaman tidak ditemukan"));
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Dashboard Owner"),
//         backgroundColor: Colors.blueAccent,
//         actions: [
//           IconButton(onPressed: fetchOwnerData, icon: const Icon(Icons.refresh))
//         ],
//       ),
//       body: getBody(),
//       bottomNavigationBar: BottomNavigationBar(
//         currentIndex: _selectedIndex,
//         selectedItemColor: Colors.blueAccent,
//         unselectedItemColor: Colors.grey,
//         onTap: (index) => setState(() => _selectedIndex = index),
//         items: const [
//           BottomNavigationBarItem(icon: Icon(Icons.home), label: "Kost"),
//           BottomNavigationBarItem(icon: Icon(Icons.bed), label: "Kamar"),
//           BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Fasilitas"),
//           BottomNavigationBarItem(icon: Icon(Icons.payment), label: "Transaksi"),
//           BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profil"),
//         ],
//       ),
//     );
//   }
// }




// import 'package:flutter/material.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';

// class OwnerDashboard extends StatefulWidget {
//   const OwnerDashboard({super.key});

//   @override
//   State<OwnerDashboard> createState() => _OwnerDashboardState();
// }

// class _OwnerDashboardState extends State<OwnerDashboard> {
//   final supabase = Supabase.instance.client;
//   List<dynamic> kostList = [];
//   List<dynamic> bookingList = [];
//   List<dynamic> paymentList = [];
//   bool isLoading = true;

//   @override
//   void initState() {
//     super.initState();
//     fetchOwnerData();
//   }

//   Future<void> fetchOwnerData() async {
//     setState(() => isLoading = true);

//     try {
//       final user = supabase.auth.currentUser;
//       if (user == null) throw Exception("User belum login.");

//       // Ambil semua kost milik owner
//       final kostRes = await supabase
//           .from('kost')
//           .select('*')
//           .eq('owner_id', user.id);

//       // Ambil semua booking dari kost miliknya
//       final bookingRes = await supabase
//           .from('bookings')
//           .select('*, kost:nama_kost(id, nama_kost)')
//           .in_('kost_id', kostRes.map((k) => k['id']).toList());

//       // Ambil semua pembayaran terkait kost miliknya
//       final paymentRes = await supabase
//           .from('payments')
//           .select('*, bookings!inner(kost_id)')
//           .in_('bookings.kost_id', kostRes.map((k) => k['id']).toList());

//       setState(() {
//         kostList = kostRes;
//         bookingList = bookingRes;
//         paymentList = paymentRes;
//       });
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Gagal memuat data: $e')),
//       );
//     }

//     setState(() => isLoading = false);
//   }

//   Future<void> updateBookingStatus(String bookingId, String status) async {
//     try {
//       await supabase.from('bookings').update({'status': status}).eq('id', bookingId);
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Status booking diubah menjadi $status')),
//       );
//       fetchOwnerData();
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Gagal update status: $e')),
//       );
//     }
//   }

//   Widget buildKostList() {
//     if (kostList.isEmpty) {
//       return const Center(child: Text('Belum ada kost terdaftar.'));
//     }
//     return Column(
//       children: kostList.map((kost) {
//         return Card(
//           margin: const EdgeInsets.symmetric(vertical: 8),
//           child: ListTile(
//             title: Text(kost['nama_kost'] ?? '-'),
//             subtitle: Text(kost['alamat'] ?? '-'),
//             trailing: const Icon(Icons.home_work),
//           ),
//         );
//       }).toList(),
//     );
//   }

//   Widget buildBookingList() {
//     if (bookingList.isEmpty) {
//       return const Center(child: Text('Belum ada pemesanan.'));
//     }
//     return Column(
//       children: bookingList.map((booking) {
//         return Card(
//           margin: const EdgeInsets.symmetric(vertical: 8),
//           child: ListTile(
//             title: Text('Booking ID: ${booking['id']}'),
//             subtitle: Text('Status: ${booking['status']}'),
//             trailing: PopupMenuButton<String>(
//               onSelected: (value) =>
//                   updateBookingStatus(booking['id'], value),
//               itemBuilder: (context) => [
//                 const PopupMenuItem(value: 'diterima', child: Text('Terima')),
//                 const PopupMenuItem(value: 'ditolak', child: Text('Tolak')),
//               ],
//             ),
//           ),
//         );
//       }).toList(),
//     );
//   }

//   Widget buildPaymentList() {
//     if (paymentList.isEmpty) {
//       return const Center(child: Text('Belum ada transaksi pembayaran.'));
//     }
//     return Column(
//       children: paymentList.map((p) {
//         return Card(
//           margin: const EdgeInsets.symmetric(vertical: 8),
//           child: ListTile(
//             title: Text('Metode: ${p['metode']}'),
//             subtitle: Text('Jumlah: Rp${p['jumlah']} - Status: ${p['status']}'),
//             trailing: p['bukti_url'] != null
//                 ? IconButton(
//                     icon: const Icon(Icons.receipt_long),
//                     onPressed: () {
//                       showDialog(
//                         context: context,
//                         builder: (_) => AlertDialog(
//                           title: const Text('Bukti Pembayaran'),
//                           content: Image.network(p['bukti_url']),
//                         ),
//                       );
//                     },
//                   )
//                 : null,
//           ),
//         );
//       }).toList(),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Dashboard Owner"),
//         backgroundColor: Colors.blueAccent,
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.refresh),
//             onPressed: fetchOwnerData,
//           )
//         ],
//       ),
//       body: isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : SingleChildScrollView(
//               padding: const EdgeInsets.all(16),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const Text("🏠 Kost Kamu",
//                       style:
//                           TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//                   buildKostList(),
//                   const SizedBox(height: 20),
//                   const Text("📋 Pemesanan Kost",
//                       style:
//                           TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//                   buildBookingList(),
//                   const SizedBox(height: 20),
//                   const Text("💰 Pembayaran",
//                       style:
//                           TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//                   buildPaymentList(),
//                 ],
//               ),
//             ),
//     );
//   }
// }
