class AddFaceRecognitionStatusToPhotos < ActiveRecord::Migration[8.1]
  def change
    add_column :photos, :face_recognition_status, :string, null: false, default: "pending"
    add_column :photos, :face_recognition_error, :string
    add_column :photos, :face_recognized_at, :datetime

    add_index :photos, [ :wedding_id, :face_recognition_status ],
              name: "index_photos_on_wedding_id_and_face_recognition_status",
              where: "face_recognition_status IN ('pending', 'failed')"
  end
end
