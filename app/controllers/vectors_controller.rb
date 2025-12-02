class VectorsController < ApplicationController
  def index
    # Load 10 example documents that have a style_vec
    @documents = Document.where.not(style_vec: nil).limit(10)
  end
end
