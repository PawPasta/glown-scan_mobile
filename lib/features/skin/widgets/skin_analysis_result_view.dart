import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class SkinAnalysisResultView extends StatelessWidget {
  const SkinAnalysisResultView({
    required this.result,
    this.requiresPremium = false,
    super.key,
  });

  final Object? result;
  final bool requiresPremium;

  @override
  Widget build(BuildContext context) {
    final data = _asMap(result);
    final summary = _asMap(data['summary']);
    final quality = _asMap(data['quality']);
    final notes = _readableItems(summary['notes']);
    final score = summary['overallSkinScore'];
    final confidence = summary['confidence'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ScoreCard(score: score, confidence: confidence),
        const SizedBox(height: 12),
        _QualityCard(
          accepted: quality['accepted'] as bool?,
          issues: _readableItems(quality['issues']),
        ),
        if (notes.isNotEmpty) ...[
          const SizedBox(height: 12),
          _InsightSection(
            title: 'What we noticed',
            icon: Icons.auto_awesome_outlined,
            child: _BulletList(items: notes),
          ),
        ],
        const SizedBox(height: 12),
        if (requiresPremium)
          const _PremiumUpsellCard()
        else ...[
          _ProfileSection(value: data['skinProfile']),
          _ScoreGroup(
            title: 'Skin metrics',
            icon: Icons.insights_outlined,
            value: data['metrics'],
            scoreLabel: 'Metric score',
          ),
          _ScoreGroup(
            title: 'Face regions',
            icon: Icons.grid_view_rounded,
            value: data['regions'],
            scoreLabel: 'Region score',
          ),
          _RecordGroup(
            title: 'What we observed',
            icon: Icons.notes_outlined,
            value: data['observations'],
            descriptionKey: 'note',
            showBounds: true,
          ),
          _RecordGroup(
            title: 'Highlights',
            icon: Icons.star_outline_rounded,
            value: data['highlights'],
            descriptionKey: 'label',
            showPoint: true,
          ),
          _ListSection(
            title: 'Assessment limitations',
            icon: Icons.info_outline_rounded,
            value: data['limitations'],
          ),
        ],
        const SizedBox(height: 12),
        const Text(
          'Cosmetic visual estimate only. This is not a medical diagnosis.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.mutedText, fontSize: 12),
        ),
      ],
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.score, required this.confidence});

  final Object? score;
  final Object? confidence;

  @override
  Widget build(BuildContext context) {
    final scoreNumber = score is num ? score as num : null;
    final scoreText = scoreNumber == null ? '—' : _numberText(scoreNumber);
    final confidenceText = confidence is num
        ? '${_numberText(_asPercent(confidence as num))}% confidence'
        : null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.sand,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.softBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 74,
            height: 74,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.paper,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.rose, width: 2),
            ),
            child: Text(
              scoreText,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppTheme.deepRose,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Overall skin score',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 3),
                const Text('A visual estimate out of 100'),
                if (confidenceText != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.paper,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      confidenceText,
                      style: const TextStyle(
                        color: AppTheme.deepRose,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QualityCard extends StatelessWidget {
  const _QualityCard({required this.accepted, required this.issues});

  final bool? accepted;
  final List<String> issues;

  @override
  Widget build(BuildContext context) {
    final color = switch (accepted) {
      true => const Color(0xFF32734D),
      false => const Color(0xFF9A5C18),
      null => AppTheme.mutedText,
    };
    final background = switch (accepted) {
      true => const Color(0xFFEAF5EE),
      false => const Color(0xFFFFF2E2),
      null => AppTheme.sand,
    };
    final title = switch (accepted) {
      true => 'Photo quality looks good',
      false => 'Some parts may be hard to assess',
      null => 'Photo quality check',
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                accepted == true
                    ? Icons.check_circle_outline
                    : Icons.lightbulb_outline,
                color: color,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(color: color, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (issues.isEmpty && accepted == true) ...[
            const SizedBox(height: 6),
            const Text('No image quality issues were reported.'),
          ] else if (issues.isNotEmpty) ...[
            const SizedBox(height: 10),
            _BulletList(items: issues.map(_humanize).toList()),
          ],
        ],
      ),
    );
  }
}

class _InsightSection extends StatelessWidget {
  const _InsightSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.paper,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.softBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppTheme.deepRose, size: 20),
            const SizedBox(width: 8),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.value});

  final Object? value;

  @override
  Widget build(BuildContext context) {
    final profile = _asMap(value);
    if (profile.isEmpty) return const SizedBox.shrink();
    final notes = _readableValue(profile['notes']);
    final skinType = _readableValue(profile['skinType']);
    final sensitivity = _readableValue(profile['sensitivityLevel']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _InsightSection(
        title: 'Skin profile',
        icon: Icons.face_3_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (skinType.isNotEmpty || sensitivity.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (skinType.isNotEmpty)
                    _InfoChip(label: 'Skin type', value: skinType),
                  if (sensitivity.isNotEmpty)
                    _InfoChip(label: 'Sensitivity', value: sensitivity),
                ],
              ),
            if (notes.isNotEmpty) ...[
              if (skinType.isNotEmpty || sensitivity.isNotEmpty)
                const SizedBox(height: 12),
              Text(notes),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScoreGroup extends StatelessWidget {
  const _ScoreGroup({
    required this.title,
    required this.icon,
    required this.value,
    required this.scoreLabel,
  });

  final String title;
  final IconData icon;
  final Object? value;
  final String scoreLabel;

  @override
  Widget build(BuildContext context) {
    final scores = _asMap(value);
    if (scores.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _InsightSection(
        title: title,
        icon: icon,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final entry in scores.entries)
                  SizedBox(
                    width: width,
                    child: _ScoreDetailCard(
                      title: _humanize(entry.key),
                      data: _asMap(entry.value),
                      scoreLabel: scoreLabel,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ScoreDetailCard extends StatelessWidget {
  const _ScoreDetailCard({
    required this.title,
    required this.data,
    required this.scoreLabel,
  });

  final String title;
  final Map<String, Object?> data;
  final String scoreLabel;

  @override
  Widget build(BuildContext context) {
    final score = data['score'];
    final confidence = data['confidence'];
    final visibility = _readableValue(data['visibility']);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.sand,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.softBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          if (score is num) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _numberText(score),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.deepRose,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    scoreLabel,
                    style: const TextStyle(
                      color: AppTheme.mutedText,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (score / 100).clamp(0, 1).toDouble(),
                minHeight: 5,
                backgroundColor: AppTheme.softBorder,
                color: AppTheme.rose,
              ),
            ),
          ],
          if (confidence is num || visibility.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              [
                if (confidence is num)
                  '${_numberText(_asPercent(confidence))}% confidence',
                if (visibility.isNotEmpty) visibility,
              ].join('  ·  '),
              style: const TextStyle(color: AppTheme.mutedText, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: AppTheme.sand,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text('$label: $value', style: Theme.of(context).textTheme.bodySmall),
  );
}

class _RecordGroup extends StatelessWidget {
  const _RecordGroup({
    required this.title,
    required this.icon,
    required this.value,
    required this.descriptionKey,
    this.showBounds = false,
    this.showPoint = false,
  });

  final String title;
  final IconData icon;
  final Object? value;
  final String descriptionKey;
  final bool showBounds;
  final bool showPoint;

  @override
  Widget build(BuildContext context) {
    if (value is! List || (value as List).isEmpty) {
      return const SizedBox.shrink();
    }
    final records = (value as List).whereType<Map>().toList();
    if (records.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _InsightSection(
        title: title,
        icon: icon,
        child: Column(
          children: [
            for (var index = 0; index < records.length; index++) ...[
              if (index > 0)
                const Divider(height: 18, color: AppTheme.softBorder),
              _RecordCard(
                data: _asMap(records[index]),
                descriptionKey: descriptionKey,
                showBounds: showBounds,
                showPoint: showPoint,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.data,
    required this.descriptionKey,
    required this.showBounds,
    required this.showPoint,
  });

  final Map<String, Object?> data;
  final String descriptionKey;
  final bool showBounds;
  final bool showPoint;

  @override
  Widget build(BuildContext context) {
    final description = _readableValue(data[descriptionKey]);
    final type = _readableValue(data['type']);
    final confidence = data['confidence'];
    final severity = data['severity'];
    final visibility = _readableValue(data['visibility']);
    final box = data['box2d'];
    final pointX = data['x'];
    final pointY = data['y'];
    final radius = data['radius'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (description.isNotEmpty)
          Text(description, style: Theme.of(context).textTheme.titleSmall),
        if (type.isNotEmpty) ...[
          if (description.isNotEmpty) const SizedBox(height: 3),
          Text(type, style: const TextStyle(color: AppTheme.mutedText)),
        ],
        if (severity is num || confidence is num || visibility.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              if (severity is num)
                _InfoChip(label: 'Severity', value: _numberText(severity)),
              if (confidence is num)
                _InfoChip(
                  label: 'Confidence',
                  value: '${_numberText(_asPercent(confidence))}%',
                ),
              if (visibility.isNotEmpty)
                _InfoChip(label: 'Visibility', value: visibility),
            ],
          ),
        ],
        if (showBounds && box is List && box.length >= 4) ...[
          const SizedBox(height: 8),
          Text(
            'Image area: (${box[0]}, ${box[1]}) to (${box[2]}, ${box[3]})',
            style: const TextStyle(color: AppTheme.mutedText, fontSize: 12),
          ),
        ],
        if (showPoint && pointX is num && pointY is num) ...[
          const SizedBox(height: 8),
          Text(
            'Image point: (${_numberText(pointX)}, ${_numberText(pointY)})'
            '${radius is num ? ' · radius ${_numberText(radius)}' : ''}',
            style: const TextStyle(color: AppTheme.mutedText, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

class _ListSection extends StatelessWidget {
  const _ListSection({
    required this.title,
    required this.icon,
    required this.value,
  });

  final String title;
  final IconData icon;
  final Object? value;

  @override
  Widget build(BuildContext context) {
    final items = _readableItems(value);
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _InsightSection(
        title: title,
        icon: icon,
        child: _BulletList(items: items),
      ),
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final item in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 7),
                child: Icon(Icons.circle, size: 6, color: AppTheme.rose),
              ),
              const SizedBox(width: 9),
              Expanded(child: Text(item)),
            ],
          ),
        ),
    ],
  );
}

class _PremiumUpsellCard extends StatelessWidget {
  const _PremiumUpsellCard();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [AppTheme.deepRose, AppTheme.rose],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.workspace_premium_outlined, color: AppTheme.paper),
        const SizedBox(height: 10),
        Text(
          'Unlock your complete skin report',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(color: AppTheme.paper, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          'Your summary is ready. GlowScan Premium includes:',
          style: TextStyle(color: AppTheme.paper),
        ),
        const SizedBox(height: 10),
        for (final feature in const [
          'Detailed skin metrics',
          'Face-area insights and observations',
          'Personalized highlights',
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                const Icon(
                  Icons.lock_open_rounded,
                  size: 16,
                  color: AppTheme.paper,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    feature,
                    style: const TextStyle(color: AppTheme.paper),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        const Text(
          'Manage your subscription on the GlowScan website.',
          style: TextStyle(color: AppTheme.paper, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

Map<String, Object?> _asMap(Object? value) {
  if (value is! Map) return const {};
  return {
    for (final entry in value.entries)
      if (entry.key is String) entry.key as String: entry.value,
  };
}

List<String> _readableItems(Object? value) {
  if (value is! List) return const [];
  return value.map(_readableValue).where((item) => item.isNotEmpty).toList();
}

String _readableValue(Object? value) {
  if (value == null) return '';
  if (value is String) {
    final text = value.trim();
    return RegExp(r'^[A-Z][A-Z0-9_-]*$').hasMatch(text)
        ? _humanize(text)
        : text;
  }
  if (value is num) return _numberText(value);
  if (value is bool) return value ? 'Yes' : 'No';
  if (value is List) return _readableItems(value).join(' · ');
  if (value is Map) {
    return _asMap(value).entries
        .map((entry) {
          final detail = _readableValue(entry.value);
          return detail.isEmpty ? '' : '${_humanize(entry.key)}: $detail';
        })
        .where((item) => item.isNotEmpty)
        .join(' · ');
  }
  return '';
}

String _humanize(String value) {
  final words = value
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (match) => '${match[1]} ${match[2]}',
      )
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .toLowerCase()
      .trim()
      .split(RegExp(r'\s+'));
  return words
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

double _asPercent(num value) {
  final percent = value <= 1 ? value * 100 : value;
  return percent.clamp(0, 100).toDouble();
}

String _numberText(num value) =>
    value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
