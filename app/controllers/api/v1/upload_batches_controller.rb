module Api
  module V1
    class UploadBatchesController < BaseController
      def show
        batch = current_studio.upload_batches.find(params[:id])
        render_success(UploadBatchBlueprint.render_as_hash(batch))
      end
    end
  end
end
