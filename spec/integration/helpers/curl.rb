# frozen_string_literal: true

require "net/http"
require "uri"

##
# What we expect from the environment and from passed parameters.

hostname   = ENV["PORTUS_MACHINE_FQDN_VALUE"]
method     = ARGV[0].downcase
endpoint   = ARGV[1]
username   = ARGV[2]
parameters = ARGV[3]

##
# Initialize the request object.

uri = URI.parse("http://#{hostname}:3000#{endpoint}")
req = Net::HTTP.const_get(method.capitalize).new(uri)
req["Accept"] = "application/json"

if method == "post" && parameters.present?
  ##
  # Application token

  ApplicationToken.delete_all
  user = User.find_by(username: username)
  _, plain = ApplicationToken.create_token(
    current_user: user, user_id: user.id, params: { application: "integration-test" }
  )
  req["Portus-Auth"] = "#{username}:#{plain}"

  ##
  # Body

  req["Content-Type"] = "application/json"
  body = {}
  parameters.split(",").each do |kv|
    k, v = kv.split("=", 2)
    first, second = k.split(".", 2)
    if second.nil?
      body[first] = v
    else
      body[first] = body.fetch(first, {})
      body[first][second] = v
    end
  end
  req.body = body.to_json
end

##
# Perform the HTTP request and print the response.

response = Net::HTTP.start(uri.hostname, uri.port) do |http|
  http.request(req)
end

puts response.body
exit 0 if response.code.to_i == 200 || response.code.to_i == 201
exit 1
