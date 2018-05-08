class RemoveHasLowerFromPics < ActiveRecord::Migration[4.2]
  def up
    remove_column :pics, :has_lower
      end

  def down
    add_column :pics, :has_lower, :boolean
  end
end
