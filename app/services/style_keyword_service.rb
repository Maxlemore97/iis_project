class StyleKeywordService
  # Basic adjective and emotion lexicons (very simple)
  ADJECTIVES = %w[
    beautiful large small incredible significant various major minor entire quick slow
    important strong weak remarkable notable huge tiny practical theoretical
  ].freeze

  EMOTIVE_WORDS = %w[
    love hate anger joy happy sad excited terrified amazing horrible wonderful
  ].freeze

  PASSIVE_PATTERN = /\b(is|was|were|be|been|being)\s+\w+ed\b/i

  def self.generate(words:, sentences:, style_vec:)
    ttr, avg_len, pron_ratio, readability = style_vec

    keywords = []

    total_words = words.size
    words_down = words.map(&:downcase)

    # ===========================================================
    # 1) VOCABULARY RICHNESS (TTR)
    # ===========================================================
    case ttr
    when 0.7..1.0
      keywords += ["very-varied-vocabulary", "lexically-rich"]
    when 0.6...0.7
      keywords << "varied-vocabulary"
    when 0.3...0.4
      keywords << "slightly-repetitive"
    when 0.0...0.3
      keywords << "highly-repetitive"
    end

    # ===========================================================
    # 2) SENTENCE LENGTH (complexity proxy)
    # ===========================================================
    if avg_len > 25
      keywords += ["very-long-sentences", "high-complexity"]
    elsif avg_len > 20
      keywords += ["long-sentences", "complex-structure"]
    elsif avg_len < 8
      keywords += ["very-short-sentences", "very-concise"]
    elsif avg_len < 12
      keywords += ["short-sentences", "concise"]
    end

    # ===========================================================
    # 3) PRONOUN USAGE (subjective vs objective)
    # ===========================================================
    if pron_ratio > 0.12
      keywords += ["strongly-personal", "subjective", "narrative"]
    elsif pron_ratio > 0.08
      keywords += ["personal", "conversational"]
    elsif pron_ratio < 0.02
      keywords += ["highly-impersonal", "objective", "formal"]
    elsif pron_ratio < 0.04
      keywords += ["impersonal", "analytical"]
    end

    # ===========================================================
    # 4) READABILITY (Flesch reading ease)
    # ===========================================================
    if readability > 70
      keywords += ["very-easy-to-read", "light", "simple-style"]
    elsif readability > 60
      keywords += ["easy-to-read", "accessible"]
    elsif readability < 30
      keywords += ["very-academic", "dense", "technical"]
    elsif readability < 45
      keywords += ["academic", "formal"]
    end

    # ===========================================================
    # 5) LEXICAL DENSITY (percentage of unique words)
    # ===========================================================
    lexical_density = words.uniq.size.to_f / words.size
    if lexical_density > 0.5
      keywords << "high-lexical-density"
    elsif lexical_density < 0.3
      keywords << "low-lexical-density"
    end

    # ===========================================================
    # 6) ADJECTIVE FREQUENCY (descriptive vs dry)
    # ===========================================================
    adj_count = words_down.count { |w| ADJECTIVES.include?(w) }
    adj_ratio = adj_count.to_f / [total_words, 1].max

    if adj_ratio > 0.07
      keywords << "highly-descriptive"
    elsif adj_ratio > 0.04
      keywords << "descriptive"
    elsif adj_ratio < 0.015
      keywords << "dry-style"
    end

    # ===========================================================
    # 7) EMOTIONAL TONE
    # ===========================================================
    emotive_count = words_down.count { |w| EMOTIVE_WORDS.include?(w) }
    if emotive_count > 5
      keywords << "emotional"
    elsif emotive_count == 0
      keywords << "emotionally-neutral"
    end

    # ===========================================================
    # 8) PASSIVE VOICE INDICATORS
    # ===========================================================
    passive_sentences = sentences.count { |s| s =~ PASSIVE_PATTERN }

    if passive_sentences > sentences.size * 0.4
      keywords << "passive-style"
    elsif passive_sentences < sentences.size * 0.1
      keywords << "active-style"
    end

    # ===========================================================
    # Final keyword cleanup
    # ===========================================================
    keywords.map!(&:downcase)
    keywords.uniq
  end
end
