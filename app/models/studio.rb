class Studio < ApplicationRecord
  has_secure_password

  before_validation :generate_slug, if: -> { studio_name_changed? || slug.blank? }

  validates :email,       presence: true, uniqueness: { case_sensitive: false },
                          format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :studio_name, presence: true
  validates :slug,        presence: true, uniqueness: true

  private

  def generate_slug
    return if studio_name.blank?

    base = studio_name.parameterize
    candidate = base
    counter = 1

    while Studio.where(slug: candidate).where.not(id: id).exists?
      candidate = "#{base}-#{counter}"
      counter += 1
    end

    self.slug = candidate
  end
end
