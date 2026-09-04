/// VaaniX AI — Domain Layer Barrel
///
/// Single import surface for all AI domain contracts and models. The data and
/// presentation layers import from here; nothing in `domain` imports them.
///
/// ```dart
/// import 'package:vaanix_app/features/ai/domain/ai_domain.dart';
/// ```
library;

export 'ai_config.dart';
export 'ai_message.dart';
export 'ai_service.dart';
export 'conversation_context.dart';
export 'conversation_memory.dart';
export 'conversation_pipeline.dart';
export 'model_adapter.dart';
export 'prompt_pipeline.dart';
