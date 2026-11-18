import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/app_button.dart';
import '../../app_router.dart';

class CreateMeetupScreen extends StatefulWidget {
  const CreateMeetupScreen({super.key});

  @override
  State<CreateMeetupScreen> createState() => _CreateMeetupScreenState();
}

class _CreateMeetupScreenState extends State<CreateMeetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _cityController = TextEditingController();
  final _seatsController = TextEditingController();
  DateTime? _dateTime;
  bool _isCreating = false;
  bool _isStructuring = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _cityController.dispose();
    _seatsController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateTime ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime ?? DateTime.now()),
    );
    if (time == null) return;
    setState(() {
      _dateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _structureDescription() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a title first')),
      );
      return;
    }
    setState(() => _isStructuring = true);
    try {
      final result = await ApiClient.post(
        '/api/v1/ai/structure-meetup',
        body: jsonEncode(<String, dynamic>{
          'title': _titleController.text.trim(),
          'city': _cityController.text.trim(),
          'seats': _seatsController.text.trim().isEmpty
              ? null
              : int.tryParse(_seatsController.text.trim()),
        }),
      );
      if (mounted && result is Map<String, dynamic>) {
        final description =
            result['description'] ?? result['structured_description'];
        if (description != null) {
          _descriptionController.text = description.toString();
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to structure description: $e')),
      );
    } finally {
      if (mounted) setState(() => _isStructuring = false);
    }
  }

  Future<void> _createMeetup() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date and time')),
      );
      return;
    }
    setState(() => _isCreating = true);
    try {
      await ApiClient.post(
        '/api/v1/meetups',
        body: jsonEncode(<String, dynamic>{
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'city': _cityController.text.trim(),
          'date_time': DateFormat('yyyy-MM-ddTHH:mm:ss').format(_dateTime!),
          'total_seats': int.parse(_seatsController.text.trim()),
        }),
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRouter.circlesMeetups);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create meetup: $e')),
      );
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Meetup'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Create a new meetup',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Fill in the details to host your event',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 32),
              AppTextField(
                controller: _titleController,
                label: 'Title',
                hint: 'e.g. Weekend Coffee Meetup',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Title is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _descriptionController,
                label: 'Description',
                hint: 'What will happen at this meetup?',
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Description is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              AppButton(
                text: 'AI Structure Description',
                icon: Icons.auto_awesome,
                type: AppButtonType.outline,
                isLoading: _isStructuring,
                onPressed: _isCreating ? null : _structureDescription,
                width: double.infinity,
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _cityController,
                label: 'City / Zone',
                hint: 'e.g. Downtown, Brooklyn',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'City/zone is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _seatsController,
                label: 'Total Seats',
                hint: 'e.g. 10',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Total seats is required';
                  }
                  final seats = int.tryParse(value.trim());
                  if (seats == null || seats < 1) {
                    return 'Enter a valid number of seats';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Date & Time',
                hint: _dateTime == null
                    ? 'Select date and time'
                    : DateFormat('EEE, MMM d, yyyy \u2022 h:mm a')
                        .format(_dateTime!),
                keyboardType: TextInputType.datetime,
                enabled: false,
                prefixIcon: const Icon(
                  Icons.calendar_today,
                  size: 20,
                ),
              ),
              const SizedBox(height: 32),
              AppButton(
                text: 'Create Meetup',
                icon: Icons.event,
                type: AppButtonType.primary,
                isLoading: _isCreating,
                onPressed: _isCreating ? null : _createMeetup,
                width: double.infinity,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}


