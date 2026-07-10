import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});
  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final _picker = ImagePicker();
  final Map<String, String?> _uploads = {
    'Driver License': null,
    'Vehicle Registration': null,
    'Insurance Certificate': null,
  };

  final _makeCtrl    = TextEditingController();
  final _modelCtrl   = TextEditingController();
  final _yearCtrl    = TextEditingController();
  final _plateCtrl   = TextEditingController();
  final _colorCtrl   = TextEditingController();
  String _vehicleType = 'ECONOMY';

  Future<void> _pickImage(String key) async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file != null) setState(() => _uploads[key] = file.path);
  }

  void _submit() {
    // TODO: Upload documents and vehicle info via API
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vehicle & Documents')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Vehicle Information',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: TextFormField(controller: _makeCtrl,
                    decoration: const InputDecoration(labelText: 'Make (e.g. Toyota)'))),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _modelCtrl,
                    decoration: const InputDecoration(labelText: 'Model'))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextFormField(controller: _yearCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Year'))),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _colorCtrl,
                    decoration: const InputDecoration(labelText: 'Color'))),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _plateCtrl,
                decoration: const InputDecoration(labelText: 'License Plate')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _vehicleType,
              decoration: const InputDecoration(labelText: 'Vehicle Type'),
              items: ['ECONOMY', 'STANDARD', 'PREMIUM', 'XL']
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _vehicleType = v!),
            ),
            const SizedBox(height: 28),
            const Text('Documents',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ..._uploads.keys.map((key) => _DocumentUploadCard(
              title: key,
              uploaded: _uploads[key] != null,
              onTap: () => _pickImage(key),
            )),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _submit,
              child: const Text('Submit & Continue'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentUploadCard extends StatelessWidget {
  final String title;
  final bool uploaded;
  final VoidCallback onTap;

  const _DocumentUploadCard({required this.title, required this.uploaded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: uploaded ? AppTheme.onlineColor : Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(
              uploaded ? Icons.check_circle : Icons.upload_file,
              color: uploaded ? AppTheme.onlineColor : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w500))),
            Text(uploaded ? 'Uploaded' : 'Tap to upload',
                style: TextStyle(
                    color: uploaded ? AppTheme.onlineColor : Colors.grey,
                    fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
