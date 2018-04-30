class Api::CourseProfResource < JSONAPI::Resource
  attributes :returned_sheets
  has_one :course
  has_one :prof
  has_one :form
  has_one :term
  has_many :c_pics
end
