require "ostruct"

class DocumentsElasticController < ApplicationController
  def index
    @queries = QueryDocument.order(:trec_id)
    query_id = params[:query_id]

    # Weight: how important the vector similarity is
    @weight = (params[:weight] || 20).to_i.clamp(0, 100)
    weight = @weight / 100.0

    #
    # No search → show random documents
    #
    if query_id.blank?
      @searched = false
      @documents = Document.order("RANDOM()").limit(20)
      return
    end

    #
    # ------------------------------------------------------
    # Load query document (this has title, body & style_vec)
    # ------------------------------------------------------
    #
    query_record = QueryDocument.find(query_id)
    @query_doc = query_record
    @query = query_record.body

    query_text = "#{query_record.title} #{query_record.body}"
    query_vec = query_record.style_vec.map(&:to_f)

    #
    # ======================================================
    # 1) TEXT SEARCH (BM25)
    # ======================================================
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

    max_bm25 = text_hits.map(&:score).max || 1.0
    text_hits.each { |h| h.norm_score = h.score.to_f / max_bm25 }

    #
    # ======================================================
    # 2) VECTOR SIMILARITY
    #    (computed on the same 200 docs)
    # ======================================================
    #
    text_hits.each do |hit|
      doc = Document.find_by(id: hit.id)
      next if doc.nil? || doc.style_vec.nil?

      vec = doc.style_vec.map(&:to_f)
      hit.vector_score = cosine_similarity(query_vec, vec)
    end

    max_vec = text_hits.map { |h| h.vector_score || 0 }.max || 1.0
    text_hits.each { |h| h.vector_score = (h.vector_score || 0) / max_vec }

    #
    # ======================================================
    # 3) HYBRID SCORING
    # ======================================================
    #
    hybrid = text_hits.map do |hit|
      hybrid_score = (1 - weight) * hit.norm_score +
                     weight * hit.vector_score

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

    @searched = true
    @documents = hybrid.sort_by { |d| -d.hybrid_score }.first(20)
  end

  private

  #
  # Convert ES result → struct
  #
  Result = Struct.new(
    :id, :trec_id, :title, :body,
    :score, :norm_score, :vector_score,
    keyword_init: true
  )

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
  # Cosine similarity (0..1)
  #
  def cosine_similarity(a, b)
    return 0 if a.nil? || b.nil?

    dot = a.zip(b).map { |x, y| x * y }.sum
    mag_a = Math.sqrt(a.map { |x| x * x }.sum)
    mag_b = Math.sqrt(b.map { |y| y * y }.sum)

    return 0 if mag_a == 0 || mag_b == 0

    dot / (mag_a * mag_b)
  end
end
