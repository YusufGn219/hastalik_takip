import 'package:flutter/material.dart';
import '../profile_service.dart';
import '../../auth/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final result = await ProfileService.getProfile();
      setState(() {
        _profile = result['data'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  Future<void> _showEditDialog() async {
    final firstNameCtrl =
        TextEditingController(text: _profile?['first_name'] ?? '');
    final lastNameCtrl =
        TextEditingController(text: _profile?['last_name'] ?? '');
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Profili Düzenle'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: firstNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Ad',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Ad boş olamaz' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: lastNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Soyad',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Soyad boş olamaz' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => saving = true);
                      try {
                        await ProfileService.updateProfile(
                          firstName: firstNameCtrl.text.trim(),
                          lastName: lastNameCtrl.text.trim(),
                        );
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        await _loadProfile();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Profil güncellendi'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        setDialogState(() => saving = false);
                        if (!ctx.mounted) return;
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(e.toString()),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );

    firstNameCtrl.dispose();
    lastNameCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          if (_profile != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Düzenle',
              onPressed: _showEditDialog,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const SizedBox(height: 16),

                  // Kullanıcı bilgileri kartı
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: Theme.of(context).primaryColor,
                            child: Text(
                              _profile?['first_name']?[0]?.toUpperCase() ?? '?',
                              style: const TextStyle(
                                fontSize: 28,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_profile?['first_name'] ?? ''} ${_profile?['last_name'] ?? ''}'
                                      .trim(),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _profile?['email'] ?? '',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined,
                                color: Colors.grey),
                            onPressed: _showEditDialog,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Şifre değiştir
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: const Icon(Icons.lock_outline),
                      title: const Text('Şifre Değiştir'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await Navigator.pushNamed(context, '/change-password');
                      },
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Çıkış yap
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: const Icon(Icons.logout, color: Colors.red),
                      title: const Text(
                        'Çıkış Yap',
                        style: TextStyle(color: Colors.red),
                      ),
                      onTap: _logout,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
