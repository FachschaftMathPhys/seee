class Api::CourseResource < JSONAPI::Resource
  attributes :title, :students, :evaluator, :description, :summary, :fscontact, :language, :note, :mails_sent
  has_one :form
  has_one :term
  has_one :faculty
  has_many :course_profs
  has_many :profs
  has_many :c_pics
  has_many :tutors
end
