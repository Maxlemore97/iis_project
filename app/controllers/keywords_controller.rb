class KeywordsController < ApplicationController
  def index
    @documents = Document.order("RANDOM()").limit(2).map do |doc|
      words = StyleFeatureService.tokenize(doc.body)
      sentences = doc.body.split(/(?<=[.!?])\s+/)
      style_vec = doc.style_vec || [0, 0, 0, 0]

      # Style keywords using the new detailed service
      style_keywords = StyleKeywordService.generate(
        words: words,
        sentences: sentences,
        style_vec: style_vec
      )

      # Additional details for the explanation view
      freq = Hash.new(0)
      words.each { |w| freq[w.downcase] += 1 }

      {
        record: doc,
        preview: doc.body[0..500],

        words_count: words.size,
        unique_count: words.uniq.size,
        sentence_count: sentences.size,
        lexical_density: (words.uniq.size.to_f / words.size).round(3),

        adjectives: StyleKeywordService::ADJECTIVES,
        emotive_words: StyleKeywordService::EMOTIVE_WORDS,

        adjective_count: words.count { |w| StyleKeywordService::ADJECTIVES.include?(w.downcase) },
        emotive_count: words.count { |w| StyleKeywordService::EMOTIVE_WORDS.include?(w.downcase) },

        passive_sentences: sentences.select { |s| s =~ StyleKeywordService::PASSIVE_PATTERN },

        top_unique: freq.sort_by { |w, c| -c }.first(30).map { |word, count| { word:, count: } },

        style_keywords: style_keywords
      }
    end
  end
end
