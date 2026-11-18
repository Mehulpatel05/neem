import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/app_providers.dart';
import '../../core/auth/auth_service.dart';
import '../../app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/app_button.dart';
import '../../core/network/api_client.dart';

class IdentitySetupScreen extends StatefulWidget {
  const IdentitySetupScreen({super.key});

  @override
  State<IdentitySetupScreen> createState() => _IdentitySetupScreenState();
}

class _IdentitySetupScreenState extends State<IdentitySetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _handleController = TextEditingController();

  String? _selectedCity;
  String? _selectedZone;
  bool _isLoading = false;

  static const Map<String, List<String>> _cityZones = {
    'Vadodara': ['Alkapuri', 'Sayajigunj', 'Fatehgunj', 'Manjalpur', 'Gotri'],
    'Ahmedabad': ['Satellite', 'Prahladnagar', 'Navrangpura', 'Bodakdev', 'Vastrapur'],
    'Mumbai': ['Bandra', 'Andheri', 'Powai', 'South Mumbai', 'Juhu'],
    'Delhi': ['Connaught Place', 'Saket', 'Dwarka', 'Gurgaon', 'Noida'],
    'Bangalore': ['Koramangala', 'Indiranagar', 'Whitefield', 'HSR Layout', 'Jayanagar'],
  };

  List<String> get _cities => _cityZones.keys.toList();
  List<String> get _zones => _selectedCity == null ? [] : _cityZones[_selectedCity]!;

  @override
  void dispose() {
    _displayNameController.dispose();
    _handleController.dispose();
    super.dispose();
  }

  String? _validateDisplayName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Display name is required';
    }
    return null;
  }

  String? _validateHandle(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final regex = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!regex.hasMatch(value.trim())) {
      return 'Handle can only contain letters, numbers, and underscores';
    }
    return null;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await context.read<AuthNotifier>().saveProfile(
        displayName: _displayNameController.text.trim(),
        handle: _handleController.text.trim().isEmpty
            ? null
            : _handleController.text.trim(),
        city: _selectedCity,
        zone: _selectedZone,
      );
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(AppRouter.profileSaved);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _decoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: AppColors.surfaceVariantLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.dividerLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.dividerLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Set up your identity', style: textTheme.titleLarge),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Tell us about yourself',
              style: AppTheme.lightTheme().textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'We never share your exact GPS location',
              style: TextStyle(
                color: AppColors.primary,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 24),
            AppTextField(
              controller: _displayNameController,
              label: 'Display name',
              hint: 'Enter your display name',
              validator: _validateDisplayName,
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _handleController,
              label: 'Handle / username',
              hint: 'e.g. john_doe',
              validator: _validateHandle,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: _decoration('City'),
              value: _selectedCity,
              items: _cities
                  .map((city) => DropdownMenuItem(
                        value: city,
                        child: Text(city),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCity = value;
                  _selectedZone = null;
                });
              },
              validator: (value) =>
                  value == null ? 'Please select a city' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: _decoration('Zone'),
              value: _selectedZone,
              items: _zones
                  .map((zone) => DropdownMenuItem(
                        value: zone,
                        child: Text(zone),
                      ))
                  .toList(),
              onChanged: _selectedCity == null
                  ? null
                  : (value) {
                      setState(() => _selectedZone = value);
                    },
              validator: (value) =>
                  value == null ? 'Please select a zone' : null,
            ),
            const SizedBox(height: 24),
            AppButton(
              text: 'Continue',
              onPressed: _saveProfile,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }
}

