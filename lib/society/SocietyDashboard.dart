import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:kost_hunter/society/DetailKostPage.dart';
import 'package:kost_hunter/society/PesananPage.dart';
import 'package:kost_hunter/society/ProfilePage.dart';
import 'package:kost_hunter/society/WishlistPage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SocietyDashboard extends StatefulWidget {
  const SocietyDashboard({super.key});

  @override
  State<SocietyDashboard> createState() => _SocietyDashboardState();
}

class _SocietyDashboardState extends State<SocietyDashboard> {
  String selectedCategory = 'Semua';
  bool isLoading = true;

  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> kostList = [];
  Set<String> wishlist = {};

  final List<String> promoImages = [
    'https://images.unsplash.com/photo-1600585154340-be6161a56a0c',
    'https://images.unsplash.com/photo-1600047509807-ba8f99d2cdde',
    'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2',
  ];

  final List<Map<String, String>> categories = [
    {'icon': '🏠', 'name': 'Semua'},
    {'icon': '👦', 'name': 'Putra'},
    {'icon': '👧', 'name': 'Putri'},
    {'icon': '🏡', 'name': 'Campur'},
    {'icon': '⭐', 'name': 'Eksklusif'},
  ];

  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    fetchAllData();
  }

  Future<void> fetchAllData() async {
    await fetchKostData();
    await fetchWishlist();
  }

  // Ambil data kost
  Future<void> fetchKostData() async {
    try {
      final response = await supabase.from('kost').select('*');
      setState(() {
        kostList = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      print('❌ Error ambil data kost: $e');
      setState(() => isLoading = false);
    }
  }

  // Ambil wishlist user
  Future<void> fetchWishlist() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await supabase
          .from('wishlist')
          .select('kost_id')
          .eq('user_id', userId);

      setState(() {
        wishlist = Set<String>.from(
          (response as List).map((e) => e['kost_id'].toString()),
        );
      });
    } catch (e) {
      print('❌ Error ambil wishlist: $e');
    }
  }

  // Toggle wishlist
  Future<void> toggleWishlist(String kostId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan login dulu untuk menambahkan ke wishlist')),
      );
      return;
    }

    try {
      if (wishlist.contains(kostId)) {
        await supabase
            .from('wishlist')
            .delete()
            .eq('kost_id', kostId)
            .eq('user_id', userId);

        setState(() => wishlist.remove(kostId));
      } else {
        await supabase.from('wishlist').insert({
          'kost_id': kostId,
          'user_id': userId,
        });

        setState(() => wishlist.add(kostId));
      }
    } catch (e) {
      print('❌ Gagal update wishlist: $e');
    }
  }

  // Filter kost berdasarkan kategori
  List<Map<String, dynamic>> get filteredKosts {
    if (selectedCategory == 'Semua') return kostList;
    return kostList
        .where((kost) =>
            (kost['type'] ?? '').toString().toLowerCase() ==
            selectedCategory.toLowerCase())
        .toList();
  }

  // Kost terdekat (ambil 3 pertama)
  List<Map<String, dynamic>> get nearby => filteredKosts.take(3).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Lokasi
                      Row(
                        children: const [
                          Icon(Icons.location_on, color: Colors.blue),
                          SizedBox(width: 5),
                          Text(
                            'Malang, Indonesia',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),

                      // Search bar
                      TextField(
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: 'Cari kost...',
                          suffixIcon: const Icon(Icons.filter_list),
                          filled: true,
                          fillColor: Colors.blue.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Promo carousel
                      CarouselSlider(
                        options: CarouselOptions(
                          height: 160,
                          autoPlay: true,
                          enlargeCenterPage: true,
                        ),
                        items: promoImages.map((url) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(url,
                                fit: BoxFit.cover, width: double.infinity),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),

                      // Kategori
                      Center(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: categories.map((c) {
                              final name = c['name']!;
                              final icon = c['icon']!;
                              final isSelected = selectedCategory == name;
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      selectedCategory = name;
                                    });
                                  },
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircleAvatar(
                                        radius: 25,
                                        backgroundColor: isSelected
                                            ? Colors.blue
                                            : Colors.blue.shade50,
                                        child: Text(icon,
                                            style:
                                                const TextStyle(fontSize: 20)),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        name,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: isSelected
                                                ? Colors.blue
                                                : Colors.black),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Kost Rekomendasi
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Kost Rekomendasi',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Lihat semua',
                            style: TextStyle(color: Colors.blue),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 250,
                        child: filteredKosts.isEmpty
                            ? const Center(child: Text('Tidak ada kost ditemukan'))
                            : ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: filteredKosts.length,
                                itemBuilder: (context, index) {
                                  final kost = filteredKosts[index];
                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => DetailKostPage(
                                            kost: kost,
                                            userId: supabase.auth.currentUser?.id ?? '',
                                          ),
                                        ),
                                      );
                                    },
                                    child: kostCard(kost),
                                  );
                                },
                              ),
                      ),

                      const SizedBox(height: 20),
                      // Kost Terdekat
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Kost Terdekat',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Lihat semua',
                            style: TextStyle(color: Colors.blue),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 250,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: nearby.length,
                          itemBuilder: (context, index) {
                            final kost = nearby[index];
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DetailKostPage(
                                      kost: kost,
                                      userId: supabase.auth.currentUser?.id ?? '',
                                    ),
                                  ),
                                );
                              },
                              child: kostCard(kost),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),

      // Bottom navigation
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        onTap: (index) {
          setState(() => _currentIndex = index);
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const WishlistPage(
                ),
              ),
            );
          } else if (index == 2) {
            // Fix: Pass required parameters to BookingPage
            if (filteredKosts.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PesananPage(),
                ),
              );
            }
          } else if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfilePage(
                  userId: supabase.auth.currentUser?.id ?? '',
                ),
              ),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Jelajah'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite_border), label: 'Favorit'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Pesan'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profil'),
        ],
      ),
    );
  }

  // Widget kost card
  Widget kostCard(Map<String, dynamic> kost) {
    final kostId = kost['id'].toString();

    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.network(
                (kost['gambar']?.isNotEmpty ?? false)
                    ? kost['gambar']
                    : 'https://via.placeholder.com/150?text=No+Image',
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          kost['nama_kost'] ?? '-',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => toggleWishlist(kostId),
                        child: Icon(
                          wishlist.contains(kostId)
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: wishlist.contains(kostId)
                              ? Colors.red
                              : Colors.grey,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.grey, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          kost['alamat'] ?? '-',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: List.generate(
                      (kost['rating'] ?? 0).round(),
                      (index) => const Icon(Icons.star, color: Colors.amber, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}



// import 'package:flutter/material.dart';
// import 'package:carousel_slider/carousel_slider.dart';
// import 'package:kost_hunter/ChatPage.dart';
// import 'package:kost_hunter/DetailKostPage.dart';
// import 'package:kost_hunter/ProfilePage.dart';
// import 'package:kost_hunter/WishlistPage.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';

// class SocietyDashboard extends StatefulWidget {
//   const SocietyDashboard({super.key});

//   @override
//   State<SocietyDashboard> createState() => _SocietyDashboardState();
// }

// class _SocietyDashboardState extends State<SocietyDashboard> {
//   String selectedCategory = 'Semua';
//   bool isLoading = true;

//   final supabase = Supabase.instance.client;

//   List<Map<String, dynamic>> kostList = [];
//   Set<String> wishlist = {};

//   final List<String> promoImages = [
//     'https://images.unsplash.com/photo-1600585154340-be6161a56a0c',
//     'https://images.unsplash.com/photo-1600047509807-ba8f99d2cdde',
//     'https://images.unsplash.com/photo-1560448204-e02f11c3d0e2',
//   ];

//   final List<Map<String, String>> categories = [
//     {'icon': '🏠', 'name': 'Semua'},
//     {'icon': '👦', 'name': 'Putra'},
//     {'icon': '👧', 'name': 'Putri'},
//     {'icon': '🏡', 'name': 'Campur'},
//     {'icon': '⭐', 'name': 'Eksklusif'},
//   ];

//   @override
//   void initState() {
//     super.initState();
//     fetchAllData();
//   }

//   Future<void> fetchAllData() async {
//     await fetchKostData();
//     await fetchWishlist();
//   }

//   // ✅ Ambil data kost
//   Future<void> fetchKostData() async {
//     try {
//       final response = await supabase.from('kost').select('*');
//       setState(() {
//         kostList = List<Map<String, dynamic>>.from(response);
//         isLoading = false;
//       });
//     } catch (e) {
//       print('❌ Error ambil data kost: $e');
//       setState(() => isLoading = false);
//     }
//   }

//   // ✅ Ambil wishlist dari Supabase
//   Future<void> fetchWishlist() async {
//     try {
//       final userId = supabase.auth.currentUser?.id;
//       if (userId == null) return;

//       final response = await supabase
//           .from('wishlist')
//           .select('kost_id')
//           .eq('user_id', userId);

//       setState(() {
//         wishlist = Set<String>.from(
//           (response as List).map((e) => e['kost_id'].toString()),
//         );
//       });
//     } catch (e) {
//       print('❌ Error ambil wishlist: $e');
//     }
//   }

//   // ✅ Toggle wishlist (tambah / hapus)
//   Future<void> toggleWishlist(String kostId) async {
//     final userId = supabase.auth.currentUser?.id;
//     if (userId == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Silakan login dulu untuk menambahkan ke wishlist')),
//       );
//       return;
//     }

//     try {
//       if (wishlist.contains(kostId)) {
//         // hapus dari Supabase
//         await supabase
//             .from('wishlist')
//             .delete()
//             .eq('kost_id', kostId)
//             .eq('user_id', userId);

//         setState(() => wishlist.remove(kostId));
//       } else {
//         // tambah ke Supabase
//         await supabase.from('wishlist').insert({
//           'kost_id': kostId,
//           'user_id': userId,
//         });

//         setState(() => wishlist.add(kostId));
//       }
//     } catch (e) {
//       print('❌ Gagal update wishlist: $e');
//     }
//   }

//   // ✅ Filter
//   List<Map<String, dynamic>> get filteredKosts {
//     if (selectedCategory == 'Semua') return kostList;
//     return kostList
//         .where((kost) =>
//             (kost['type'] ?? '').toString().toLowerCase() ==
//             selectedCategory.toLowerCase())
//         .toList();
//   }

//   List<Map<String, dynamic>> get nearby => filteredKosts.take(3).toList();

//   int _currentIndex = 0;

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: SafeArea(
//         child: isLoading
//             ? const Center(child: CircularProgressIndicator())
//             : SingleChildScrollView(
//                 physics: const BouncingScrollPhysics(),
//                 child: Padding(
//                   padding: const EdgeInsets.all(16),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Row(
//                         children: [
//                           const Icon(Icons.location_on, color: Colors.blue),
//                           const SizedBox(width: 5),
//                           const Text(
//                             'Malang, Indonesia',
//                             style: TextStyle(
//                                 fontSize: 16, fontWeight: FontWeight.w500),
//                           ),
//                         ],
//                       ),
//                       const SizedBox(height: 15),
//                       TextField(
//                         decoration: InputDecoration(
//                           prefixIcon: const Icon(Icons.search),
//                           hintText: 'Cari kost...',
//                           suffixIcon: const Icon(Icons.filter_list),
//                           filled: true,
//                           fillColor: Colors.blue.shade50,
//                           border: OutlineInputBorder(
//                             borderRadius: BorderRadius.circular(12),
//                             borderSide: BorderSide.none,
//                           ),
//                         ),
//                       ),
//                       const SizedBox(height: 20),
//                       CarouselSlider(
//                         options: CarouselOptions(
//                           height: 160,
//                           autoPlay: true,
//                           enlargeCenterPage: true,
//                         ),
//                         items: promoImages.map((url) {
//                           return ClipRRect(
//                             borderRadius: BorderRadius.circular(12),
//                             child: Image.network(url,
//                                 fit: BoxFit.cover, width: double.infinity),
//                           );
//                         }).toList(),
//                       ),
//                       const SizedBox(height: 20),
//                       Center(
//                         child: SingleChildScrollView(
//                           scrollDirection: Axis.horizontal,
//                           child: Row(
//                             mainAxisSize: MainAxisSize.min,
//                             children: categories.map((c) {
//                               final name = c['name']!;
//                               final icon = c['icon']!;
//                               final isSelected = selectedCategory == name;
//                               return Padding(
//                                 padding:
//                                     const EdgeInsets.symmetric(horizontal: 8),
//                                 child: GestureDetector(
//                                   onTap: () {
//                                     setState(() {
//                                       selectedCategory = name;
//                                     });
//                                   },
//                                   child: Column(
//                                     mainAxisSize: MainAxisSize.min,
//                                     children: [
//                                       CircleAvatar(
//                                         radius: 25,
//                                         backgroundColor: isSelected
//                                             ? Colors.blue
//                                             : Colors.blue.shade50,
//                                         child: Text(icon,
//                                             style:
//                                                 const TextStyle(fontSize: 20)),
//                                       ),
//                                       const SizedBox(height: 5),
//                                       Text(
//                                         name,
//                                         style: TextStyle(
//                                             fontSize: 12,
//                                             color: isSelected
//                                                 ? Colors.blue
//                                                 : Colors.black),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                               );
//                             }).toList(),
//                           ),
//                         ),
//                       ),
//                       const SizedBox(height: 20),
//                       const Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Text(
//                             'Kost Rekomendasi',
//                             style: TextStyle(
//                                 fontSize: 18, fontWeight: FontWeight.bold),
//                           ),
//                           Text(
//                             'Lihat semua',
//                             style: TextStyle(color: Colors.blue),
//                           ),





