require "ostruct"

class DocumentsHybridController < ApplicationController
  def index
    @queries = QueryDocument.order(:trec_id)

    @weight = (params[:weight] || 20).to_i.clamp(0, 100)
    weight = @weight / 100.0

    query_id = params[:query_id]

    if query_id.blank?
      @searched = false
      @documents = Document.order("RANDOM()").limit(20)
      return
    end

    # -------------------------------------------
    # Load selected query
    # -------------------------------------------
    query_record = QueryDocument.find(query_id)
    @query_doc = query_record
    query_text = query_record.body
    query_vec = query_record.style_vec.map(&:to_f)

    #
    # ===========================================
    # 1) BM25 SEARCH (title + body)
    # ===========================================
    #
    text_results = Document.search(
      query: {
        multi_match: {
          query: query_text,
          fields: ["title^2", "body"]
        }
      },
      size: 200
    )

    text_hits = es_hits(text_results) # array of Result structs

    # Normalize BM25 scores → 0..1
    max_bm25 = text_hits.map(&:score).max || 1.0
    text_hits.each { |h| h.norm_score = h.score / max_bm25 }

    #
    # ===========================================
    # 2) VECTOR RE-RANKING (using only BM25 hits)
    # ===========================================
    #
    text_hits.each do |hit|
      doc = Document.find(hit.id) rescue nil
      next unless doc&.style_vec

      vec = doc.style_vec.map(&:to_f)
      hit.vector_score = cosine_similarity(query_vec, vec)
    end

    # Normalize vector scores → 0..1
    max_vec = text_hits.map { |h| h.vector_score || 0 }.max || 1.0
    text_hits.each do |h|
      h.vector_score = (h.vector_score || 0) / max_vec
    end

    #
    # ===========================================
    # 3) Compute hybrid score
    # ===========================================
    #
    results = text_hits.map do |hit|
      hybrid_score = (1 - weight) * hit.norm_score + weight * hit.vector_score

      OpenStruct.new(
        id: hit.id,
        trec_id: hit.trec_id,
        title: hit.title,
        body: hit.body,
        bm25_score: hit.norm_score,
        vector_score: hit.vector_score,
        hybrid_score: hybrid_score
      )
    end

    #
    # ===========================================
    # 4) RANKING POSITIONS (NEW)
    # ===========================================
    #

    # 🔵 BM25-only rank
    bm25_sorted = results.sort_by { |r| -r.bm25_score }
    bm25_sorted.each_with_index do |r, i|
      r.bm25_rank = i + 1
    end

    # 🔵 Vector-only rank
    vec_sorted = results.sort_by { |r| -r.vector_score }
    vec_sorted.each_with_index do |r, i|
      r.vector_rank = i + 1
    end

    # 🔵 Hybrid rank (what we will return)
    hybrid_sorted = results.sort_by { |r| -r.hybrid_score }
    hybrid_sorted.each_with_index do |r, i|
      r.hybrid_rank = i + 1
    end

    @searched = true
    @documents = hybrid_sorted.first(20)
  end

  private

  Result = Struct.new(:id, :trec_id, :title, :body, :score, :norm_score, :vector_score, keyword_init: true)

  def es_hits(results)
    results.response["hits"]["hits"].map do |hit|
      Result.new(
        id: hit["_id"].to_s,
        trec_id: hit["_source"]["trec_id"],
        title: hit["_source"]["title"],
        body: hit["_source"]["body"],
        score: hit["_score"].to_f
      )
    end
  end

  #
  # Cosine similarity between two vectors
  #
  def cosine_similarity(a, b)
    return 0 if a.nil? || b.nil?

    dot = a.zip(b).map { |x, y| x * y }.sum
    mag_a = Math.sqrt(a.sum { |x| x * x })
    mag_b = Math.sqrt(b.sum { |y| y * y })

    return 0 if mag_a == 0 || mag_b == 0

    dot / (mag_a * mag_b)
  end
end
