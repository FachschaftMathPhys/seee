class Api::FacultyResource < JSONAPI::Resource
  attributes :longname, :shortname, :critical
  has_many :courses
  has_many :course_profs
  def critical
    @model.critical?
  end
end
