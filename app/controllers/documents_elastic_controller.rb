class DocumentsElasticController < ApplicationController
  def index
    # Show the newest 20 documents
    @documents = Document.order(created_at: :desc).limit(20)
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
