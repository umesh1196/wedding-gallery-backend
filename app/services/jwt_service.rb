class JwtService
  SECRET = ENV.fetch("JWT_SECRET", "change_me_in_production")

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
