class JwtService
  SECRET = ENV["JWT_SECRET"].presence || (
    if Rails.env.development? || Rails.env.test?
      "dev_test_jwt_secret"
    else
      raise KeyError, "JWT_SECRET is required"
    end
  )

  def self.encode(payload, exp: 7.days.from_now)
    payload = payload.dup
    payload[:exp] = exp.to_i
    JWT.encode(payload, SECRET, "HS256")
  end

  def self.decode(token)
    JWT.decode(token, SECRET, true, algorithm: "HS256").first
  rescue JWT::DecodeError, JWT::ExpiredSignature
    nil
  end
end
