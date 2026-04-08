module Api
  module V1
    class CeremoniesController < BaseController
      TEMPLATES = {
        "indian_wedding" => [
          "Engagement",
          "Haldi",
          "Mehendi",
          "Sangeet",
          "Wedding Ceremony",
          "Reception",
          "Candid Moments",
          "Family Portraits"
        ],
        "minimal" => [
          "Ceremony",
          "Reception",
          "Portraits"
        ]
      }.freeze

      def create
        ceremony = wedding.ceremonies.new(ceremony_params)
        ceremony.save!

        render_success(CeremonyBlueprint.render_as_hash(ceremony), status: :created)
      end

      def index
        render_success(CeremonyBlueprint.render_as_hash(wedding.ceremonies.order(:sort_order)))
      end

      def show
        render_success(CeremonyBlueprint.render_as_hash(ceremony))
      end

      def update
        ceremony.update!(ceremony_params)
        render_success(CeremonyBlueprint.render_as_hash(ceremony))
      end

      def upload_cover
        result = CeremonyCoverUploadService.new(ceremony: ceremony, upload: params[:file]).call
        render_success(result)
      rescue CeremonyCoverUploadService::UploadError => e
        render_error(e.message, status: :unprocessable_entity, code: "invalid_upload")
      end

      def destroy
        ceremony.destroy!
        render_success({ id: ceremony.id, deleted: true })
      end

      def reorder
        order = Array(params[:order]).map(&:to_s)
        ceremonies_by_id = wedding.ceremonies.where(id: order).index_by { |record| record.id.to_s }
        missing_ids = order - ceremonies_by_id.keys

        raise ActiveRecord::RecordNotFound, "Couldn't find Ceremony with provided ids" if missing_ids.any?

        Ceremony.transaction do
          order.each_with_index do |id, index|
            ceremonies_by_id.fetch(id).update_columns(sort_order: index, updated_at: Time.current)
          end
        end

        render_success(CeremonyBlueprint.render_as_hash(wedding.ceremonies.order(:sort_order)))
      end

      def seed
        if wedding.ceremonies.exists?
          return render_success(
            CeremonyBlueprint.render_as_hash(wedding.ceremonies.order(:sort_order)),
            meta: { seeded: false }
          )
        end

        template = TEMPLATES.fetch(params[:template]) do
          render_error("Unknown template", status: :unprocessable_entity, code: "validation_error")
          return
        end

        ceremonies = Ceremony.transaction do
          template.each_with_index.map do |name, index|
            wedding.ceremonies.create!(name: name, sort_order: index)
          end
        end

        render_success(CeremonyBlueprint.render_as_hash(ceremonies), status: :created, meta: { seeded: true })
      end

      private

      def wedding
        @wedding ||= current_studio.weddings.find_by!(slug: params[:wedding_slug])
      end

      def ceremony
        @ceremony ||= wedding.ceremonies.find_by!(slug: params[:slug])
      end

      def ceremony_params
        params.require(:ceremony).permit(:name, :slug, :cover_image_url, :description, :sort_order)
      end
    end
  end
end
