class Person < ApplicationRecord
  belongs_to :wedding
  has_many :person_photos, dependent: :destroy
  has_many :photos, through: :person_photos

  validates :label, presence: true
  validates :label, uniqueness: { scope: :wedding_id, case_sensitive: false }
end
