class Api::ProfResource < JSONAPI::Resource
 attributes :firstname, :surname, :email, :gender, :gender_symbol
 has_many :course_profs
 has_many :courses

end
