class AddAgreedToProfs < ActiveRecord::Migration[5.1]
  def change
    add_column :profs, :agreed, :boolean, :default => false
  end
end
