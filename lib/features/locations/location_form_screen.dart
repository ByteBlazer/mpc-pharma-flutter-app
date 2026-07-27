import 'package:flutter/material.dart';

import '../../api/api_client.dart';
import '../../widgets/app_screen_scaffold.dart';
import '../users/user_models.dart';

class LocationFormScreen extends StatefulWidget {
  const LocationFormScreen({super.key, required this.apiClient, this.location});

  final ApiClient apiClient;
  final BaseLocation? location;

  @override
  State<LocationFormScreen> createState() => _LocationFormScreenState();
}

class _LocationFormScreenState extends State<LocationFormScreen> {
  late final TextEditingController _nameController;
  bool _isSaving = false;
  String? _errorMessage;

  bool get _isEditing => widget.location != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.location?.name ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _clearErrorMessage() {
    if (_errorMessage != null) setState(() => _errorMessage = null);
  }

  Future<void> _save() async {
    final locationName = _nameController.text.trim();
    if (locationName.isEmpty) {
      setState(() => _errorMessage = 'Enter location name.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final request = BaseLocationSaveRequest(name: locationName);

    try {
      final location = widget.location;
      if (location == null) {
        await widget.apiClient.createBaseLocation(request: request);
      } else {
        await widget.apiClient.updateBaseLocation(
          id: location.id,
          request: request,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScreenScaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Location' : 'Add Location'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _nameController,
                        textInputAction: TextInputAction.done,
                        onChanged: (_) => _clearErrorMessage(),
                        onSubmitted: (_) {
                          if (!_isSaving) _save();
                        },
                        decoration: const InputDecoration(
                          labelText: 'Location name',
                        ),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      if (_isSaving)
                        const Center(child: CircularProgressIndicator())
                      else
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _save,
                                child: Text(
                                  _isEditing ? 'Save Location' : 'Add Location',
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
