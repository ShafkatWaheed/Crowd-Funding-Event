import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../widgets/app_toast.dart';
import '../../providers/venue_provider.dart';
import '../../services/mapbox_geocoding_service.dart';

class CreateVenueScreen extends StatefulWidget {
  const CreateVenueScreen({super.key});

  @override
  State<CreateVenueScreen> createState() => _CreateVenueScreenState();
}

class _CreateVenueScreenState extends State<CreateVenueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _provinceCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();
  bool _isLoading = false;

  // Geocoding state
  double? _lat;
  double? _lng;
  List<GeocodingResult> _suggestions = [];
  bool _showSuggestions = false;
  bool _geocoding = false;
  Timer? _debounce;

  Future<void> _onAddressChanged(String query) async {
    _lat = null;
    _lng = null;
    _debounce?.cancel();
    if (query.trim().length < 3) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _geocoding = true);
      final results = await MapboxGeocodingService.search(query);
      if (mounted) {
        setState(() {
          _suggestions = results;
          _showSuggestions = results.isNotEmpty;
          _geocoding = false;
        });
      }
    });
  }

  void _selectSuggestion(GeocodingResult result) {
    setState(() {
      _addressCtrl.text = result.fullAddress;
      if (result.city != null && result.city!.isNotEmpty) {
        _cityCtrl.text = result.city!;
      }
      if (result.province != null && result.province!.isNotEmpty) {
        _provinceCtrl.text = result.province!;
      }
      _lat = result.lat;
      _lng = result.lng;
      _showSuggestions = false;
      _suggestions = [];
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final repo = context.read<VenueProvider>();
      await repo.createVenue({
        'name': _nameCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'province': _provinceCtrl.text.trim(),
        'max_capacity': int.parse(_capacityCtrl.text),
        if (_lat != null) 'lat': _lat,
        if (_lng != null) 'lng': _lng,
      });

      if (mounted) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        } else {
          context.go('/venues');
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.fromError(context, e, fallback: 'Failed to create venue');
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _provinceCtrl.dispose();
    _capacityCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: const Text('Add Venue'),
      ),
      body: GestureDetector(
        onTap: () => setState(() => _showSuggestions = false),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Venue Name'),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // ── Address with Mapbox autocomplete ──
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _addressCtrl,
                          decoration: InputDecoration(
                            labelText: 'Address',
                            suffixIcon: _geocoding
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                                  )
                                : _lat != null
                                    ? const Icon(Icons.check_circle,
                                        color: AppTheme.successColor, size: 20)
                                    : null,
                          ),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Required' : null,
                          onChanged: _onAddressChanged,
                        ),
                        if (_showSuggestions && _suggestions.isNotEmpty)
                          Container(
                            constraints: const BoxConstraints(maxHeight: 200),
                            margin: const EdgeInsets.only(top: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.cardOf(context),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.dividerOf(context)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: _suggestions.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final s = _suggestions[index];
                                return ListTile(
                                  dense: true,
                                  leading: Icon(
                                      Icons.location_on_outlined,
                                      size: 20,
                                      color: AppTheme.textSecondaryOf(context)),
                                  title: Text(
                                    s.fullAddress,
                                    style: TextStyle(fontSize: 13, color: AppTheme.textPrimaryOf(context)),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () => _selectSuggestion(s),
                                );
                              },
                            ),
                          ),
                        // Location status
                        if (_lat != null && _lng != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'Location found (${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)})',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.successColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _cityCtrl,
                            decoration:
                                const InputDecoration(labelText: 'City'),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Required'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _provinceCtrl,
                            decoration:
                                const InputDecoration(labelText: 'Province'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _capacityCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Max Capacity'),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Required';
                        if (int.tryParse(v) == null) return 'Enter a number';
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Create Venue'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
