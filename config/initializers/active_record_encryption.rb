Rails.application.configure do
  primary_key = ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"].presence
  deterministic_key = ENV["ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"].presence
  key_derivation_salt = ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"].presence

  if primary_key.blank? || deterministic_key.blank? || key_derivation_salt.blank?
    if Rails.env.development? || Rails.env.test?
      primary_key ||= "0" * 32
      deterministic_key ||= "1" * 32
      key_derivation_salt ||= "2" * 32
    else
      raise "Active Record encryption keys are required"
    end
  end

  config.active_record.encryption.primary_key = primary_key
  config.active_record.encryption.deterministic_key = deterministic_key
  config.active_record.encryption.key_derivation_salt = key_derivation_salt
end
