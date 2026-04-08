class Album < ApplicationRecord
  ALBUM_TYPES = %w[studio_curated user_created].freeze
  VISIBILITIES = %w[private shared].freeze

  belongs_to :ceremony
  belongs_to :created_by_studio, class_name: "Studio", optional: true
  belongs_to :created_by_gallery_session, class_name: "GallerySession", optional: true
  belongs_to :cover_photo, class_name: "Photo", optional: true

  has_many :album_photos, -> { order(:sort_order, :id) }, dependent: :destroy
  has_many :album_share_links, dependent: :destroy
  has_many :photos, through: :album_photos

  before_validation :normalize_slug
  before_validation :generate_slug, if: :should_generate_slug?

  validates :album_type, inclusion: { in: ALBUM_TYPES }
  validates :visibility, inclusion: { in: VISIBILITIES }
  validates :name, presence: true
  validates :slug, presence: true, uniqueness: { scope: :ceremony_id }
  validate :single_owner_path
  validate :creator_matches_album_type
  validate :cover_photo_matches_ceremony

  delegate :wedding, to: :ceremony

  def studio_curated?
    album_type == "studio_curated"
  end

  def user_created?
    album_type == "user_created"
  end

  def owned_by_studio?(studio)
    studio_curated? && created_by_studio == studio
  end

  def owned_by_gallery_session?(gallery_session)
    user_created? && created_by_gallery_session == gallery_session
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

    while self.class.where(ceremony_id: ceremony_id, slug: candidate).where.not(id: id).exists?
      candidate = "#{base}-#{counter}"
      counter += 1
    end

    self.slug = candidate
  end

  def single_owner_path
    owners = [ created_by_studio.present?, created_by_gallery_session.present? ].count(true)
    return if owners == 1

    errors.add(:base, "must have exactly one owner")
  end

  def creator_matches_album_type
    return unless errors[:base].blank?
    return if studio_curated? && created_by_studio.present? && created_by_gallery_session.blank?
    return if user_created? && created_by_gallery_session.present? && created_by_studio.blank?

    errors.add(:album_type, "must match the creator type")
  end

  def cover_photo_matches_ceremony
    return if cover_photo.blank? || ceremony.blank?
    return if cover_photo.ceremony_id == ceremony_id

    errors.add(:cover_photo, "must belong to the same ceremony")
  end
end
