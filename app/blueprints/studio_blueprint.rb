class StudioBlueprint < Blueprinter::Base
  identifier :id

  fields :email, :studio_name, :slug, :phone, :plan, :plan_expires_at, :created_at
end
