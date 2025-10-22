import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FacilityManagementPage extends StatefulWidget {
  @override
  State<FacilityManagementPage> createState() => _FacilityManagementPageState();
}

class _FacilityManagementPageState extends State<FacilityManagementPage> {
  final supabase = Supabase.instance.client;
  List<dynamic> kostList = [];
  List<dynamic> facilities = [];
  bool loading = true;
  String? selectedKostId;

  @override
  void initState() {
    super.initState();
    initAll();
  }

  Future<void> initAll() async {
    setState(() => loading = true);
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final k = await supabase.from('kost').select().eq('owner_id', user.id);
    setState(() {
      kostList = k;
      selectedKostId = kostList.isNotEmpty ? kostList[0]['id'] : null;
    });
    await fetchFacilities();
    setState(() => loading = false);
  }

  Future<void> fetchFacilities() async {
    if (selectedKostId == null) { 
      setState(() => facilities = []); 
      return; 
    }
    
    try {
      final response = await supabase
          .from('facilities')
          .select()
          .eq('kost_id', selectedKostId as Object);
      
      setState(() => facilities = response);
    } catch (e) {
      print('Error fetching facilities: $e');
      setState(() => facilities = []);
    }
  }

  Future<void> showFacilityForm({Map? edit}) async {
    final nameCtrl = TextEditingController(text: edit?['nama_fasilitas'] ?? '');
    final descCtrl = TextEditingController(text: edit?['deskripsi'] ?? '');
    final iconCtrl = TextEditingController(text: edit?['icon_url'] ?? '');

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(edit == null ? 'Tambah Fasilitas' : 'Edit Fasilitas'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: selectedKostId,
              decoration: const InputDecoration(labelText: 'Pilih Kost'),
              items: kostList.map((k) => DropdownMenuItem<String>(value: k['id'].toString(), child: Text(k['nama_kost']))).toList(),
              onChanged: (v) => setState(() => selectedKostId = v),
            ),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nama Fasilitas')),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Deskripsi')),
            TextField(controller: iconCtrl, decoration: const InputDecoration(labelText: 'Icon URL (opsional)')),
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
                  await supabase.from('facilities').insert({
                    'kost_id': selectedKostId,
                    'nama_fasilitas': nameCtrl.text,
                    'deskripsi': descCtrl.text,
                    'icon_url': iconCtrl.text,
                  });
                } else {
                  await supabase.from('facilities').update({
                    'nama_fasilitas': nameCtrl.text,
                    'deskripsi': descCtrl.text,
                    'icon_url': iconCtrl.text,
                  }).eq('id', edit['id']);
                }
                await fetchFacilities();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sukses menyimpan fasilitas')));
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

  Future<void> deleteFacility(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Fasilitas'),
        content: const Text('Yakin ingin menghapus fasilitas ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await supabase.from('facilities').delete().eq('id', id);
      await fetchFacilities();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fasilitas dihapus')));
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
              const Expanded(child: Text('Manajemen Fasilitas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              ElevatedButton.icon(onPressed: () => showFacilityForm(), icon: const Icon(Icons.add), label: const Text('Tambah')),
            ],
          ),
          const SizedBox(height: 10),
          if (loading) const Expanded(child: Center(child: CircularProgressIndicator())) else
          Column(
            children: [
              DropdownButton<String>(
                value: selectedKostId,
                hint: const Text('Pilih Kost'),
                items: kostList.map((k) => DropdownMenuItem<String>(value: k['id'].toString(), child: Text(k['nama_kost']))).toList(),
                onChanged: (v) async {
                  setState(() => selectedKostId = v);
                  await fetchFacilities();
                },
              ),
              const SizedBox(height: 8),
              Expanded(
                child: facilities.isEmpty
                    ? const Center(child: Text('Belum ada fasilitas'))
                    : ListView.builder(
                        itemCount: facilities.length,
                        itemBuilder: (_, i) {
                          final f = facilities[i];
                          return Card(
                            child: ListTile(
                              leading: f['icon_url'] != null ? Image.network(f['icon_url'], width: 48) : const Icon(Icons.miscellaneous_services),
                              title: Text(f['nama_fasilitas'] ?? '-'),
                              subtitle: Text(f['deskripsi'] ?? ''),
                              trailing: PopupMenuButton<String>(
                                onSelected: (v) {
                                  if (v == 'edit') showFacilityForm(edit: f);
                                  if (v == 'delete') deleteFacility(f['id']);
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
