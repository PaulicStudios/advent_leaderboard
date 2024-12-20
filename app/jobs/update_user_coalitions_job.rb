class UpdateUserCoalitionsJob < ApplicationJob
  class  IntraAPIError < StandardError; end
  extend FortytwoIntra

  queue_as :default

  def fortytwo_api_client
    @client ||= FortytwoIntra::APIClient.new(ENV['FORTYTWO_KEY'], ENV['FORTYTWO_SECRET'])
  end

  def perform(user)
    ActiveRecord::Base.transaction do
      resp = fortytwo_api_client.get_response("/v2/users/#{user.username}/coalitions_users")
      while (resp.status != 200 && try < 5) do
        logger.warn "Failed to fetch #{user.username}'s coalitions, retrying."
        sleep(1)
        resp = fortytwo_api_client.get_response('/v2/coalitions')
        try += 1
      end

      if try == 5 then
        raise IntraAPIError, "tried and failed to fetch #{user.username}'s coalitions five times"
      end

      user.coalitions = []
      resp.parsed.each do |coalition_data|
        user.coalitions << Coalition.find_by!(fortytwo_id: coalition_data['coalition_id'])
      end
    end

    # Now that we have updated the user's coalition list, we may have to
    # remove their currently selected coalition, in case it is no longer
    # one of their coalitions. In that case, we select a new one for them.
    if !user.coalitions.include?(user.coalition)
      user.update!(coalition: nil)
    end
  end
end
