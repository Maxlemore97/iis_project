require "ostruct"

class DocumentsHybridController < ApplicationController

  ###########################################################################
  # Struct including all required fields for ranking
  ###########################################################################
  Result = Struct.new(
    :id,
    :trec_id,
    :title,
    :body,
    :score, # raw BM25 score
    :norm_score, # normalized BM25
    :vector_score, # normalized vector score
    :hybrid_score, # final hybrid score
    :bm25_rank, # rank based only on BM25
    :vector_rank, # rank based only on vector
    :hybrid_rank, # combined rank
    keyword_init: true
  )

  ###########################################################################
  # INDEX ACTION (UI)
  ###########################################################################
  def index
    @queries = QueryDocument.order(:trec_id)
    @weight = (params[:weight] || 20).to_i.clamp(0, 100)
    weight = @weight / 100.0

    query_id = params[:query_id]

    # No query selected → show random documents
    if query_id.blank?
      @searched = false
      @documents = Document.order("RANDOM()").limit(20)
      return
    end

    # Load the selected query
    query_record = QueryDocument.find(query_id)
    @query_doc = query_record

    query_text = query_record.body
    query_vec = query_record.style_vec.map(&:to_f)

    # Compute hybrid results (only top 20 for UI)
    results = compute_hybrid_results(query_text, query_vec, weight, 20)

    @documents = results
    @searched = true
  end

  ###########################################################################
  # EXPORT ALL 50 QUERIES TO A TREC FILE
  ###########################################################################
  def export_trec
    weight = (params[:weight] || 20).to_i.clamp(0, 100) / 100.0
    system_name = "hybrid_vec"

    lines = []

    QueryDocument.order(:trec_id).find_each do |query|
      query_text = query.body
      query_vec = query.style_vec.map(&:to_f)

      # Reuse the SAME scoring logic used in UI but with limit 1000
      ranked = compute_hybrid_results(query_text, query_vec, weight, 1000)

      ranked.each_with_index do |doc, rank|
        lines << [
          query.trec_id, # Query ID
          "Q0", # iteration tag
          doc.trec_id, # document ID
          rank, # rank (0-based)
          doc.hybrid_score.round(5),
          system_name
        ].join(" ")
      end
    end

    send_data(
      lines.join("\n"),
      filename: "trec_results_vektor_search.trec",
      type: "text/plain",
      disposition: :attachment
    )
  end

  ###########################################################################
  # SHARED HYBRID SCORING LOGIC
  ###########################################################################
  def compute_hybrid_results(query_text, query_vec, weight, limit)
    # 1. Perform BM25 search
    text_results = Document.search(
      query: {
        multi_match: {
          query: query_text,
          fields: ["title^2", "body"]
        }
      },
      size: limit
    )

    hits = es_hits(text_results) # array of Result structs

    # 2. Normalize BM25 scores
    max_bm25 = hits.map(&:score).max || 1.0
    hits.each { |h| h.norm_score = h.score / max_bm25 }

    # 3. Compute vector similarity for same documents
    hits.each do |hit|
      doc = Document.find_by(id: hit.id)
      next if doc.nil? || doc.style_vec.nil?

      hit.vector_score = cosine_similarity(query_vec, doc.style_vec.map(&:to_f))
    end

    # 4. Normalize vector scores
    max_vec = hits.map { |h| h.vector_score || 0 }.max || 1.0
    hits.each { |h| h.vector_score = (h.vector_score || 0) / max_vec }

    # 5. Compute hybrid score
    hits.each do |hit|
      hit.hybrid_score = (1.0 - weight) * hit.norm_score +
                         weight * hit.vector_score
    end

    # 6. Compute ranks
    bm25_sorted = hits.sort_by { |h| -h.norm_score }
    bm25_sorted.each_with_index { |h, i| h.bm25_rank = i + 1 }

    vec_sorted = hits.sort_by { |h| -h.vector_score }
    vec_sorted.each_with_index { |h, i| h.vector_rank = i + 1 }

    hybrid_sorted = hits.sort_by { |h| -h.hybrid_score }
    hybrid_sorted.each_with_index { |h, i| h.hybrid_rank = i + 1 }

    # 7. Return the top N hybrid results
    hybrid_sorted.first(limit)
  end

  ###########################################################################
  # HELPERS
  ###########################################################################

  private

  def es_hits(results)
    results.response["hits"]["hits"].map do |hit|
      Result.new(
        id: hit["_id"],
        trec_id: hit["_source"]["trec_id"],
        title: hit["_source"]["title"],
        body: hit["_source"]["body"],
        score: hit["_score"].to_f
      )
    end
  end

  def cosine_similarity(a, b)
    return 0 if a.nil? || b.nil?

    dot = a.zip(b).map { |x, y| x * y }.sum
    mag_a = Math.sqrt(a.sum { |x| x * x })
    mag_b = Math.sqrt(b.sum { |y| y * y })

    return 0 if mag_a.zero? || mag_b.zero?

    dot / (mag_a * mag_b)
  end
end
