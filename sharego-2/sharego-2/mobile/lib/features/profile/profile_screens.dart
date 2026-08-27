import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_theme.dart';
import '../../core/providers.dart';
import '../common/widgets.dart';
import '../common/coach.dart';

String _kycUploadFilename(XFile f) {
  final n = f.name.trim();
  if (n.isNotEmpty) return n;
  final p = f.path.replaceAll('\\', '/');
  final slash = p.lastIndexOf('/');
  if (slash >= 0 && slash < p.length - 1) return p.substring(slash + 1);
  return 'upload.jpg';
}

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Map<String, dynamic>? _user;
  bool _loading = true;

  final _infoKey = GlobalKey();
  final _kycKey = GlobalKey();
  final _helpKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadProfile();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Coach.show(
        context,
        storageKey: 'has_seen_profile_guide',
        steps: [
          CoachStep(targetKey: _infoKey, title: 'Profile info', body: 'Keep your name and city updated.'),
          CoachStep(targetKey: _kycKey, title: 'Verification', body: 'Verify ID to increase trust as traveler.'),
          CoachStep(targetKey: _helpKey, title: 'Help & logout', body: 'Get support or sign out here.'),
        ],
      );
    });
  }

  Future<void> _loadProfile() async {
    try {
      final service = ref.read(profileServiceProvider);
      final result = await service.getMe();
      if (mounted) setState(() { _user = result; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _user?['email']?.toString() ?? '';
    final name = _user?['name']?.toString() ?? '';
    final city = _user?['city']?.toString() ?? '';
    final country = _user?['country']?.toString() ?? '';
    final location = [city, country].where((s) => s.isNotEmpty).join(', ');
    final rating = _user?['rating_avg']?.toString() ?? '0.0';
    final roles = (_user?['roles'] as List?)?.join(', ') ?? 'user';
    final initial = (name.isNotEmpty ? name : email).isNotEmpty
        ? (name.isNotEmpty ? name : email)[0].toUpperCase()
        : 'U';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Help',
            icon: const Icon(Icons.help_outline),
            onPressed: () => Coach.show(
              context,
              force: true,
              storageKey: 'has_seen_profile_guide',
              steps: [
                CoachStep(targetKey: _infoKey, title: 'Profile info', body: 'Keep your name and city updated.'),
                CoachStep(targetKey: _kycKey, title: 'Verification', body: 'Verify ID to increase trust as traveler.'),
                CoachStep(targetKey: _helpKey, title: 'Help & logout', body: 'Get support or sign out here.'),
              ],
            ),
          ),
        ],
      ),
      body: _loading
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: SkeletonList(items: 4, itemHeight: 60),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    key: _infoKey,
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: AppTheme.primary,
                        child: Text(
                          initial,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 22),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if (name.isNotEmpty)
                            Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          Text(email, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                          if (location.isNotEmpty)
                            Text(location, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          Text('Rating $rating  •  $roles', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        ]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ListTile(
                    leading: const Icon(Icons.account_balance_wallet),
                    title: const Text('My Wallet'),
                    onTap: () => context.push('/wallet'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.edit),
                    title: const Text('Edit Profile'),
                    onTap: () async {
                      await context.push('/profile/edit');
                      _loadProfile();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.rate_review),
                    title: const Text('My Reviews'),
                    onTap: () => context.push('/profile/reviews'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.verified_user),
                    title: const Text('KYC Status'),
                    key: _kycKey,
                    onTap: () => context.push('/profile/kyc'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings),
                    title: const Text('Settings'),
                    onTap: () => context.push('/profile/settings'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Logout'),
                    key: _helpKey,
                    onTap: () => context.push('/profile/logout'),
                  ),
                ],
              ),
            ),
    );
  }
}

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});
  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = await ref.read(profileServiceProvider).getMe();
      _nameCtrl.text = user['name']?.toString() ?? '';
      _phoneCtrl.text = user['phone']?.toString() ?? '';
      _cityCtrl.text = user['city']?.toString() ?? '';
      _countryCtrl.text = user['country']?.toString() ?? '';
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(profileServiceProvider).updateMe(
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        country: _countryCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: ${e.toString().replaceFirst("Exception: ", "")}')),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _cityCtrl.dispose();
    _countryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: _loading
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: SkeletonList(items: 3, itemHeight: 56),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _cityCtrl,
                    decoration: const InputDecoration(
                      labelText: 'City',
                      prefixIcon: Icon(Icons.location_city_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _countryCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Country',
                      prefixIcon: Icon(Icons.flag_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  LoadingButton(
                    onPressed: _save,
                    label: 'Save',
                    isLoading: _saving,
                  ),
                ],
              ),
            ),
    );
  }
}

class KycScreen extends ConsumerStatefulWidget {
  const KycScreen({super.key});

  @override
  ConsumerState<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends ConsumerState<KycScreen> {
  String _status = 'loading';
  String? _rejectReason;
  bool _submitting = false;
  String? _error;
  String? _success;
  String? _docPath;
  String? _selfiePath;
  String? _passportPath;
  String? _docServerPath;
  String? _selfieServerPath;
  String? _passportServerPath;

  @override
  void initState() {
    super.initState();
    _loadKycStatus();
  }

  Future<void> _loadKycStatus() async {
    try {
      final service = ref.read(profileServiceProvider);
      final result = await service.getKycStatus();
      if (mounted) {
        setState(() {
          _status = result['status']?.toString() ?? 'not_submitted';
          _rejectReason = result['reject_reason']?.toString();
        });
      }
    } catch (_) {
      if (mounted) setState(() => _status = 'not_submitted');
    }
  }

  Future<void> _pickDoc() async {
  final picker = ImagePicker();
  final image = await picker.pickImage(source: ImageSource.gallery);
  if (image == null) return;

  setState(() {
    _docPath = _kycUploadFilename(image);
    _docServerPath = null;
    _error = null;
  });

  try {
    final bytes = await image.readAsBytes();
    final result = await ref.read(profileServiceProvider).uploadMediaBytes(
          bytes,
          _kycUploadFilename(image),
        );

    if (mounted) {
      setState(() {
        _docServerPath = result['path']?.toString();
      });
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        _error = 'Doc upload failed: ${e.toString()}';
      });
    }
  }
}

  Future<void> _pickSelfie() async {
  final picker = ImagePicker();
  final image = await picker.pickImage(
    source: ImageSource.camera,
    preferredCameraDevice: CameraDevice.front,
  );

  if (image == null) return;

  setState(() {
    _selfiePath = _kycUploadFilename(image);
    _selfieServerPath = null;
    _error = null;
  });

  try {
    final bytes = await image.readAsBytes();
    final result = await ref.read(profileServiceProvider).uploadMediaBytes(
          bytes,
          _kycUploadFilename(image),
        );

    if (mounted) {
      setState(() {
        _selfieServerPath = result['path']?.toString();
      });
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        _error = 'Selfie upload failed: ${e.toString()}';
      });
    }
  }
}
  Future<void> _pickPassport() async {
  final picker = ImagePicker();
  final image = await picker.pickImage(source: ImageSource.gallery);

  if (image == null) return;

  setState(() {
    _passportPath = _kycUploadFilename(image);
    _passportServerPath = null;
    _error = null;
  });

  try {
    final bytes = await image.readAsBytes();
    final result = await ref.read(profileServiceProvider).uploadMediaBytes(
          bytes,
          _kycUploadFilename(image),
        );

    if (mounted) {
      setState(() {
        _passportServerPath = result['path']?.toString();
      });
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        _error = 'Passport upload failed: ${e.toString()}';
      });
    }
  }
}

  Future<void> _submitKyc() async {
    if (_docServerPath == null) {
      setState(() => _error = 'Please upload your CNIC / Passport first.');
      return;
    }
    setState(() { _submitting = true; _error = null; });
    try {
      final service = ref.read(profileServiceProvider);
      await service.submitKyc(
        docType: 'cnic',
        docUrl: _docServerPath!,
        selfieUrl: _selfieServerPath,
        passportUrl: _passportServerPath,
      );
      if (mounted) {
        setState(() {
          _success = 'KYC submitted! Awaiting admin approval.';
          _submitting = false;
          _status = 'pending';
          _rejectReason = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst("Exception: ", ""); _submitting = false; });
    }
  }

  bool get _canSubmit => _status != 'approved' && _status != 'loading';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('KYC Verification')),
      body: RefreshIndicator(
        onRefresh: _loadKycStatus,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              StatusPill(_status),
              const SizedBox(height: 16),
              if (_status == 'rejected' && _rejectReason != null && _rejectReason!.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.danger.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Rejected: $_rejectReason', style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w500))),
                    ],
                  ),
                ),
              if (_success != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.success.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: AppTheme.success, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_success!, style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.w500))),
                    ],
                  ),
                ),
              if (_error != null) ErrorBanner(_error!),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    _UploadArea(
                      label: 'CNIC / Passport',
                      icon: Icons.badge_outlined,
                      selectedPath: _docPath,
                      uploaded: _docServerPath != null,
                      onTap: _canSubmit ? _pickDoc : () {},
                    ),
                    const SizedBox(height: 12),
                    _UploadArea(
                      label: 'Selfie',
                      icon: Icons.camera_alt_outlined,
                      selectedPath: _selfiePath,
                      uploaded: _selfieServerPath != null,
                      onTap: _canSubmit ? _pickSelfie : () {},
                    ),
                    const SizedBox(height: 12),
                    _UploadArea(
                      label: 'Passport Photo (required for travelers)',
                      icon: Icons.flight_outlined,
                      selectedPath: _passportPath,
                      uploaded: _passportServerPath != null,
                      onTap: _canSubmit ? _pickPassport : () {},
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'Passport photo is required if you plan to be a traveler.',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
              LoadingButton(
                onPressed: _canSubmit ? _submitKyc : null,
                label: _status == 'approved' ? 'Already Approved' : (_status == 'rejected' ? 'Resubmit KYC' : 'Submit KYC'),
                isLoading: _submitting,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadArea extends StatelessWidget {
  const _UploadArea({required this.label, required this.icon, required this.onTap, this.selectedPath, this.uploaded = false});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final String? selectedPath;
  final bool uploaded;

  @override
  Widget build(BuildContext context) {
    final hasFile = selectedPath != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: hasFile ? AppTheme.primary.withValues(alpha: 0.08) : AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: uploaded ? AppTheme.success : (hasFile ? AppTheme.primary : const Color(0xFFE0E2EB)),
            width: hasFile ? 2 : 1,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                uploaded ? Icons.check_circle : icon,
                size: 36,
                color: uploaded ? AppTheme.success : AppTheme.primary,
              ),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                uploaded ? 'Uploaded' : (hasFile ? 'Uploading...' : 'Tap to upload'),
                style: TextStyle(fontSize: 12, color: uploaded ? AppTheme.success : Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notifications = true;
  String _language = 'English';
  String _theme = 'System';

  static const _themeCycle = ['System', 'Light', 'Dark'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _notifications = prefs.getBool('settings_notifications') ?? true;
        _language = prefs.getString('settings_language') ?? 'English';
        _theme = prefs.getString('settings_theme') ?? 'System';
      });
    }
  }

  ThemeMode _toThemeMode(String value) {
    switch (value) {
      case 'Light':
        return ThemeMode.light;
      case 'Dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Preferences', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            value: _notifications,
            onChanged: (val) async {
              setState(() => _notifications = val);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('settings_notifications', val);
            },
            title: const Text('Notifications'),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Language'),
            subtitle: Text(_language),
            onTap: () async {
              final next = _language == 'English' ? 'Urdu' : 'English';
              setState(() => _language = next);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('settings_language', next);
            },
          ),
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: const Text('Theme'),
            subtitle: Text(_theme),
            onTap: () async {
              final idx = _themeCycle.indexOf(_theme);
              final next = _themeCycle[(idx + 1) % _themeCycle.length];
              setState(() => _theme = next);
              ref.read(themeModeProvider.notifier).set(_toThemeMode(next));
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('settings_theme', next);
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('About', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('App Version'),
            subtitle: Text('1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.support_agent),
            title: const Text('Support'),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class LogoutScreen extends ConsumerWidget {
  const LogoutScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Logout')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.danger.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.logout, size: 40, color: AppTheme.danger),
              ),
              const SizedBox(height: 16),
              const Text(
                'Are you sure you want to logout?',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'You will need to sign in again to access your account.',
                style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.danger,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    await ref.read(authStorageProvider).clear();
                    if (context.mounted) context.go('/auth/login');
                  },
                  child: const Text('Yes, logout'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
