class AddCommentToCPics < ActiveRecord::Migration[4.2]
  def change
    add_column :c_pics, :text, :text
    add_column :c_pics, :step, :integer
  end
end
