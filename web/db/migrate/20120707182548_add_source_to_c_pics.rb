class AddSourceToCPics < ActiveRecord::Migration[4.2]
  def change
    add_column :c_pics, :source, :string
  end
end
