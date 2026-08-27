import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_theme.dart';
import '../../core/providers.dart';
import '../common/widgets.dart';

class AuditCenterScreen extends ConsumerStatefulWidget {
  const AuditCenterScreen({super.key});

  @override
  ConsumerState<AuditCenterScreen> createState() => _AuditCenterScreenState();
}

class _AuditCenterScreenState extends ConsumerState<AuditCenterScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Use the AI service to ask about user's disputes/issues
      final aiService = ref.read(aiServiceProvider);
      final response = await aiService.chat('Show my recent bookings and any issues');
      if (mounted) {
        setState(() {
          // The AI returns a text response; we'll show it in a simple list
          _logs = [
            {'title': 'AI Assistant Response', 'content': response['reply']?.toString() ?? 'No issues found.'},
          ];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Audit & Issues'),
          elevation: 0,
          bottom: const TabBar(tabs: [
            Tab(text: 'My Reports'),
            Tab(text: 'Status'),
          ]),
          actions: [
            TextButton(
              onPressed: () => context.push('/audit/report/new'),
              child: const Text('Report', style: TextStyle(color: AppTheme.primary)),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            // My Reports tab
            _loading
                ? const Padding(padding: EdgeInsets.all(16), child: SkeletonList(items: 3, itemHeight: 60))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ErrorBanner(_error!),
                            const SizedBox(height: 8),
                            ElevatedButton(onPressed: _load, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: _logs.isEmpty
                            ? ListView(children: [
                                const SizedBox(height: 100),
                                Center(
                                  child: Column(
                                    children: [
                                      Icon(Icons.check_circle_outline, size: 64, color: theme.colorScheme.onSurfaceVariant),
                                      const SizedBox(height: 12),
                                      Text('No issues reported', style: theme.textTheme.titleMedium),
                                    ],
                                  ),
                                ),
                              ])
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _logs.length,
                                itemBuilder: (context, i) {
                                  final log = _logs[i];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(log['title']?.toString() ?? '', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                                          const SizedBox(height: 8),
                                          Text(log['content']?.toString() ?? '', style: theme.textTheme.bodyMedium),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
            // Status tab — link to AI assistant for real-time help
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.support_agent, size: 64, color: AppTheme.primary.withValues(alpha: 0.6)),
                    const SizedBox(height: 16),
                    Text('Need help?', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(
                      'Use the AI Assistant to check status of your bookings, report disputes, or get help.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () => context.push('/ai'),
                      icon: const Icon(Icons.chat),
                      label: const Text('Open AI Assistant'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class IssueDetailScreen extends StatelessWidget {
  const IssueDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Issue #$id'), elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Issue Details', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text('Issue #$id has been submitted for review.', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            const StatusPill('Under Review'),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => context.push('/audit/$id/add-evidence'),
                    child: const Text('Add Evidence'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.push('/ai'),
                    child: const Text('Contact Support'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ReportIssueScreen extends ConsumerStatefulWidget {
  const ReportIssueScreen({super.key});

  @override
  ConsumerState<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends ConsumerState<ReportIssueScreen> {
  String? _category;
  final _descCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    if (_category == null || _descCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please select a category and describe the issue.');
      return;
    }

    setState(() { _submitting = true; _error = null; });
    try {
      final aiService = ref.read(aiServiceProvider);
      await aiService.chat(
        'I want to report an issue. Category: $_category. Description: ${_descCtrl.text.trim()}',
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      context.go('/audit');
      messenger.showSnackBar(
        const SnackBar(content: Text('Issue reported successfully')),
      );
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _submitting = false; });
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report an Issue'), elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Category'),
              initialValue: _category,
              items: const [
                DropdownMenuItem(value: 'OTP', child: Text('Wrong OTP entered')),
                DropdownMenuItem(value: 'Marketplace', child: Text('Marketplace issue')),
                DropdownMenuItem(value: 'Abuse', child: Text('User harassment')),
                DropdownMenuItem(value: 'Other', child: Text('Other')),
              ],
              onChanged: (v) => setState(() => _category = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Describe what happened...',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              ErrorBanner(_error!),
            ],
            const SizedBox(height: 16),
            LoadingButton(
              onPressed: _submit,
              label: 'Submit Report',
              isLoading: _submitting,
            ),
          ],
        ),
      ),
    );
  }
}

class AddEvidenceScreen extends ConsumerStatefulWidget {
  const AddEvidenceScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<AddEvidenceScreen> createState() => _AddEvidenceScreenState();
}

class _AddEvidenceScreenState extends ConsumerState<AddEvidenceScreen> {
  final _noteCtrl = TextEditingController();
  Uint8List? _photoBytes;
  String _photoFilename = 'evidence.jpg';
  bool _submitting = false;

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200);
    if (file != null && mounted) {
      final bytes = await file.readAsBytes();
      final name = file.name.trim().isNotEmpty ? file.name : 'evidence.jpg';
      setState(() {
        _photoBytes = bytes;
        _photoFilename = name;
      });
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      if (_photoBytes != null) {
        final profileService = ref.read(profileServiceProvider);
        await profileService.uploadMediaBytes(_photoBytes!, _photoFilename);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Evidence attached')),
        );
        context.go('/audit/${widget.id}');
      }
    } catch (e) {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Add Evidence'), elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(labelText: 'Note'),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickPhoto,
              child: Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.outline),
                ),
                child: _photoBytes != null
                    ? const Center(child: Icon(Icons.check_circle, color: AppTheme.success, size: 48))
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, size: 40, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(height: 8),
                          Text('Tap to upload photo', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            LoadingButton(
              onPressed: _submit,
              label: 'Attach Evidence',
              isLoading: _submitting,
            ),
          ],
        ),
      ),
    );
  }
}

class AdminAuditPanelScreen extends ConsumerStatefulWidget {
  const AdminAuditPanelScreen({super.key});

  @override
  ConsumerState<AdminAuditPanelScreen> createState() => _AdminAuditPanelScreenState();
}

class _AdminAuditPanelScreenState extends ConsumerState<AdminAuditPanelScreen> {
  List<Map<String, dynamic>> _bookings = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final service = ref.read(featureAServiceProvider);
      final result = await service.listBookings();
      if (mounted) setState(() { _bookings = result; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Audit Panel'), elevation: 0),
      body: _loading
          ? const Padding(padding: EdgeInsets.all(16), child: SkeletonList(items: 5, itemHeight: 60))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ErrorBanner(_error!),
                      const SizedBox(height: 8),
                      ElevatedButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _bookings.length,
                    itemBuilder: (context, i) {
                      final b = _bookings[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          title: Text('Booking #${b['id']}', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                          subtitle: Text('Status: ${b['status']} • Amount: ${b['currency'] ?? 'PKR'} ${b['amount'] ?? '-'}'),
                          trailing: StatusPill(b['status']?.toString() ?? ''),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
