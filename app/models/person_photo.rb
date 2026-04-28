class PersonPhoto < ApplicationRecord
  belongs_to :person
  belongs_to :photo
end
