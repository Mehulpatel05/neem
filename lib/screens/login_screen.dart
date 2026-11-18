import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_router.dart';
import '../core/providers/app_providers.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isLoading = false;
  bool _otpSent = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleSendOtp() async {
    final raw = _phoneController.text.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your mobile number')),
      );
      return;
    }

    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 10-digit mobile number')),
      );
      return;
    }

    final phone = digits.length == 10
        ? '+91$digits'
        : (digits.startsWith('91') && digits.length == 12
            ? '+$digits'
            : '+91${digits.substring(digits.length - 10)}');

    setState(() => _isLoading = true);
    final authNotifier = context.read<AuthNotifier>();
    final requestId = await authNotifier.loginWithPhone(phone);
    setState(() => _isLoading = false);

    if (!mounted) return;

    if (requestId != null) {
      setState(() => _otpSent = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OTP sent successfully to your WhatsApp!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authNotifier.errorMessage ?? 'Failed to send OTP'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleVerifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the OTP')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final authNotifier = context.read<AuthNotifier>();
    final success = await authNotifier.verifyOtp(otp);
    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login successful!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pushReplacementNamed(AppRouter.cityPulse);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authNotifier.errorMessage ?? 'Invalid OTP'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.eco,
                  size: 64,
                  color: Color(0xFF2E7D32),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Welcome to Neem',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Hyperlocal community platform for your neighborhood',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: 'Mobile Number',
                    hintText: '98765 43210',
                    prefixIcon: Container(
                      width: 70,
                      alignment: Alignment.center,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '+91',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                          SizedBox(width: 8),
                          SizedBox(
                            height: 22,
                            child: VerticalDivider(
                              width: 1,
                              thickness: 1,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    border: const OutlineInputBorder(),
                    counterText: '',
                  ),
                  keyboardType: TextInputType.number,
                  autofillHints: const [],
                  enableSuggestions: false,
                  autocorrect: false,
                  maxLength: 10,
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 16),
                if (_otpSent) ...[
                  TextField(
                    controller: _otpController,
                    decoration: const InputDecoration(
                      labelText: 'OTP Code',
                      hintText: 'Enter 6-digit code',
                      prefixIcon: Icon(Icons.lock_clock),
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                    keyboardType: TextInputType.number,
                    autofillHints: const [],
                    maxLength: 6,
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleVerifyOtp,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Verify & Continue', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _isLoading ? null : _handleSendOtp,
                    child: const Text('Resend OTP'),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleSendOtp,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Send OTP via WhatsApp', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
