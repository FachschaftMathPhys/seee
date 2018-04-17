class Api::ProfResource < JSONAPI::Resource
  attributes :firstname, :surname, :email, :gender, :gender_symbol
  has_many :course_profs
  has_many :courses
 def self.updatable_fields(context)
   super - [:gender_symbol]
 end
 def self.creatable_fields(context)
   super - [:gender_symbol]
 end
end
