class Api::TermResource < JSONAPI::Resource
  attributes :firstday, :lastday, :title, :critical, :longtitle
  has_many :forms
  has_many :courses
  has_many :course_profs
  has_many :tutors
  has_many :faculties

end
