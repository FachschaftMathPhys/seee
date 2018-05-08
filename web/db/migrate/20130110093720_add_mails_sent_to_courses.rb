class AddMailsSentToCourses < ActiveRecord::Migration[4.2]
  def change
    add_column :courses, :mails_sent, :string
  end
end
