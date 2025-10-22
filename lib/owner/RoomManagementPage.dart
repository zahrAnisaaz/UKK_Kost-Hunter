import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RoomManagementPage extends StatefulWidget {
  @override
  State<RoomManagementPage> createState() => _RoomManagementPageState();
}

class _RoomManagementPageState extends State<RoomManagementPage> {
  final supabase = Supabase.instance.client;
  List<dynamic> kostList = [];
  List<dynamic> rooms = [];
  bool loading = true;
  String? selectedKostId;

  @override
  void initState() {
    super.initState();
    loadInitial();
  }

  Future<void> loadInitial() async {
    setState(() => loading = true);
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final k = await supabase.from('kost').select().eq('owner_id', user.id);
    setState(() {
      kostList = k;
      selectedKostId = kostList.isNotEmpty ? kostList[0]['id'] : null;
    });
    await fetchRooms();
    setState(() => loading = false);
  }

  Future<void> fetchRooms() async {
    if (selectedKostId == null) {
      setState(() => rooms = []);
      return;
    }
    final r = await supabase.from('rooms').select().eq('kost_id', selectedKostId as Object);
    setState(() => rooms = r);
  }

  Future<void> showRoomForm({Map? edit}) async {
    final nameCtrl = TextEditingController(text: edit?['nama_kamar'] ?? '');
    final sizeCtrl = TextEditingController(text: edit?['ukuran'] ?? '');
    final priceCtrl = TextEditingController(text: edit?['harga_per_bulan']?.toString() ?? '');
    String status = edit?['status'] ?? 'tersedia';

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(edit == null ? 'Tambah Kamar' : 'Edit Kamar'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: selectedKostId,
              decoration: const InputDecoration(labelText: 'Pilih Kost'),
              items: kostList.map((k) => DropdownMenuItem<String>(value: k['id']?.toString(), child: Text(k['nama_kost']))).toList(),
              onChanged: (v) => setState(() => selectedKostId = v),
            ),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nama Kamar')),
            TextField(controller: sizeCtrl, decoration: const InputDecoration(labelText: 'Ukuran')),
            TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Harga per bulan'), keyboardType: TextInputType.number),
            DropdownButtonFormField<String>(
              value: status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem(value: 'tersedia', child: Text('Tersedia')),
                DropdownMenuItem(value: 'dipesan', child: Text('Dipesan')),
                DropdownMenuItem(value: 'tidak aktif', child: Text('Tidak aktif')),
              ],
              onChanged: (v) => status = v ?? 'tersedia',
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              if (selectedKostId == null) return;
              Navigator.pop(context);
              try {
                if (edit == null) {
                  await supabase.from('rooms').insert({
                    'kost_id': selectedKostId,
                    'nama_kamar': nameCtrl.text,
                    'ukuran': sizeCtrl.text,
                    'harga_per_bulan': double.tryParse(priceCtrl.text) ?? 0,
                    'status': status,
                  });
                } else {
                  await supabase.from('rooms').update({
                    'nama_kamar': nameCtrl.text,
                    'ukuran': sizeCtrl.text,
                    'harga_per_bulan': double.tryParse(priceCtrl.text) ?? 0,
                    'status': status,
                  }).eq('id', edit['id']);
                }
                await fetchRooms();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sukses menyimpan kamar')));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> deleteRoom(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Kamar'),
        content: const Text('Yakin ingin menghapus kamar ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await supabase.from('rooms').delete().eq('id', id);
      await fetchRooms();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kamar dihapus')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal hapus: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(child: Text('Manajemen Kamar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              ElevatedButton.icon(onPressed: () => showRoomForm(), icon: const Icon(Icons.add), label: const Text('Tambah Kamar')),
            ],
          ),
          const SizedBox(height: 10),
          if (loading) const Expanded(child: Center(child: CircularProgressIndicator())) else
          Column(
            children: [
              DropdownButton<String>(
                value: selectedKostId,
                hint: const Text('Pilih Kost'),
                items: kostList.map((k) => DropdownMenuItem<String>(value: k['id']?.toString(), child: Text(k['nama_kost']))).toList(),
                onChanged: (v) async {
                  setState(() => selectedKostId = v);
                  await fetchRooms();
                },
              ),
              const SizedBox(height: 8),
              Expanded(
                child: rooms.isEmpty
                    ? const Center(child: Text('Belum ada kamar'))
                    : ListView.builder(
                        itemCount: rooms.length,
                        itemBuilder: (_, i) {
                          final r = rooms[i];
                          return Card(
                            child: ListTile(
                              title: Text(r['nama_kamar'] ?? '-'),
                              subtitle: Text('Rp ${r['harga_per_bulan'] ?? '-'} / bulan\nStatus: ${r['status']}'),
                              isThreeLine: true,
                              trailing: PopupMenuButton<String>(
                                onSelected: (v) {
                                  if (v == 'edit') showRoomForm(edit: r);
                                  if (v == 'delete') deleteRoom(r['id']);
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                                  PopupMenuItem(value: 'delete', child: Text('Hapus')),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
