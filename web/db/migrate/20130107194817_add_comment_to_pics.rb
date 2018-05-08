class AddCommentToPics < ActiveRecord::Migration[4.2]
  def change
    add_column :pics, :text, :text
    add_column :pics, :step, :integer
  end
end
