# encoding: utf-8

class AddNoteToCourse < ActiveRecord::Migration[4.2]
  def self.up
    add_column :courses, :note, :text
  end

  def self.down
    remove_column :courses, :note
  end
end
