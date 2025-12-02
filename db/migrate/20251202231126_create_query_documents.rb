class CreateQueryDocuments < ActiveRecord::Migration[6.1]
  def change
    create_table :query_documents do |t|
      t.string :trec_id
      t.string :title
      t.text   :body
      t.float  :style_vec, array: true

      t.timestamps
    end

    add_index :query_documents, :trec_id
  end
end
