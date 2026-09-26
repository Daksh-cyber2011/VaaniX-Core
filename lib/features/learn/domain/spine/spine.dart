/// Learn Mode 2.0 — M1 Architecture Spine (public surface)
///
/// One barrel so feature code imports the whole spine coherently:
///
///   LearnerProfile → Diagnostic → LearningState → Planner →
///   LearningSession → Evaluation → Mastery → Replan
///
/// M1 scope: typed models + contracts + deterministic planner + the
/// validation boundary. Later milestones build ON these types (M2
/// persists profiles, M3 fills diagnostics, M4 swaps in the Gemini
/// planner, M6 drives sessions) without changing the spine's shape.
library;

export 'mastery.dart';
export 'concept_graph.dart';
export 'learner_profile.dart';
export 'diagnostic.dart';
export 'learning_state.dart';
export 'learning_plan.dart';
export 'personalized_course.dart';
export 'course_blueprint.dart';
export 'evaluation.dart';
export 'learning_session.dart';
export 'planner.dart';
export 'deterministic_planner.dart';
export 'planner_prompt.dart';
export 'planner_output.dart';
export 'content_registry.dart';
export 'generated_content.dart';
export 'content_prompt.dart';
export 'generated_content_parser.dart';
export 'session_engine.dart';
export 'mastery_scheduling.dart';

