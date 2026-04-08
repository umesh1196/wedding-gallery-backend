class StudioStorageConnectionBlueprint < Blueprinter::Base
  identifier :id

  fields :label, :provider, :account_id, :bucket, :region, :endpoint,
         :base_prefix, :is_default, :active
end
