class Api::TermResource < JSONAPI::Resource
  attributes :firstday, :lastday, :title, :critical, :longtitle
  has_many :forms
  has_many :courses
  has_many :course_profs
  has_many :tutors
  has_many :faculties
  filter :is_active, apply: ->(records, value, _options) {
    if value
      d = Date.today
      return records.where(["firstday <= ? AND lastday >= ?", d, d])
    else
      return records
    end
  }
end
