class DocumentsController < ApplicationController
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

    render json: results.records
  end
end
