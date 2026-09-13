/// Course-aware study session for a selected Exam Mode syllabus unit.
///
/// The screen intentionally stores only trusted curriculum metadata and a
/// study method; it does not republish NCERT textbook passages. Students use
/// their prescribed text alongside this in-scope guide, then move into a
/// focused practice session for the same stable syllabus id.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:vaanix_app/core/constants/route_names.dart';
import 'package:vaanix_app/core/theme/app_colors.dart';
import 'package:vaanix_app/core/theme/app_text_styles.dart';
import 'package:vaanix_app/features/exam/data/syllabus/syllabus.dart';
import 'package:vaanix_app/features/exam/domain/exam_scope.dart';
import 'package:vaanix_app/features/exam/presentation/providers/exam_gamification_providers.dart';
import 'package:vaanix_app/features/exam/presentation/providers/exam_scope_providers.dart';
import 'package:vaanix_app/shared/widgets/loading_indicator.dart';
import 'package:vaanix_app/shared/widgets/primary_button.dart';
import 'package:vaanix_app/shared/widgets/vaanix_scaffold.dart';

class ExamStudyScreen extends ConsumerWidget {
  const ExamStudyScreen({
    super.key,
    required this.trackId,
    required this.topicId,
  });

  final String trackId;
  final String topicId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scopeAsync = ref.watch(examScopeProvider(trackId));
    final syllabusAsync = ref.watch(courseSyllabusProvider(trackId));

    return VaaniXScaffold(
      title: 'Study',
      body: scopeAsync.when(
        loading: () => const Center(
          child: VaaniXLoadingIndicator(message: 'Loading your study plan…'),
        ),
        error: (_, __) => const _StudyUnavailable(),
        data: (scope) => syllabusAsync.when(
          loading: () => const Center(
            child: VaaniXLoadingIndicator(message: 'Loading syllabus…'),
          ),
          error: (_, __) => const _StudyUnavailable(),
          data: (syllabus) {
            final unit = scope.view?.unitById(topicId);
            if (syllabus == null ||
                unit == null ||
                !scope.selection.isSelected(topicId)) {
              return const _StudyUnavailable();
            }
            final section = syllabus.sections
                .where((s) => s.id == unit.sectionId)
                .firstOrNull;
            return _StudyBody(
              trackId: trackId,
              topicId: topicId,
              syllabus: syllabus,
              unit: unit,
              section: section,
            );
          },
        ),
      ),
    );
  }
}

class _StudyBody extends ConsumerWidget {
  const _StudyBody({
    required this.trackId,
    required this.topicId,
    required this.syllabus,
    required this.unit,
    required this.section,
  });

  final String trackId;
  final String topicId;
  final CourseSyllabus syllabus;
  final ScopeUnit unit;
  final SyllabusSection? section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLiterature = unit.isChapter;
    final method = _studyMethod(
      isLiterature: isLiterature,
      sectionKey: section?.stableKey,
      title: unit.title,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Text(syllabus.courseName,
            style: AppTextStyles.labelMedium(color: AppColors.primary)),
        const SizedBox(height: 6),
        Text(unit.title, style: AppTextStyles.headlineSmall()),
        if (unit.subtitle != null) ...[
          const SizedBox(height: 6),
          Text(unit.subtitle!,
              style: AppTextStyles.bodyMedium(
                  color:
                      isDark ? AppColors.subtextDark : AppColors.subtextLight)),
        ],
        const SizedBox(height: 20),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('आज का अध्ययन', style: AppTextStyles.titleSmall()),
              const SizedBox(height: 10),
              for (var i = 0; i < method.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor:
                            AppColors.primary.withValues(alpha: .12),
                        child: Text('${i + 1}',
                            style: AppTextStyles.labelSmall(
                                color: AppColors.primary)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(method[i],
                              style: AppTextStyles.bodyMedium())),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Card(
          child: Text(
            isLiterature
                ? 'पाठ का मूल पाठ अपनी NCERT पुस्तक से पढ़ें। VaaniX केवल आधिकारिक पाठ्यक्रम सीमा, अध्ययन-सहायता और अभ्यास देता है; पुस्तक का पाठ यहाँ दोबारा प्रकाशित नहीं किया जाता।'
                : 'यह गतिविधि आपके चुने हुए आधिकारिक exam scope के भीतर है। अभ्यास भी इसी unit तक सीमित रहेगा।',
            style: AppTextStyles.bodySmall(
                color: isDark ? AppColors.subtextDark : AppColors.subtextLight),
          ),
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: 'इस unit का अभ्यास करें',
          icon: const Icon(Icons.edit_note),
          onPressed: () async {
            await _markLearnComplete(ref);
            if (context.mounted) {
              GoRouter.of(context).pushNamed(
                RouteNames.examPracticeName,
                pathParameters: {'trackId': trackId},
                queryParameters: {'topic': topicId},
              );
            }
          },
        ),
      ],
    );
  }

  Future<void> _markLearnComplete(WidgetRef ref) async {
    final now = DateTime.now();
    final dayKey = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    await ref
        .read(examHubRepositoryProvider)
        .recordCompletion(trackId, dayKey, 'learn');
    ref.invalidate(examDayCompletionsProvider('$trackId|$dayKey'));
  }

  List<String> _studyMethod({
    required bool isLiterature,
    required String? sectionKey,
    required String title,
  }) {
    if (isLiterature) {
      return [
        'अपनी निर्धारित NCERT पुस्तक में “$title” पढ़ें और अपरिचित शब्दों को चिह्नित करें।',
        'पाठ का केंद्रीय विचार अपने शब्दों में 3–4 वाक्यों में लिखें; उत्तर पुस्तक से ज्यों-का-त्यों न उतारें।',
        'पाठ से ऐसे प्रमाण चुनें जो आपके विचार का समर्थन करते हों, फिर focused practice से अपनी तैयारी जाँचें।',
      ];
    }
    return switch (sectionKey) {
      'grammar' => [
          '“$title” की आधिकारिक परिभाषा और दिए गए उप-प्रकार दोहराएँ।',
          'कम-से-कम पाँच अपने उदाहरण बनाकर प्रत्येक में नियम पहचानें।',
          'गलत हुए उदाहरणों को अलग नोट करें और focused practice शुरू करें।',
        ],
      'writing' => [
          'प्रश्न में दिए format, शब्द-सीमा और विकल्प को पहले पहचानें।',
          'लिखने से पहले 3–4 बिंदुओं की रूपरेखा बनाएँ; फिर साफ़ शुरुआत, मुख्य भाग और समापन लिखें।',
          'जाँचें कि उत्तर “$title” की आधिकारिक माँग और शब्द-सीमा के अनुरूप है।',
        ],
      'unread' => [
          'पहले प्रश्न पढ़ें, फिर गद्यांश/काव्यांश को ध्यान से पढ़कर प्रमाण चिह्नित करें।',
          'उत्तर केवल दिए गए पाठ के आधार पर दें; बाहर की जानकारी न जोड़ें।',
          'समय बाँटकर short-answer और MCQ दोनों की जाँच करें।',
        ],
      _ => [
          '“$title” के आधिकारिक scope को पढ़ें और मुख्य बिंदु लिखें।',
          'एक छोटा स्वयं-परीक्षण करें, फिर focused practice शुरू करें।',
        ],
    };
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.surfaceDark
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.borderDark
                  : AppColors.borderLight),
        ),
        child: child,
      );
}

class _StudyUnavailable extends StatelessWidget {
  const _StudyUnavailable();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            'यह unit अभी आपके चुने हुए scope में उपलब्ध नहीं है। पहले scope चुनें या इसे फिर से शामिल करें।',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium(),
          ),
        ),
      );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
