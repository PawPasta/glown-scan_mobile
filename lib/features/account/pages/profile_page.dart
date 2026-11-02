import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../services/account_api.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({required this.accountApi, super.key});

  final AccountApiContract accountApi;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const _genders = <String, String>{
    'MALE': 'Male',
    'FEMALE': 'Female',
    'OTHERS': 'Others',
    'PREFER_NOT_TO_SAY': 'Prefer not to say',
  };

  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  final _imagePicker = ImagePicker();
  late Future<UserProfile> _profileFuture = widget.accountApi.getProfile();
  UserProfile? _profile;
  String? _gender;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _dateOfBirthController.dispose();
    super.dispose();
  }

  void _startEditing(UserProfile profile) {
    _fullNameController.text = profile.fullName ?? '';
    _dateOfBirthController.text = _formatDate(profile.dateOfBirth);
    _gender = _genders.containsKey(profile.gender) ? profile.gender : null;
    setState(() => _isEditing = true);
  }

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) return '';
    if (value.length >= 10) {
      final date = value.substring(0, 10);
      if (DateTime.tryParse(date) != null) return date;
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    return '${parsed.year.toString().padLeft(4, '0')}-'
        '${parsed.month.toString().padLeft(2, '0')}-'
        '${parsed.day.toString().padLeft(2, '0')}';
  }

  Future<void> _selectDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final minimumDate = DateTime(1900);
    final selectedDate = DateTime.tryParse(_dateOfBirthController.text);
    final initialDate = selectedDate == null || selectedDate.isAfter(today)
        ? today
        : selectedDate.isBefore(minimumDate)
        ? minimumDate
        : selectedDate;
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: minimumDate,
      lastDate: today,
    );
    if (date == null || !mounted) return;
    _dateOfBirthController.text = _formatDate(date.toIso8601String());
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final updated = await widget.accountApi.updateProfile(
        fullName: _fullNameController.text.trim().isEmpty
            ? null
            : _fullNameController.text.trim(),
        dateOfBirth: _dateOfBirthController.text.isEmpty
            ? null
            : _dateOfBirthController.text,
        gender: _gender,
      );
      if (!mounted) return;
      setState(() {
        _profile = updated;
        _isEditing = false;
      });
      _showMessage('Profile updated successfully.');
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message, error: true);
    } catch (error) {
      if (mounted) {
        _showMessage('Could not update your profile: $error', error: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _selectAvatar() async {
    if (_isUploadingAvatar) return;
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image == null || !mounted) return;
      setState(() => _isUploadingAvatar = true);
      final updated = await widget.accountApi.uploadAvatar(image);
      if (!mounted) return;
      setState(() => _profile = updated);
      _showMessage('Profile photo updated successfully.');
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message, error: true);
    } catch (error) {
      if (mounted) {
        _showMessage(
          'Could not update your profile photo: $error',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  void _cancelEditing() {
    final profile = _profile;
    if (profile != null) {
      _fullNameController.text = profile.fullName ?? '';
      _dateOfBirthController.text = _formatDate(profile.dateOfBirth);
      _gender = _genders.containsKey(profile.gender) ? profile.gender : null;
    }
    setState(() => _isEditing = false);
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  Widget _avatar(UserProfile profile) => Center(
    child: Stack(
      children: [
        CircleAvatar(
          radius: 52,
          backgroundColor: AppTheme.sand,
          backgroundImage: profile.avatarUrl == null
              ? null
              : NetworkImage(profile.avatarUrl!),
          child: profile.avatarUrl == null
              ? const Icon(
                  Icons.person_outline_rounded,
                  size: 52,
                  color: AppTheme.deepRose,
                )
              : null,
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: IconButton.filled(
            tooltip: 'Change profile photo',
            onPressed: _isUploadingAvatar ? null : _selectAvatar,
            icon: _isUploadingAvatar
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.camera_alt_outlined),
          ),
        ),
      ],
    ),
  );

  Widget _readOnlyProfile(UserProfile profile) => Column(
    children: [
      _profileField('Full name', profile.fullName),
      _profileField('Date of birth', _formatDate(profile.dateOfBirth)),
      _profileField(
        'Gender',
        profile.gender == null
            ? null
            : _genders[profile.gender] ?? profile.gender,
      ),
    ],
  );

  Widget _profileField(String label, String? value) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: Text(value == null || value.isEmpty ? 'Not specified' : value),
  );

  Widget _editForm() => Form(
    key: _formKey,
    child: Column(
      children: [
        TextFormField(
          controller: _fullNameController,
          enabled: !_isSaving,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Full name'),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _dateOfBirthController,
          readOnly: true,
          enabled: !_isSaving,
          onTap: _selectDate,
          decoration: const InputDecoration(
            labelText: 'Date of birth',
            suffixIcon: Icon(Icons.calendar_today_outlined),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _gender,
          decoration: const InputDecoration(labelText: 'Gender'),
          items: _genders.entries
              .map(
                (entry) => DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text(entry.value),
                ),
              )
              .toList(),
          onChanged: _isSaving
              ? null
              : (value) => setState(() => _gender = value),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Profile')),
    body: FutureBuilder<UserProfile>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 40),
                  const SizedBox(height: 12),
                  const Text(
                    'We could not load your profile.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => setState(
                      () => _profileFuture = widget.accountApi.getProfile(),
                    ),
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final profile = _profile ?? snapshot.data!;
        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            _avatar(profile),
            const SizedBox(height: 24),
            if (_isEditing) _editForm() else _readOnlyProfile(profile),
            const SizedBox(height: 24),
            if (_isEditing) ...[
              FilledButton(
                onPressed: _isSaving ? null : _saveProfile,
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save changes'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _isSaving ? null : _cancelEditing,
                child: const Text('Cancel'),
              ),
            ] else
              OutlinedButton.icon(
                onPressed: () => _startEditing(profile),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit profile'),
              ),
          ],
        );
      },
    ),
  );
}
