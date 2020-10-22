# This controller is designed to allow your agents to receive cross-site webhooks (POSTs), or to output data streams.
# When a POST or GET is received, your agent will have #receive_web_request called on itself with the incoming params,
# method, and requested content-type.
#
# Requests are routed as follows:
#   http://yourserver.com/users/:user_id/web_requests/:agent_id/:secret
# where :user_id is a User's id, :agent_id is an agent's id, and :secret is a token that should be user-specifiable in
# an agent that implements #receive_web_request. It is highly recommended that every agent verify this token whenever
# #receive_web_request is called. For example, one of your agent's options could be :secret and you could compare this
# value to params[:secret] whenever #receive_web_request is called on your agent, rejecting invalid requests.
#
# Your agent's #receive_web_request method should return an array of json_or_string_response, status_code,
# optional mime type, and optional hash of custom response headers.  For example:
#   [{status: "success"}, 200]
# or
#   ["not found", 404, 'text/plain']
# or
#   ["<status>success</status>", 200, 'text/xml', {"Access-Control-Allow-Origin" => "*"}]

class WebRequestsController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!

  # rubocop:disable Metrics/CyclomaticComplexity
  # rubocop:disable Metrics/PerceivedComplexity
  def handle_request
    user = User.find_by_id(params[:user_id])
    if user
      agent = user.agents.find_by_id(params[:agent_id])
      if agent
        content, status, content_type, headers = agent.trigger_web_request(request)

        if headers.present?
          headers.each do |k, v|
            response.headers[k] = v
          end
        end

        status ||= 200

        if status.to_s.in?(%w[301 302])
          redirect_to content, status: status
        elsif content.is_a?(String)
          render plain: content, status: status, content_type: content_type || 'text/plain'
        elsif content.is_a?(Hash)
          render json: content, status: status
        else
          head(status)
        end
      else
        render plain: 'agent not found', status: 404
      end
    else
      render plain: 'user not found', status: 404
    end
  end
  # rubocop:enable Metrics/PerceivedComplexity
  # rubocop:enable Metrics/CyclomaticComplexity
end
