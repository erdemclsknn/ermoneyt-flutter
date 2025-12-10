// lib/screens/address_add_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddressAddScreen extends StatefulWidget {
  const AddressAddScreen({super.key});

  @override
  State<AddressAddScreen> createState() => _AddressAddScreenState();
}

class _AddressAddScreenState extends State<AddressAddScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleCtrl = TextEditingController();        // Adres başlığı
  final _fullnameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _tcCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _neighborhoodCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _zipCtrl = TextEditingController();
  final _lineCtrl = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _fullnameCtrl.dispose();
    _phoneCtrl.dispose();
    _tcCtrl.dispose();
    _cityCtrl.dispose();
    _districtCtrl.dispose();
    _neighborhoodCtrl.dispose();
    _streetCtrl.dispose();
    _zipCtrl.dispose();
    _lineCtrl.dispose();
    super.dispose();
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    TextInputType type = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: const Color(0xFF131822),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFFD166)),
        ),
      ),
      validator: validator,
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adres kaydetmek için giriş yapmalısın.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('addresses')
          .doc();

      final title = _titleCtrl.text.trim().isEmpty
          ? 'Adres'
          : _titleCtrl.text.trim();

      final fullName = _fullnameCtrl.text.trim();
      final phone = _phoneCtrl.text.trim();
      final tc = _tcCtrl.text.trim();
      final city = _cityCtrl.text.trim();
      final district = _districtCtrl.text.trim();
      final neighborhood = _neighborhoodCtrl.text.trim();
      final street = _streetCtrl.text.trim();
      final postalCode = _zipCtrl.text.trim();
      final extraLine = _lineCtrl.text.trim();

      // line1 = mahalle + sokak + ekstra adres satırı
      final line1Parts = <String>[
        neighborhood,
        street,
        extraLine,
      ].where((e) => e.isNotEmpty).toList();

      final line1 = line1Parts.join(' ');

      await ref.set({
        'id': ref.id,
        'title': title,                 // web ile uyumlu adres başlığı
        'fullName': fullName,
        'phone': phone,
        'tc': tc,                       // web tarafındaki tc ile aynı alan
        'city': city,
        'district': district,
        'neighborhood': neighborhood,   // ekstra detay, web isterse kullanır
        'street': street,               // ekstra detay
        'line1': line1,                 // web tarafı bunu ana adres satırı olarak okuyor
        'postalCode': postalCode,       // web: postalCode || zipCode diye okuyor, artık direkt postalCode
        'country': 'Türkiye',
        'isDefault': false,             // mobilde şimdilik varsayılan seçimi yok
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Adres kaydedilemedi: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F17),
      appBar: AppBar(
        title: const Text('Yeni Adres'),
        backgroundColor: const Color(0xFF0B0F17),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Adres Başlığı (web ile aynı mantıkta)
              _field(
                controller: _titleCtrl,
                label: 'Adres Başlığı (Örn: Ev, İş)',
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Adres başlığı girin' : null,
              ),
              const SizedBox(height: 12),

              _field(
                controller: _fullnameCtrl,
                label: 'Ad Soyad',
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Ad soyad girin' : null,
              ),
              const SizedBox(height: 12),

              _field(
                controller: _phoneCtrl,
                label: 'Telefon Numarası',
                type: TextInputType.phone,
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Telefon girin' : null,
              ),
              const SizedBox(height: 12),

              _field(
                controller: _tcCtrl,
                label: 'TC Kimlik Numarası',
                type: TextInputType.number,
                validator: (v) {
                  final val = v?.trim() ?? '';
                  if (val.isEmpty) return 'TC Kimlik numarası zorunludur';
                  if (val.length != 11 || int.tryParse(val) == null) {
                    return 'TC Kimlik numarası 11 haneli olmalıdır';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _field(
                      controller: _cityCtrl,
                      label: 'İl',
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'İl girin' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _field(
                      controller: _districtCtrl,
                      label: 'İlçe',
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'İlçe girin' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _field(
                controller: _neighborhoodCtrl,
                label: 'Mahalle',
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Mahalle girin' : null,
              ),
              const SizedBox(height: 12),

              _field(
                controller: _streetCtrl,
                label: 'Sokak / Cadde',
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Sokak girin' : null,
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _field(
                      controller: _zipCtrl,
                      label: 'Posta Kodu',
                      type: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _field(
                      controller: _lineCtrl,
                      label: 'Adres Satırı (Bina / Daire / Not)',
                      maxLines: 1,
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Adres satırı girin'
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD166),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text(
                          'Adresi Kaydet',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
