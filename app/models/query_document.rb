class QueryDocument < ApplicationRecord
  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks

  index_name "query_documents"

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
      indexes :style_keywords, type: :keyword

      indexes :style_vec,
              type: :dense_vector,
              dims: 4,
              index: true,
              similarity: :cosine
    end
  end
end

# Create index if necessary
QueryDocument.__elasticsearch__.create_index!
