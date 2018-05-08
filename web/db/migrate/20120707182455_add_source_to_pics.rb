class AddSourceToPics < ActiveRecord::Migration[4.2]
  def change
    add_column :pics, :source, :string
  end
end
