class AddStyleVecToDocuments < ActiveRecord::Migration[7.2]
  def change
    add_column :documents, :style_vec, :float, array: true, default: [], null: true
  end
end
