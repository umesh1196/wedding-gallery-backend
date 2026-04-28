class PrintSelectionBucket < ApplicationRecord
  belongs_to :wedding
  belongs_to :created_by_studio, class_name: "Studio"

  has_many :print_selection_photos, -> { order(:created_at, :id) }, dependent: :destroy
  has_many :photos, through: :print_selection_photos

  before_validation :normalize_slug
  before_validation :generate_slug, if: :should_generate_slug?

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: { scope: :wedding_id }
  validates :selection_limit, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :sort_order, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :ordered, -> { order(:sort_order, :created_at, :id) }

  def locked?
    locked_at.present?
  end

  def remaining_count
    [ selection_limit - selected_count, 0 ].max
  end

  def cover_photo
    @cover_photo ||= print_selection_photos.includes(:photo).first&.photo
  end

  private

  def normalize_slug
    self.slug = slug.to_s.parameterize.presence if slug.present?
  end

  def should_generate_slug?
    name.present? && (slug.blank? || (will_save_change_to_name? && !will_save_change_to_slug?))
  end

  def generate_slug
    base = name.to_s.parameterize
    candidate = base
    counter = 1

    while self.class.where(wedding_id: wedding_id, slug: candidate).where.not(id: id).exists?
      candidate = "#{base}-#{counter}"
      counter += 1
    end

    self.slug = candidate
  end
end
