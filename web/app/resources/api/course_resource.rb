class Api::CourseResource < JSONAPI::Resource
  attributes :title, :students, :evaluator, :description, :summary, :fscontact, :language, :note, :mails_sent, :returned_sheets, :comment
  has_one :form
  has_one :term
  has_one :faculty
  has_many :course_profs
  has_many :profs
  has_many :c_pics
  has_many :tutors
  filter :faculty_id, apply: ->(records, value, _options) {
    return records.where(faculty_id: value)
  }
  filter :term_id, apply: ->(records, value, _options) {
    return records.where( term_id:value)
  }
  def creatable_fields
    super -[:returned_sheets]
  end
  def updatable_fields
    super -[:returned_sheets]
  end
end
