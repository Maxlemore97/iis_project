require "ostruct"

class DocumentsElasticController < ApplicationController
  def index
    @queries = QueryDocument.order(:trec_id)

    # % importance of keyword similarity
    @weight = (params[:weight] || 20).to_i.clamp(0, 100)
    weight = @weight / 100.0

    query_id = params[:query_id]

    #
    # No query selected → return random documents
    #
    if query_id.blank?
      @searched = false
      @documents = Document.order("RANDOM()").limit(20)
      return
    end

    # ------------------------------------------------------
    # Load query document → we need text + style_keywords
    # ------------------------------------------------------
    query_record = QueryDocument.find(query_id)
    @query_doc = query_record

    query_text = "#{query_record.title} #{query_record.body}"
    query_keywords = (query_record.style_keywords || []).map(&:downcase)

    # If query has no keywords yet → generate and save them
    if query_keywords.empty?
      words = StyleFeatureService.tokenize(query_record.body)
      sentences = query_record.body.split(/(?<=[.!?])\s+/)

      new_keywords = StyleKeywordService.generate(
        words: words,
        sentences: sentences,
        style_vec: query_record.style_vec
      )

      query_record.update!(style_keywords: new_keywords)
      query_keywords = new_keywords.map(&:downcase)
    end

    bm25_boost = 1.0 - weight
    kw_boost = weight

    #
    # ======================================================
    # ONE Elasticsearch query combining BM25 + style keywords
    # ======================================================
    #
    es_query = {
      query: {
        bool: {
          should: [
            # text-relevance
            {
              multi_match: {
                query: query_text,
                fields: ["title^2", "body"],
                boost: bm25_boost
              }
            },
            # keyword overlap relevance
            {
              terms: {
                style_keywords: query_keywords,
                boost: kw_boost * 5.0 # keyword multiplier
              }
            }
          ]
        }
      },
      size: 200
    }

    results = Document.search(es_query)

    # Convert hits to structs with extracted fields
    raw_docs = es_hits(results)

    #
    # ======================================================
    # Normalize BM25 score (0..1)
    # ======================================================
    #
    max_bm25 = raw_docs.map(&:score).max || 1.0
    min_bm25 = raw_docs.map(&:score).min || 0.0

    range_bm25 = max_bm25 - min_bm25
    range_bm25 = 1.0 if range_bm25.zero?

    raw_docs.each do |d|
      d.norm_bm25 = (d.score - min_bm25) / range_bm25
    end

    #
    # ======================================================
    # Compute keyword similarity score (manual overlap)
    # ======================================================
    #
    raw_docs.each do |doc|
      doc_keywords = (doc.style_keywords || []).map(&:downcase)

      overlap = (doc_keywords & query_keywords).size
      union = (doc_keywords | query_keywords).size

      doc.keyword_score =
        union.zero? ? 0.0 : overlap.to_f / union
    end

    #
    # Normalize keyword scores
    #
    max_kw = raw_docs.map(&:keyword_score).max || 1.0
    raw_docs.each { |d| d.keyword_score /= max_kw }

    #
    # ======================================================
    # Hybrid score
    # ======================================================
    #
    raw_docs.each do |d|
      d.hybrid_score = (1.0 - weight) * d.norm_bm25 +
                       weight * d.keyword_score
    end

    #
    # Final sorting & selection
    #
    @documents = raw_docs.sort_by { |d| -d.hybrid_score }.first(20)
    @searched = true
  end

  def export_trec
    system_name = "hybrid_kw" # will appear in the file

    queries = QueryDocument.order(:trec_id).limit(50)

    lines = []

    queries.each do |query|
      query_text = "#{query.title} #{query.body}"

      # Ensure query has keywords
      q_keywords = (query.style_keywords || [])
      if q_keywords.empty?
        words = StyleFeatureService.tokenize(query.body)
        sentences = query.body.split(/(?<=[.!?])\s+/)
        new_kw = StyleKeywordService.generate(
          words: words,
          sentences: sentences,
          style_vec: query.style_vec
        )
        query.update!(style_keywords: new_kw)
        q_keywords = new_kw
      end
      q_keywords = q_keywords.map(&:downcase)

      #
      # Elasticsearch hybrid query (BM25 + keyword terms)
      #
      es_query = {
        query: {
          bool: {
            should: [
              {
                multi_match: {
                  query: query_text,
                  fields: ["title^2", "body"],
                  boost: 0.8
                }
              },
              {
                terms: {
                  style_keywords: q_keywords,
                  boost: 0.2 * 5.0
                }
              }
            ]
          }
        },
        size: 1000
      }

      results = Document.search(es_query)
      docs = es_hits(results)

      #
      # Compute keyword overlap for all docs
      #
      docs.each do |d|
        doc_kw = (d.style_keywords || []).map(&:downcase)
        overlap = (doc_kw & q_keywords).size
        union = (doc_kw | q_keywords).size
        d.keyword_score = union.zero? ? 0.0 : overlap.to_f / union
      end

      # Normalize keyword score
      max_kw = docs.map(&:keyword_score).max || 1.0
      docs.each { |d| d.keyword_score = d.keyword_score / max_kw }

      #
      # Normalize BM25 score
      #
      max_bm25 = docs.map(&:score).max || 1.0
      min_bm25 = docs.map(&:score).min || 0.0
      range_bm25 = max_bm25 - min_bm25
      range_bm25 = 1.0 if range_bm25.zero?

      docs.each do |d|
        d.norm_bm25 = (d.score - min_bm25) / range_bm25
      end

      #
      # Hybrid score = 0.8 BM25 + 0.2 Keyword
      #
      docs.each do |d|
        d.hybrid_score = 0.8 * d.norm_bm25 + 0.2 * d.keyword_score
      end

      #
      # Sort and take top 1000 (trec_eval allows max 1000 per query)
      #
      ranked = docs.sort_by { |d| -d.hybrid_score }.first(1000)

      #
      # Build TREC-EVAL LINES
      #
      ranked.each_with_index do |doc, rank|
        lines << [
          query.trec_id,
          "Q0",
          doc.trec_id,
          rank, # rank starts at 0
          doc.hybrid_score.round(4),
          system_name
        ].join(" ")
      end
    end

    #
    # Stream the file for download as .trec
    #
    send_data lines.join("\n"),
              filename: "trec_results_keyword_search.trec",
              type: "text/plain",
              disposition: :attachment
  end

  private

  #
  # Convert Elasticsearch hits → OpenStruct
  #
  def es_hits(results)
    results.response["hits"]["hits"].map do |hit|
      OpenStruct.new(
        id: hit["_id"],
        trec_id: hit["_source"]["trec_id"],
        title: hit["_source"]["title"],
        body: hit["_source"]["body"],
        style_keywords: hit["_source"]["style_keywords"] || [],
        score: hit["_score"].to_f, # BM25 score
        keyword_score: 0.0, # filled later
        hybrid_score: 0.0 # filled later
      )
    end
  end
end
