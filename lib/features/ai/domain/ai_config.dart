/// VaaniX AI — Configuration
///
/// Describes how an AI request should be fulfilled. The configuration is
/// deliberately model-agnostic: a [ModelAdapter] reads the fields it
/// understands (temperature, max tokens, etc.) and ignores the rest. This
/// lets the same config drive Gemini, GLM, OpenAI, Claude, Groq, Kimi, etc.
/// without per-provider conditionals.
///
/// Configuration is created by the application layer (based on user
/// preferences + active model) and passed into the [AIService]. It is NOT a
/// place for secrets — API keys live in environment / secure storage and are
/// injected into adapters, not into request configs.
library;

import 'package:equatable/equatable.dart';

/// Identifies a pluggable AI provider backend.
///
/// Add new entries here when a new [ModelAdapter] is wired in. The string id
/// is what is persisted in user preferences and resolved by the DI container.
enum AiProviderId {
  /// Offline echo adapter — used until a real backend is configured and as
  /// the always-available fallback.
  offline,

  /// Google Gemini.
  gemini,

  /// Zhipu GLM.
  glm,

  /// OpenAI (GPT family).
  openai,

  /// Anthropic Claude.
  claude,

  /// Groq-hosted models.
  groq,

  /// Moonshot Kimi.
  kimi;

  /// Stable string identifier persisted in preferences.
  String get id => name;

  static AiProviderId fromString(String? raw) {
    if (raw == null) return AiProviderId.offline;
    for (final v in AiProviderId.values) {
      if (v.id == raw) return v;
    }
    return AiProviderId.offline;
  }
}

/// Immutable AI request configuration.
class AiConfig extends Equatable {
  const AiConfig({
    this.provider = AiProviderId.offline,
    this.model = '',
    this.temperature = 0.7,
    this.maxTokens = 1024,
    this.topP = 1.0,
    this.enableStreaming = true,
    this.systemPrompt = '',
    this.extra = const {},
  });

  /// Which provider backend should fulfill the request.
  final AiProviderId provider;

  /// Provider-specific model name (e.g. 'gemini-2.5-flash', 'gpt-4o-mini').
  /// Empty string means "use the adapter's default".
  final String model;

  /// Sampling temperature (0.0 deterministic → 1.0+ creative).
  final double temperature;

  /// Maximum tokens to generate in the response.
  final int maxTokens;

  /// Nucleus sampling probability mass.
  final double topP;

  /// Whether the adapter should stream the response token-by-token.
  final bool enableStreaming;

  /// Optional system prompt that defines Van's persona for this request.
  /// When empty, the active persona prompt from [ConversationContext] is used.
  final String systemPrompt;

  /// Provider-specific overrides the application may inject (e.g. safety
  /// settings, response format). Adapters read keys they understand.
  final Map<String, dynamic> extra;

  /// A safe default config pointing at the offline adapter.
  static const AiConfig offline = AiConfig(provider: AiProviderId.offline);

  AiConfig copyWith({
    AiProviderId? provider,
    String? model,
    double? temperature,
    int? maxTokens,
    double? topP,
    bool? enableStreaming,
    String? systemPrompt,
    Map<String, dynamic>? extra,
  }) =>
      AiConfig(
        provider: provider ?? this.provider,
        model: model ?? this.model,
        temperature: temperature ?? this.temperature,
        maxTokens: maxTokens ?? this.maxTokens,
        topP: topP ?? this.topP,
        enableStreaming: enableStreaming ?? this.enableStreaming,
        systemPrompt: systemPrompt ?? this.systemPrompt,
        extra: extra ?? this.extra,
      );

  @override
  List<Object?> get props => [
        provider,
        model,
        temperature,
        maxTokens,
        topP,
        enableStreaming,
        systemPrompt,
        extra
      ];
}
