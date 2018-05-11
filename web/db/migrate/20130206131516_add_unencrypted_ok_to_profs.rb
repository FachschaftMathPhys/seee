class AddUnencryptedOkToProfs < ActiveRecord::Migration[5.1]
  def change
    add_column :profs, :unencrypted_ok, :boolean
  end
end
