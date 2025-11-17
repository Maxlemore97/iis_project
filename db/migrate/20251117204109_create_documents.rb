class CreateDocuments < ActiveRecord::Migration[7.2]
  def change
    create_table :documents do |t|
      t.string :trec_id
      t.string :title
      t.text :body

      t.timestamps
    end
  end
end
