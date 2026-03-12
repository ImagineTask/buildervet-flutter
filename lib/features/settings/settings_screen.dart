import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/file_service.dart';
import '../../core/di/service_locator.dart';
import '../../core/widgets/user_avatar.dart';
import '../../core/constants/countries.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../providers/auth_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String? _selectedCountryCode;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  late TextEditingController _nameController;
  late TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    final user = ref.read(appUserProvider).valueOrNull;
    _selectedCountryCode = user?.country ?? 'GB';
    _nameController = TextEditingController(text: user?.name);
    _phoneController = TextEditingController(text: user?.phone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    final user = ref.read(appUserProvider).valueOrNull;
    if (user == null) return;

    setState(() => _isSaving = true);
    try {
      final authService = ref.read(authServiceProvider);
      
      // Update country if changed
      if (_selectedCountryCode != user.country) {
        await authService.updateCountry(user.uid, _selectedCountryCode!);
      }
      
      // Update profile if changed
      if (_nameController.text != user.name || _phoneController.text != user.phone) {
        await authService.updateProfile(
          uid: user.uid,
          name: _nameController.text,
          phone: _phoneController.text,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully')),
        );
        ref.invalidate(appUserProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showChangePasswordDialog() {
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'New Password'),
              obscureText: true,
            ),
            TextField(
              controller: confirmPasswordController,
              decoration: const InputDecoration(labelText: 'Confirm Password'),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (passwordController.text != confirmPasswordController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Passwords do not match'), backgroundColor: AppColors.error),
                );
                return;
              }
              if (passwordController.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password must be at least 6 characters'), backgroundColor: AppColors.error),
                );
                return;
              }

              try {
                await ref.read(authServiceProvider).updatePassword(passwordController.text);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password updated successfully')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
                  );
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadAvatar() async {
    final user = ref.read(appUserProvider).valueOrNull;
    if (user == null) return;

    final fileService = ref.read(fileLocatorProvider);
    final pickedFile = await showModalBottomSheet<PickedFile?>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () async {
                final result = await fileService.pickImage(fromCamera: false);
                if (context.mounted) Navigator.pop(context, result);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () async {
                final result = await fileService.pickImage(fromCamera: true);
                if (context.mounted) Navigator.pop(context, result);
              },
            ),
          ],
        ),
      ),
    );
 
    if (pickedFile != null) {
      setState(() => _isUploadingAvatar = true);
      try {
        final storageService = ref.read(storageLocatorProvider);
        await ref.read(authServiceProvider).updateAvatar(
          uid: user.uid,
          bytes: pickedFile.bytes,
          fileName: pickedFile.name,
          storageService: storageService,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Avatar updated successfully')),
          );
          ref.invalidate(appUserProvider);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to upload avatar: $e'), backgroundColor: AppColors.error),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isUploadingAvatar = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: AppSpacing.md),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveSettings,
              child: const Text('Save'),
            ),
        ],
      ),
      body: SafeArea(
        child: ref.watch(appUserProvider).when(
          data: (user) => ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              _buildSection(
                context,
                'Account Information',
                [
                  _buildInfoTile('Email', user?.email ?? '-'),
                  _buildInfoTile('Role', user?.role ?? '-'),
                  if (user?.company != null) _buildInfoTile('Company', user!.company!),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _buildSection(
                context,
                'Personal Details',
                [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      child: Stack(
                        children: [
                          UserAvatar(
                            radius: 50,
                            avatarUrl: user?.avatarUrl,
                            initials: user?.initials ?? '?',
                          ),
                          if (_isUploadingAvatar)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black26,
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                              ),
                            ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                              child: Container(
                                padding: const EdgeInsets.all(AppSpacing.xs),
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 20,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    child: TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    child: TextField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                        prefixIcon: Icon(Icons.phone),
                      ),
                    ),
                  ),
                  ListTile(
                    title: const Text('Country / Region'),
                    subtitle: Text(_getCountryName(_selectedCountryCode) ?? 'Not set'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _showCountryPicker,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _buildSection(
                context,
                'Security',
                [
                  ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: const Text('Change Password'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _showChangePasswordDialog,
                  ),
                ],
              ),
              // Extra space at bottom to prevent overflow and ensure last items are fully visible
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                letterSpacing: 1.2,
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
      subtitle: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
      dense: true,
    );
  }

  String? _getCountryName(String? code) {
    if (code == null) return null;
    return Countries.all
        .where((c) => c.code == code.toUpperCase())
        .map((c) => c.name)
        .firstOrNull;
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              const SizedBox(height: AppSpacing.md),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Text(
                  'Select Country',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: Countries.all.length,
                  itemBuilder: (context, index) {
                    final country = Countries.all[index];
                    final isSelected = _selectedCountryCode == country.code;
                    return ListTile(
                      title: Text(country.name),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: AppColors.primary)
                          : null,
                      onTap: () {
                        setState(() => _selectedCountryCode = country.code);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
