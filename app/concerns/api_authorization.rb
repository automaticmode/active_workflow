module APIAuthorization
  attr_reader :current_user

  def authorize_request!
    unless user_id_in_token?
        error!('401 Unauthorized', 401)
      return
    end
    @current_user = User.find(auth_token[:user_id])
  rescue JWT::VerificationError, JWT::DecodeError
    error!('401 Unauthorized', 401) unless current_user
  end

  private

  def http_token
    @http_token ||= if headers['Authorization'].present?
                      headers['Authorization'].split(' ').last
                    end
  end

  def auth_token
    @auth_token ||= JsonWebToken.decode(http_token)
  end

  def user_id_in_token?
    http_token && auth_token && auth_token[:user_id].to_i
  end
end
