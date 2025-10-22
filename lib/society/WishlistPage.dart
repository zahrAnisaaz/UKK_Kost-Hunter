import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kost_hunter/society/DetailKostPage.dart';

class WishlistPage extends StatefulWidget {
  const WishlistPage({super.key});

  @override
  State<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> wishlistKost = [];
  bool isLoading = true;

  Future<void> fetchWishlist() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final response = await supabase
          .from('wishlist')
          .select('kost(*)')
          .eq('user_id', userId);

      wishlistKost = response
          .where((item) => item['kost'] != null)
          .map<Map<String, dynamic>>((item) => 
              Map<String, dynamic>.from(item['kost']))
          .toList();

      setState(() => isLoading = false);
    } catch (e) {
      print('❌ Error ambil wishlist: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    fetchWishlist();
  }

  @override
  Widget build(BuildContext context) {
    final userId = supabase.auth.currentUser?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kost Favorit'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : wishlistKost.isEmpty
              ? const Center(child: Text('Belum ada kost di wishlist 💔'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: wishlistKost.length,
                  itemBuilder: (context, index) {
                    final kost = wishlistKost[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 3,
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            kost['gambar'] ??
                                'https://via.placeholder.com/150?text=No+Image',
                            width: 70,
                            height: 70,
                            fit: BoxFit.cover,
                          ),
                        ),
                        title: Text(kost['nama_kost'] ?? '-'),
                        subtitle: Text(kost['alamat'] ?? '-'),
                        trailing:
                            const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
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
                      ),
                    );
                  },
                ),
    );
  }
}




// import 'package:flutter/material.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:kost_hunter/DetailKostPage.dart';

// class WishlistPage extends StatefulWidget {
//   const WishlistPage({super.key, required Set<String> wishlist, required List<Map<String, dynamic>> kostList, required Future<void> Function(String kostId) onToggleWishlist});

//   @override
//   State<WishlistPage> createState() => _WishlistPageState();
// }

// class _WishlistPageState extends State<WishlistPage> {
//   final supabase = Supabase.instance.client;
//   List<Map<String, dynamic>> wishlistKost = [];
//   bool isLoading = true;

//   // Ambil wishlist beserta data kost
//   Future<void> fetchWishlist() async {
//     final userId = supabase.auth.currentUser?.id;
//     if (userId == null) {
//       setState(() => isLoading = false);
//       return;
//     }

//     try {
//       final response = await supabase
//           .from('wishlist')
//           .select('kost(*)') // join ke tabel kost
//           .eq('user_id', userId);

//       // Update: Handle response as List<dynamic>
//       wishlistKost = response
//           .where((item) => item['kost'] != null)
//           .map<Map<String, dynamic>>((item) => 
//               Map<String, dynamic>.from(item['kost']))
//           .toList();
    
//       setState(() => isLoading = false);
//     } catch (e) {
//       print('❌ Error ambil wishlist: $e');
//       setState(() => isLoading = false);
//     }
//   }

//   @override
//   void initState() {
//     super.initState();
//     fetchWishlist();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final userId = supabase.auth.currentUser?.id ?? '';

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Kost Favorit'),
//         backgroundColor: Colors.blue,
//         foregroundColor: Colors.white,
//       ),
//       body: isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : wishlistKost.isEmpty
//               ? const Center(child: Text('Belum ada kost di wishlist 💔'))
//               : ListView.builder(
//                   padding: const EdgeInsets.all(16),
//                   itemCount: wishlistKost.length,
//                   itemBuilder: (context, index) {
//                     final kost = wishlistKost[index];
//                     return Card(
//                       margin: const EdgeInsets.only(bottom: 12),
//                       shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(12)),
//                       elevation: 3,
//                       child: ListTile(
//                         leading: ClipRRect(
//                           borderRadius: BorderRadius.circular(8),
//                           child: Image.network(
//                             kost['gambar'] ??
//                                 'https://via.placeholder.com/150?text=No+Image',
//                             width: 70,
//                             height: 70,
//                             fit: BoxFit.cover,
//                           ),
//                         ),
//                         title: Text(kost['nama_kost'] ?? '-'),
//                         subtitle: Text(kost['alamat'] ?? '-'),
//                         trailing:
//                             const Icon(Icons.arrow_forward_ios, size: 16),
//                         onTap: () {
//                           Navigator.push(
//                             context,
//                             MaterialPageRoute(
//                               builder: (_) => DetailKostPage(
//                                 kost: kost,
//                                 userId: userId,
//                               ),
//                             ),
//                           );
//                         },
//                       ),
//                     );
//                   },
//                 ),
//     );
//   }
// }
