# encoding: utf-8

class AddCourseLanguage < ActiveRecord::Migration[4.2]
  def self.up
    add_column :courses, :language, :string
  end

  def self.down
    remove_column :courses, :language
  end
end
