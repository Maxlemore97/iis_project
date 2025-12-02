class DocumentsController < ApplicationController
  def index
    @queries = QueryDocument.order(:trec_id)
    query_id = params[:query_id]

    if query_id.blank?
      # No search → show random 20
      @documents = Document.order("RANDOM()").limit(20)
      @searched = false
    else
      # Load query text
      query_record = QueryDocument.find(query_id)
      @query = query_record.body

      # Perform Elasticsearch search
      results = Document.search(
        query: {
          multi_match: {
            query: @query,
            fields: ["title^2", "body"]
          }
        }
      )

      @documents = es_hits(results)
      @searched  = true
      @query_doc = query_record
    end
  end

  private

  def es_hits(results)
    results.response["hits"]["hits"].map do |hit|
      OpenStruct.new(
        id: hit["_id"],
        trec_id: hit["_source"]["trec_id"],
        title: hit["_source"]["title"],
        body: hit["_source"]["body"],
        score: hit["_score"]
      )
    end
  end
end
