# encoding: utf-8

class AddContactInformation < ActiveRecord::Migration[4.2]
  def self.up
    add_column :courses, :fscontact, :string
  end

  def self.down
    remove_column :courses, :fscontact
  end
end
