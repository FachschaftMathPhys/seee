class RemovePublishOkFromProfs < ActiveRecord::Migration[5.1]
  def up
    remove_column :profs, :publish_ok
  end

  def down
    add_column :profs, :publish_ok, :boolean, :default => false
  end
end
