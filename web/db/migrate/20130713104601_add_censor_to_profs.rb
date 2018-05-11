class AddCensorToProfs < ActiveRecord::Migration[5.1]
  def change
    add_column :profs, :censor, :string
  end
end
