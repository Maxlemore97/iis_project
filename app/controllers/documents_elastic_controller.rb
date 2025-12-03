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
      words     = StyleFeatureService.tokenize(query_record.body)
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
    # Compute keyword similarity score (manual overlap)
    # ======================================================
    #
    raw_docs.each do |doc|
      doc_keywords = (doc.style_keywords || []).map(&:downcase)

      overlap = (doc_keywords & query_keywords).size
      union = (doc_keywords | query_keywords).size

      kw_score =
        if union.zero?
          0.0
        else
          overlap.to_f / union
        end

      doc.keyword_score = kw_score
    end

    #
    # Normalize keyword scores
    #
    max_kw = raw_docs.map { |d| d.keyword_score }.max || 1.0
    raw_docs.each do |d|
      d.keyword_score = d.keyword_score / max_kw
    end

    #
    # ======================================================
    # Hybrid score
    # ======================================================
    #
    raw_docs.each do |d|
      d.hybrid_score = (1.0 - weight) * d.score.to_f +
                       weight * d.keyword_score
    end

    #
    # Final sorting & selection
    #
    @documents = raw_docs.sort_by { |d| -d.hybrid_score }.first(20)
    @searched = true
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
