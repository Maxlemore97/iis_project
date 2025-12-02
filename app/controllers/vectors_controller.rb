class VectorsController < ApplicationController
  def index
    @documents = Document.order("RANDOM()").limit(2).map do |doc|
      words = StyleFeatureService.tokenize(doc.body) # full word list
      sentences = doc.body.split(/(?<=[.!?])\s+/)    # full sentence list
      syllables = words.sum { |w| StyleFeatureService.count_syllables(w) }

      # Compute frequency of each unique word (case-insensitive)
      freq = Hash.new(0)
      words.each { |w| freq[w.downcase] += 1 }

      # Top 50 unique words by frequency
      top_unique_words =
        freq.sort_by { |_, count| -count }
            .first(50)
            .map { |word, count| { word: word, count: count } }

      # Precompute sentence previews (show 10 max)
      sentence_data = sentences.take(10).map do |s|
        { text: s, wc: StyleFeatureService.tokenize(s).size }
      end

      # Preview text for pronoun highlighting (fast)
      preview = doc.body[0..500]
      pronouns = StyleFeatureService::PRONOUNS
      pronoun_count = words.count { |w| pronouns.include?(w.downcase) }
      highlighted_preview = preview.gsub(/[A-Za-z]+/) do |token|
        if pronouns.include?(token.downcase)
          "<mark><strong>#{token}</strong></mark>"
        else
          token
        end
      end

      {
        record: doc,

        # Full computation data
        words_count: words.size,
        unique_count: freq.size,
        sentences_count: sentences.size,
        syllables: syllables,

        # Limited display examples
        top_unique: top_unique_words,
        sentences: sentence_data,
        preview: preview,
        highlighted_preview: highlighted_preview,
        pronoun_count: pronoun_count,

        # Full style vector
        vec: doc.style_vec || []
      }
    end
  end
end
