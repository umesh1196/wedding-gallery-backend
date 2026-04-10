class CreateGuestIdentities < ActiveRecord::Migration[8.1]
  class MigrationGuestIdentity < ApplicationRecord
    self.table_name = "guest_identities"
  end

  class MigrationGallerySession < ApplicationRecord
    self.table_name = "gallery_sessions"
  end

  def up
    create_table :guest_identities, id: :uuid do |t|
      t.references :wedding, null: false, foreign_key: true, type: :uuid
      t.string :token_digest, null: false
      t.string :normalized_visitor_name
      t.string :visitor_name

      t.timestamps
    end

    add_index :guest_identities, :token_digest, unique: true
    add_index :guest_identities, [ :wedding_id, :normalized_visitor_name ], unique: true, where: "normalized_visitor_name IS NOT NULL", name: "index_guest_identities_on_wedding_and_normalized_name"

    add_reference :gallery_sessions, :guest_identity, null: true, foreign_key: true, type: :uuid

    say_with_time "Backfilling guest identities for existing gallery sessions" do
      MigrationGallerySession.reset_column_information
      MigrationGuestIdentity.reset_column_information

      MigrationGallerySession.find_each do |session|
        normalized_name = normalize_name(session.visitor_name)
        identity = if normalized_name.present?
          MigrationGuestIdentity.find_or_create_by!(wedding_id: session.wedding_id, normalized_visitor_name: normalized_name) do |record|
            record.token_digest = digest_token(SecureRandom.urlsafe_base64(32))
            record.visitor_name = session.visitor_name
          end
        else
          MigrationGuestIdentity.create!(
            wedding_id: session.wedding_id,
            token_digest: digest_token(SecureRandom.urlsafe_base64(32)),
            normalized_visitor_name: nil,
            visitor_name: session.visitor_name
          )
        end

        session.update_columns(guest_identity_id: identity.id)
      end
    end
  end

  def down
    remove_reference :gallery_sessions, :guest_identity, foreign_key: true
    drop_table :guest_identities
  end

  private

  def normalize_name(value)
    value.to_s.strip.squish.downcase.presence
  end

  def digest_token(token)
    OpenSSL::Digest::SHA256.hexdigest(token.to_s)
  end
end
