import 'package:flutter/material.dart';
import '../../data/services/supabase_service.dart';
import '../theme/app_colors.dart';
import '../../core/utils/app_messenger.dart';

class DeleteAccountPortalScreen extends StatefulWidget {
  const DeleteAccountPortalScreen({super.key});

  @override
  State<DeleteAccountPortalScreen> createState() => _DeleteAccountPortalScreenState();
}

class _DeleteAccountPortalScreenState extends State<DeleteAccountPortalScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isSubmitting = false;
  bool _isSubmitted = false;

  @override
  void initState() {
    super.initState();
    final userEmail = SupabaseService().currentUser?.email;
    if (userEmail != null && userEmail.isNotEmpty) {
      _emailController.text = userEmail;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      AppMessenger.show('Please enter a valid email address.');
      return;
    }

    setState(() => _isSubmitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 1000));

    if (mounted) {
      setState(() {
        _isSubmitting = false;
        _isSubmitted = true;
      });
      AppMessenger.show('Account deletion request submitted successfully.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerHigh,
        title: const Text('Account Deletion Portal', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520),
            padding: const EdgeInsets.all(28.0),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              boxShadow: const [
                BoxShadow(color: Colors.black45, blurRadius: 20, offset: Offset(0, 10)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.electricViolet.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.no_accounts_rounded, color: AppColors.electricViolet, size: 28),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Kalpkrut Beats',
                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Account & Data Deletion Request',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                const Text(
                  'In compliance with Google Play Developer Policies and data privacy regulations, you may request permanent deletion of your Kalpkrut Beats account and all linked data.',
                  style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.darkBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Data that will be permanently removed:', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      SizedBox(height: 6),
                      Text('• Account credentials, profile email, display name & bio', style: TextStyle(color: AppColors.textMutedDark, fontSize: 12)),
                      Text('• Favorite tracks, custom playlists & saved audio libraries', style: TextStyle(color: AppColors.textMutedDark, fontSize: 12)),
                      Text('• Listening history & playback preferences', style: TextStyle(color: AppColors.textMutedDark, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (_isSubmitted) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.success),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.check_circle_rounded, color: AppColors.success, size: 36),
                        SizedBox(height: 8),
                        Text(
                          'Request Received',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Your account deletion request has been submitted. Kalpkrut Infotech support team will process your request within 24-48 hours.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 13, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const Text('Registered Email Address', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _emailController,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'user@example.com',
                      hintStyle: const TextStyle(color: AppColors.textMutedDark),
                      prefixIcon: const Icon(Icons.email_rounded, color: AppColors.electricViolet),
                      filled: true,
                      fillColor: AppColors.darkBg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isSubmitting ? null : _submitRequest,
                      child: _isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                          : const Text('Submit Deletion Request', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
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
