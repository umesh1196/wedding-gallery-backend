module Api
  module V1
    class StorageConnectionsController < BaseController
      def index
        connections = current_studio.studio_storage_connections.order(:created_at)
        render_success(StudioStorageConnectionBlueprint.render_as_hash(connections))
      end

      def create
        connection = current_studio.studio_storage_connections.new(storage_connection_params)
        connection.save!

        render_success(StudioStorageConnectionBlueprint.render_as_hash(connection), status: :created)
      end

      def update
        storage_connection.update!(storage_connection_params)
        render_success(StudioStorageConnectionBlueprint.render_as_hash(storage_connection))
      end

      def destroy
        storage_connection.update!(active: false, is_default: false)
        render_success(StudioStorageConnectionBlueprint.render_as_hash(storage_connection))
      end

      private

      def storage_connection
        @storage_connection ||= current_studio.studio_storage_connections.find(params[:id])
      end

      def storage_connection_params
        permitted = params.require(:storage_connection).permit(
          :label, :provider, :account_id, :bucket, :region, :endpoint,
          :access_key, :secret_key, :access_key_ciphertext, :secret_key_ciphertext,
          :base_prefix, :is_default, :active
        ).to_h

        if permitted.key?("access_key_ciphertext") && !permitted.key?("access_key")
          permitted["access_key"] = permitted.delete("access_key_ciphertext")
        end

        if permitted.key?("secret_key_ciphertext") && !permitted.key?("secret_key")
          permitted["secret_key"] = permitted.delete("secret_key_ciphertext")
        end
        permitted
      end
    end
  end
end
