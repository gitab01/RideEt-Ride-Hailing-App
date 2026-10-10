import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

/// Onboarding in two calls: the vehicle row, then the three document photos.
///
/// Each photo is uploaded on its own to /uploads/document, which answers with the stored
/// path; that path is what /driver/documents expects, so the driver never types a URL.
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();

  final _makeCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  String _vehicleType = 'ECONOMY';

  final Map<_DocumentKind, String?> _uploaded = {for (final k in _DocumentKind.values) k: null};

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_makeCtrl, _modelCtrl, _yearCtrl, _plateCtrl, _colorCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pick(_DocumentKind kind) async {
    final shot = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 2000);
    if (shot == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(shot.path, filename: shot.name),
      });
      final res = await ApiClient().dio.post('/uploads/document', data: form);
      if (!mounted) return;
      setState(() => _uploaded[kind] = res.data['data']['url'] as String);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _error = _errorOf(e, 'That photo could not be uploaded'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final missing = _uploaded.entries.where((e) => e.value == null).map((e) => e.key.label).toList();
    if (missing.isNotEmpty) {
      setState(() => _error = 'Add a photo for: ${missing.join(', ')}');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = ApiClient().dio;
      await api.post('/driver/register', data: {
        'vehicleMake': _makeCtrl.text.trim(),
        'vehicleModel': _modelCtrl.text.trim(),
        'vehicleYear': _yearCtrl.text.trim(),
        'licensePlate': _plateCtrl.text.trim().toUpperCase(),
        'vehicleColor': _colorCtrl.text.trim(),
        'vehicleType': _vehicleType,
      });
      await api.post('/driver/documents', queryParameters: {
        'driverLicenseUrl': _uploaded[_DocumentKind.license],
        'vehicleRegistrationUrl': _uploaded[_DocumentKind.registration],
        'insuranceUrl': _uploaded[_DocumentKind.insurance],
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Sent for verification. RideEt reviews documents before you go online.')));
      context.go('/home');
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _error = _errorOf(e, 'Onboarding did not go through'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vehicle and documents')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Vehicle information',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                    child: _Field(
                        controller: _makeCtrl,
                        label: 'Make',
                        hint: 'Toyota',
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null)),
                const SizedBox(width: 12),
                Expanded(
                    child: _Field(
                        controller: _modelCtrl,
                        label: 'Model',
                        hint: 'Corolla',
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _Field(
                        controller: _yearCtrl,
                        label: 'Year',
                        keyboard: TextInputType.number,
                        validator: (v) {
                          final year = int.tryParse((v ?? '').trim());
                          if (year == null || year < 1950 || year > DateTime.now().year + 1) {
                            return 'Enter a valid year';
                          }
                          return null;
                        })),
                const SizedBox(width: 12),
                Expanded(
                    child: _Field(
                        controller: _colorCtrl,
                        label: 'Colour',
                        hint: 'White',
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null)),
              ],
            ),
            const SizedBox(height: 12),
            _Field(
                controller: _plateCtrl,
                label: 'License plate',
                hint: 'AA-1234-B',
                validator: (v) => (v == null || v.trim().length < 4) ? 'Enter the full plate' : null),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _vehicleType,
              decoration: const InputDecoration(labelText: 'Service class'),
              items: const [
                DropdownMenuItem(value: 'ECONOMY', child: Text('Economy')),
                DropdownMenuItem(value: 'STANDARD', child: Text('Standard')),
                DropdownMenuItem(value: 'PREMIUM', child: Text('Premium')),
                DropdownMenuItem(value: 'XL', child: Text('XL')),
              ],
              onChanged: (v) => setState(() => _vehicleType = v ?? 'ECONOMY'),
            ),
            const SizedBox(height: 28),
            const Text('Documents',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Photograph each one clearly; the review team can only approve what it can read.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 14),
            for (final kind in _DocumentKind.values)
              _DocumentTile(
                kind: kind,
                path: _uploaded[kind],
                onTap: () => _pick(kind),
              ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppTheme.errorColor)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52)),
              child: _busy
                  ? const SizedBox(
                      width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Submit for verification', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  static String _errorOf(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) return data['message'] as String;
    if (e.type == DioExceptionType.connectionError) return 'Cannot reach the RideEt server';
    return fallback;
  }
}

enum _DocumentKind {
  license('Driving license'),
  registration('Vehicle registration'),
  insurance('Insurance certificate');

  final String label;
  const _DocumentKind(this.label);
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label, hint;
  final TextInputType keyboard;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    this.hint = '',
    this.keyboard = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      validator: validator,
      decoration: InputDecoration(labelText: label, hintText: hint.isEmpty ? null : hint),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  final _DocumentKind kind;
  final String? path;
  final VoidCallback onTap;

  const _DocumentTile({required this.kind, required this.path, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final done = path != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: done ? AppTheme.onlineColor : Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Icon(done ? Icons.check_circle_outline : Icons.add_a_photo_outlined,
                  color: done ? AppTheme.onlineColor : Colors.grey),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(kind.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(done ? 'Attached' : 'Tap to add a photo',
                        style: TextStyle(
                            fontSize: 12,
                            color: done ? AppTheme.onlineColor : Colors.grey.shade600)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
