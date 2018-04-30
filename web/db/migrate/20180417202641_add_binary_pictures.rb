class AddBinaryPictures < ActiveRecord::Migration[5.1]
  def change
    add_column :c_pics, :data, :binary
    add_column :pics, :data, :binary
    add_reference :c_pics, :sheet, index: true
    add_foreign_key :c_pics, :sheets
    add_reference :pics, :sheet, index: true
    add_foreign_key :pics, :sheets
  end
end
