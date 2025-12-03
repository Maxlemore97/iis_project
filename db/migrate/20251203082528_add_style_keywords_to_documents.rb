class AddStyleKeywordsToDocuments < ActiveRecord::Migration[7.1]
  def change
    add_column :documents, :style_keywords, :text, array: true, default: []
    add_column :query_documents, :style_keywords, :text, array: true, default: []
  end
end
