class DocumentsController < ApplicationController
  def index
    # Show the newest 20 documents
    @documents = Document.order(created_at: :desc).limit(20)
  end

  def search
    query = params[:q]

    results = Document.search({
                                query: {
                                  multi_match: {
                                    query: query,
                                    fields: ["title^2", "body"]
                                  }
                                }
                              })

    # TODO: For once forensic analysis

    render json: results.records
  end

  def search_two
    query = params[:q]

    results = Document.search({
                                query: {
                                  multi_match: {
                                    query: query,
                                    fields: ["title^2", "body"]
                                  }
                                }
                              })

    render json: results.records
  end
end
