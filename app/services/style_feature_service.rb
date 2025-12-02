class StyleFeatureService
  PRONOUNS = %w[
    i you he she it we they my your his her its our their me him them
  ].freeze

  # --------------------------------------------------------
  # PUBLIC API (called from rake task)
  # --------------------------------------------------------
  def self.extract(text)
    tokens = tokenize(text)
    total = tokens.size
    unique = tokens.uniq.size
    ttr = total > 0 ? unique.to_f / total : 0.0

    # Sentence splitting (very simple)
    sentences = text.split(/(?<=[.!?])\s+/)
    avg_sentence_len =
      if sentences.any?
        sentences.map { |s| tokenize(s).size }.sum.to_f / sentences.size
      else
        0
      end

    # Pronoun ratio
    pronoun_ratio =
      if total > 0
        tokens.count { |t| PRONOUNS.include?(t.downcase) }.to_f / total
      else
        0
      end

    # Readability: Flesch Reading Ease (pure Ruby)
    readability = flesch_reading_ease(text)

    [ttr, avg_sentence_len, pronoun_ratio, readability]
  end


  # --------------------------------------------------------
  # HELPERS
  # --------------------------------------------------------

  def self.tokenize(text)
    text.scan(/[A-Za-z]+/)
  end

  # Count syllables (rough heuristic)
  def self.count_syllables(word)
    word = word.downcase
    word.gsub!(/e$/, "") if word.length > 2
    parts = word.scan(/[aeiouy]+/)
    [parts.length, 1].max
  end

  def self.flesch_reading_ease(text)
    sentences = text.split(/(?<=[.!?])\s+/)
    sentence_count = [sentences.length, 1].max

    words = tokenize(text)
    word_count = [words.length, 1].max

    syllables = words.sum { |w| count_syllables(w) }

    # Flesch Reading Ease formula:
    # 206.835 – (1.015 × ASL) – (84.6 × ASW)
    asl = word_count.to_f / sentence_count                    # Avg sentence length
    asw = syllables.to_f / word_count                         # Avg syllables per word

    206.835 - (1.015 * asl) - (84.6 * asw)
  end
end
