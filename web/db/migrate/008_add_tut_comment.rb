# encoding: utf-8

class AddTutComment < ActiveRecord::Migration[4.2]
  def self.up
    add_column :tutors, :comment, :text
  end

  def self.down
    remove_column :tutors, :comment
  end
end
