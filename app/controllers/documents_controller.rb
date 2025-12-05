require "ostruct"

class DocumentsController < ApplicationController

  # Struct for BM25-only results
  BM25Result = Struct.new(
    :id, :trec_id, :title, :body,
    :raw_score, # original BM25
    :score, # normalized BM25 (0..1)
    :rank,
    keyword_init: true
  )

  #############################################################
  # UI ACTION
  #############################################################
  def index
    @queries = QueryDocument.order(:trec_id)
    query_id = params[:query_id]

    if query_id.blank?
      @searched = false
      @documents = Document.order("RANDOM()").limit(20)
      return
    end

    query_record = QueryDocument.find(query_id)
    @query_doc = query_record
    @query = query_record.body

    @documents = compute_bm25_results(@query, 20)
    @searched = true
  end

  #############################################################
  # EXPORT TOP 1000 BM25 RESULTS FOR ALL QUERIES IN TREC FORMAT
  #############################################################
  def export_trec
    system_name = "bm25_only"
    limit = 1000
    lines = []

    QueryDocument.order(:trec_id).find_each do |query|
      ranked = compute_bm25_results(query.body, limit)

      ranked.each_with_index do |doc, rank|
        lines << [
          query.trec_id, # Query ID
          "Q0",
          doc.trec_id, # Document ID
          rank, # Rank (0-based)
          doc.score.round(5), # NORMALIZED BM25 SCORE
          system_name
        ].join(" ")
      end
    end

    send_data(
      lines.join("\n"),
      filename: "trec_results_bm25.trec",
      type: "text/plain",
      disposition: :attachment
    )
  end

  #############################################################
  # SHARED BM25 RANKING + NORMALIZATION LOGIC
  #############################################################
  def compute_bm25_results(query_text, limit)
    # Elasticsearch BM25 search
    results = Document.search(
      query: {
        multi_match: {
          query: query_text,
          fields: ["title^2", "body"]
        }
      },
      size: limit
    )

    hits = es_hits(results)

    # ----------------------------------------------------------------------
    # NORMALIZE BM25 SCORES (0..1)
    # ----------------------------------------------------------------------
    raw_scores = hits.map(&:raw_score)

    max_score = raw_scores.max || 1.0
    min_score = raw_scores.min || 0.0
    range = max_score - min_score
    range = 1.0 if range.zero? # avoid division by zero

    hits.each do |hit|
      hit.score = (hit.raw_score - min_score) / range
    end

    # Sort descending by normalized BM25 score
    sorted = hits.sort_by { |h| -h.score }

    # Assign ranks
    sorted.each_with_index do |doc, idx|
      doc.rank = idx + 1
    end

    sorted.first(limit)
  end

  #############################################################
  # HELPER TO CONVERT ES HIT → Struct
  #############################################################

  private

  def es_hits(results)
    results.response["hits"]["hits"].map do |hit|
      BM25Result.new(
        id: hit["_id"].to_s,
        trec_id: hit["_source"]["trec_id"],
        title: hit["_source"]["title"],
        body: hit["_source"]["body"],
        raw_score: hit["_score"].to_f,
        score: nil,
        rank: nil
      )
    end
  end
end
