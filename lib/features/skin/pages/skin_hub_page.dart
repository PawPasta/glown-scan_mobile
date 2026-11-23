import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../premium/widgets/premium_required_view.dart';
import '../services/skin_care_api.dart';
import '../widgets/skin_analysis_result_view.dart';
import 'product_detail_page.dart';

class SkinHubPage extends StatefulWidget {
  const SkinHubPage({this.api, super.key});
  final SkinCareApiContract? api;

  @override
  State<SkinHubPage> createState() => _SkinHubPageState();
}

class _SkinHubPageState extends State<SkinHubPage> {
  late final SkinCareApiContract _api = widget.api ?? SkinCareApi();
  late Future<_SkinHubData> _data = _load();
  bool _isLoadingMoreHistory = false;

  Future<_SkinHubData> _load() async {
    final assessment = await _api.getAssessment();
    final history = await _api.getHistory(limit: 10);
    try {
      final recommendationResponse = await _api.getRecommendations(limit: 10);
      return _SkinHubData(
        assessment: assessment,
        history: history,
        recommendations: recommendationResponse.items,
        recommendationSource: recommendationResponse.source,
        recommendationsGeneratedAt: recommendationResponse.generatedAt,
      );
    } on ApiException catch (error) {
      if (error.code != 'PREMIUM_REQUIRED') rethrow;
      return _SkinHubData(
        assessment: assessment,
        history: history,
        recommendations: const [],
        recommendationsRequirePremium: true,
      );
    }
  }

  Future<void> _loadMoreHistory(_SkinHubData current) async {
    if (_isLoadingMoreHistory || !current.history.hasMore) return;
    setState(() => _isLoadingMoreHistory = true);
    try {
      final nextPage = current.history.page + 1;
      final next = await _api.getHistory(
        page: nextPage,
        limit: current.history.limit,
      );
      if (!mounted) return;
      setState(() {
        _data = Future.value(
          current.copyWith(
            history: SkinAnalysisHistory(
              items: [...current.history.items, ...next.items],
              total: next.total,
              page: nextPage,
              limit: next.limit,
            ),
          ),
        );
      });
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _isLoadingMoreHistory = false);
    }
  }

  @override
  void dispose() {
    if (widget.api == null && _api is SkinCareApi) {
      (_api).close();
    }
    super.dispose();
  }

  Future<void> _edit(SkinAssessment? initial) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => SkinAssessmentPage(api: _api, initial: initial),
      ),
    );
    if (saved == true && mounted) {
      setState(() {
        _data = _load();
      });
    }
  }

  String _recommendationSourceLabel(RecommendationSource source) {
    if (source.assessmentAvailable && source.analysisAvailable) {
      return 'Matched using your skin profile and latest analysis.';
    }
    if (source.assessmentAvailable) return 'Matched using your skin profile.';
    if (source.analysisAvailable) return 'Matched using your latest analysis.';
    return 'General product matches.';
  }

  Future<void> _openAnalysisDetails(SkinAnalysisSession item) async {
    try {
      final session = await _api.getAnalysisSession(item.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Analysis ${session.status.toLowerCase()}'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (session.createdAt != null)
                    Text('Created: ${session.createdAt}'),
                  if (session.completedAt != null)
                    Text('Completed: ${session.completedAt}'),
                  if (session.errorCode != null)
                    Text('Error: ${session.errorCode}'),
                  const SizedBox(height: 12),
                  SkinAnalysisResultView(
                    result: session.result,
                    requiresPremium: session.requiresPremium,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_SkinHubData>(
    future: _data,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return _LoadError(
          onRetry: () => setState(() {
            _data = _load();
          }),
        );
      }
      final data = snapshot.requireData;
      return RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _data = _load();
          });
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              'Your skin profile',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Keep your answers current for more relevant insights and product matches.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _AssessmentCard(
              assessment: data.assessment,
              onEdit: () => _edit(data.assessment),
            ),
            const SizedBox(height: 24),
            Text(
              'Recent analyses',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            if (data.history.items.isEmpty)
              const _EmptyCard(
                message:
                    'Your completed and in-progress analyses will appear here.',
              )
            else
              ...data.history.items.map(
                (item) => _AnalysisTile(
                  item,
                  onTap: () => _openAnalysisDetails(item),
                ),
              ),
            if (data.history.hasMore)
              Center(
                child: TextButton.icon(
                  onPressed: _isLoadingMoreHistory
                      ? null
                      : () => _loadMoreHistory(data),
                  icon: _isLoadingMoreHistory
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.expand_more),
                  label: Text(
                    _isLoadingMoreHistory ? 'Loading…' : 'Load more analyses',
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Text(
              'Recommended for you',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            if (data.recommendationsRequirePremium)
              const PremiumRequiredView(
                feature: 'personalised product recommendations',
                compact: true,
              )
            else if (data.recommendations.isEmpty)
              const _EmptyCard(
                message: 'Complete your skin profile or an analysis to see product matches.',
              )
            else ...[
              if (data.recommendationSource != null)
                Text(
                  _recommendationSourceLabel(data.recommendationSource!),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (data.recommendationsGeneratedAt != null)
                Text(
                  'Updated ${data.recommendationsGeneratedAt}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ...data.recommendations.map(
                (item) => _RecommendationCard(
                  item,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ProductDetailPage(productId: item.id),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    },
  );
}

class SkinAssessmentPage extends StatefulWidget {
  const SkinAssessmentPage({required this.api, this.initial, super.key});
  final SkinCareApiContract api;
  final SkinAssessment? initial;
  @override
  State<SkinAssessmentPage> createState() => _SkinAssessmentPageState();
}

class _SkinAssessmentPageState extends State<SkinAssessmentPage> {
  late String _skinType = widget.initial?.answers.skinType ?? 'NOT_SURE';
  late String _sensitivity = widget.initial?.answers.sensitivity ?? 'NOT_SURE';
  late Set<String> _concerns = {...?widget.initial?.answers.concerns};
  late Set<String> _goals = {...?widget.initial?.answers.goals};
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.api.saveAssessment(
        SkinAssessmentAnswers(
          skinType: _skinType,
          sensitivity: _sensitivity,
          concerns: _concerns.toList(),
          goals: _goals.toList(),
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Skin profile')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Tell us about your skin',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'These answers shape your recommendations. You can update them at any time.',
        ),
        const SizedBox(height: 24),
        _SingleChoice(
          title: 'Skin type',
          values: const {
            'NORMAL': 'Normal',
            'DRY': 'Dry',
            'OILY': 'Oily',
            'COMBINATION': 'Combination',
            'NOT_SURE': 'Not sure',
          },
          selected: _skinType,
          onChanged: (value) => setState(() => _skinType = value),
        ),
        _SingleChoice(
          title: 'Sensitivity',
          values: const {
            'LOW': 'Low',
            'MEDIUM': 'Medium',
            'HIGH': 'High',
            'NOT_SURE': 'Not sure',
          },
          selected: _sensitivity,
          onChanged: (value) => setState(() => _sensitivity = value),
        ),
        _MultiChoice(
          title: 'Concerns (up to 7)',
          values: const {
            'ACNE': 'Acne',
            'REDNESS': 'Redness',
            'DARK_SPOTS': 'Dark spots',
            'PORES': 'Pores',
            'DRYNESS': 'Dryness',
            'OILINESS': 'Oiliness',
            'TEXTURE': 'Texture',
            'NONE': 'None',
          },
          selected: _concerns,
          max: 7,
          noneKey: 'NONE',
          onChanged: (values) => setState(() => _concerns = values),
        ),
        _MultiChoice(
          title: 'Goals (up to 6)',
          values: const {
            'REDUCE_ACNE': 'Reduce acne',
            'EVEN_TONE': 'Even tone',
            'HYDRATION': 'Hydration',
            'OIL_CONTROL': 'Oil control',
            'ANTI_AGING': 'Anti-aging',
            'MAINTAIN_HEALTHY_SKIN': 'Maintain healthy skin',
          },
          selected: _goals,
          max: 6,
          onChanged: (values) => setState(() => _goals = values),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const CircularProgressIndicator()
              : const Text('Save skin profile'),
        ),
      ],
    ),
  );
}

class _SkinHubData {
  const _SkinHubData({
    required this.assessment,
    required this.history,
    required this.recommendations,
    this.recommendationsRequirePremium = false,
    this.recommendationSource,
    this.recommendationsGeneratedAt,
  });
  final SkinAssessment? assessment;
  final SkinAnalysisHistory history;
  final List<ProductRecommendation> recommendations;
  final bool recommendationsRequirePremium;
  final RecommendationSource? recommendationSource;
  final String? recommendationsGeneratedAt;

  _SkinHubData copyWith({SkinAnalysisHistory? history}) => _SkinHubData(
    assessment: assessment,
    history: history ?? this.history,
    recommendations: recommendations,
    recommendationsRequirePremium: recommendationsRequirePremium,
    recommendationSource: recommendationSource,
    recommendationsGeneratedAt: recommendationsGeneratedAt,
  );
}

class _AssessmentCard extends StatelessWidget {
  const _AssessmentCard({required this.assessment, required this.onEdit});
  final SkinAssessment? assessment;
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppTheme.sand,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          assessment == null ? 'Set up your profile' : 'Profile saved',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          assessment == null
              ? 'Share your skin type, sensitivity, concerns and goals.'
              : '${assessment!.answers.skinType.replaceAll('_', ' ')} · ${assessment!.answers.concerns.join(', ')}',
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: onEdit,
          child: Text(
            assessment == null ? 'Start assessment' : 'Edit assessment',
          ),
        ),
      ],
    ),
  );
}

class _AnalysisTile extends StatelessWidget {
  const _AnalysisTile(this.item, {required this.onTap});
  final SkinAnalysisSession item;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onTap,
      leading: Icon(
        item.status == 'SUCCEEDED'
            ? Icons.check_circle_outline
            : Icons.hourglass_top_outlined,
        color: AppTheme.deepRose,
      ),
      title: Text(item.status.toLowerCase().replaceAll('_', ' ')),
      subtitle: Text(item.createdAt ?? 'Analysis session'),
      trailing: item.errorCode == null ? null : const Icon(Icons.error_outline),
    ),
  );
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard(this.item, {required this.onTap});
  final ProductRecommendation item;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onTap,
      leading: item.imageUrl == null
          ? const Icon(Icons.spa_outlined)
          : Image.network(
              item.imageUrl!,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(Icons.spa_outlined),
            ),
      title: Text(item.name),
      subtitle: Text(
        [
          item.brand,
          if (item.matchedConcerns.isNotEmpty)
            'Matches ${item.matchedConcerns.join(', ')}',
          ...item.reasons,
          item.disclaimer,
        ].whereType<String>().join(' · '),
      ),
    ),
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      border: Border.all(color: AppTheme.softBorder),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(message),
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: FilledButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh),
      label: const Text('Try again'),
    ),
  );
}

class _SingleChoice extends StatelessWidget {
  const _SingleChoice({
    required this.title,
    required this.values,
    required this.selected,
    required this.onChanged,
  });
  final String title;
  final Map<String, String> values;
  final String selected;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values.entries
              .map(
                (entry) => ChoiceChip(
                  label: Text(entry.value),
                  selected: entry.key == selected,
                  onSelected: (_) => onChanged(entry.key),
                ),
              )
              .toList(),
        ),
      ],
    ),
  );
}

class _MultiChoice extends StatelessWidget {
  const _MultiChoice({
    required this.title,
    required this.values,
    required this.selected,
    required this.max,
    required this.onChanged,
    this.noneKey,
  });
  final String title;
  final Map<String, String> values;
  final Set<String> selected;
  final int max;
  final ValueChanged<Set<String>> onChanged;
  final String? noneKey;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values.entries.map((entry) {
            final isSelected = selected.contains(entry.key);
            return FilterChip(
              label: Text(entry.value),
              selected: isSelected,
              onSelected: (value) {
                final next = {...selected};
                if (value) {
                  if (entry.key == noneKey) {
                    next
                      ..clear()
                      ..add(entry.key);
                  } else {
                    next.remove(noneKey);
                    if (next.length >= max) return;
                    next.add(entry.key);
                  }
                } else {
                  next.remove(entry.key);
                }
                onChanged(next);
              },
            );
          }).toList(),
        ),
      ],
    ),
  );
}
