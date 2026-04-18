require "cgi"

class ClientMailer < ApplicationMailer
  def invite
    @client = params.fetch(:client)
    @invite_url = invite_url(@client.invite_token)

    mail(to: @client.email, subject: "You have been invited to NaturoPath")
  end

  def password_reset
    @client = params.fetch(:client)
    @reset_token = params.fetch(:reset_token)
    @reset_url = password_reset_url(@reset_token)

    mail(to: @client.email, subject: "Reset your NaturoPath password")
  end

  private

  def invite_url(invite_token)
    build_token_url(ENV["CLIENT_INVITE_URL"].presence, "invite_token", invite_token)
  end

  def password_reset_url(reset_token)
    build_token_url(ENV["CLIENT_PASSWORD_RESET_URL"].presence, "reset_token", reset_token)
  end

  def build_token_url(base_url, param_name, token)
    return token if base_url.blank?

    separator = base_url.include?("?") ? "&" : "?"
    "#{base_url}#{separator}#{param_name}=#{CGI.escape(token)}"
  end
end
