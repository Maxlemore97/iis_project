class Document < ApplicationRecord
  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks

  index_name "documents"

  settings index: {
    number_of_shards: 1,
    analysis: {
      analyzer: {
        custom_english: {
          type: "standard",
          stopwords: "_english_"
        }
      }
    }
  } do
    mappings dynamic: false do
      indexes :trec_id, type: :keyword
      indexes :title, type: :text, analyzer: "custom_english"
      indexes :body, type: :text, analyzer: "custom_english"
    end
  end
end

# Create and import index if needed
Document.__elasticsearch__.create_index!
