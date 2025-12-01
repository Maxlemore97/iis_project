class DocumentsController < ApplicationController
  def index
    # Show the newest 20 documents
    @documents = Document.order(created_at: :desc).limit(20)
  end

  # ----------------------------------------
  # TEXT SEARCH (kept as-is)
  # ----------------------------------------
  def search
    query = params[:q]

    results = Document.search(
      query: {
        multi_match: {
          query: query,
          fields: ["title^2", "body"]
        }
      }
    )

    render json: es_hits(results)
  end

  # ----------------------------------------
  # 🔥 NEW: VECTOR SIMILARITY SEARCH
  # ----------------------------------------
  def search_style
    # Expecting params like:
    # ?vec=0.72,18.4,0.05,46.2
    vec_param = params[:vec]

    return render json: { error: "Missing vec param" }, status: 400 if vec_param.blank?

    style_vec = vec_param.split(",").map(&:to_f)

    results = Document.__elasticsearch__.search(
      query: {
        knn: {
          field: "style_vec",
          query_vector: style_vec,
          k: 20,
          num_candidates: 10000
        }
      }
    )

    render json: es_hits(results)
  end

  def search_hybrid
    text_query = params[:q]
    vec_param  = params[:vec]

    return render json: { error: "Missing vec param" }, status: 400 if vec_param.blank?

    style_vec = vec_param.split(",").map(&:to_f)

    # --------------------------------------------
    # 1. TEXT SEARCH (BM25)
    # --------------------------------------------
    text_results = Document.search(
      query: {
        multi_match: {
          query: text_query,
          fields: ["title^2", "body"]
        }
      },
      size: 100
    )

    text_hits = es_hits(text_results) # [{id:, score:, ...}, ...]
    text_hash = text_hits.index_by { |h| h[:id].to_s }

    # Normalize BM25 scores (0..1)
    max_text = text_hits.map { |h| h[:score] }.max || 1.0
    text_hash.each { |_, h| h[:norm_score] = h[:score].to_f / max_text }


    # --------------------------------------------
    # 2. VECTOR KNN SEARCH
    # --------------------------------------------
    vec_results = Document.__elasticsearch__.search(
      query: {
        knn: {
          field: "style_vec",
          query_vector: style_vec,
          k: 100,
          num_candidates: 10000
        }
      }
    )

    vec_hits = es_hits(vec_results)
    vec_hash = vec_hits.index_by { |h| h[:id].to_s }

    # Normalize vector scores (0..1)
    max_vec = vec_hits.map { |h| h[:score] }.max || 1.0
    vec_hash.each { |_, h| h[:norm_score] = h[:score].to_f / max_vec }


    # --------------------------------------------
    # 3. MERGE + HYBRID RANKING
    # --------------------------------------------
    merged_ids = (text_hash.keys + vec_hash.keys).uniq

    hybrid_results = merged_ids.map do |id|
      t = text_hash[id]
      v = vec_hash[id]

      text_score  = t&.dig(:norm_score) || 0.0
      style_score = v&.dig(:norm_score) || 0.0

      hybrid_score = 0.80 * text_score + 0.20 * style_score

      # merge sources
      base = t || v
      base.merge(hybrid_score: hybrid_score)
    end

    # Sort by hybrid score descending
    hybrid_results.sort_by! { |r| -r[:hybrid_score] }

    render json: hybrid_results.first(20)
  end


  # ----------------------------------------
  # Extract hits from Elasticsearch response
  # ----------------------------------------
  private

  def es_hits(results)
    results.response["hits"]["hits"].map do |hit|
      {
        id: hit["_id"],
        score: hit["_score"],
        **hit["_source"]
      }
    end
  end
end
