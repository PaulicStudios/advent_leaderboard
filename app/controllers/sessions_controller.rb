class SessionsController < ApplicationController
  before_action :logged_in_user,    only: :destroy
  before_action :already_logged_in, only: :create

  # Creates a session cookie, adds the user to the database if they do not
  # exist yet, then redirects them to the root url.
  def create
    auth = request.env['omniauth.auth']

    unless auth.extra.raw_info.campus.any? { |campus| campus.id == (ENV['CAMPUS_ID']&.to_i || 14) } # Codam's ID is 14
      flash[:danger] = 'You are not associated with Codam, so you cannot log in here!'
      redirect_to root_url
      return
    end

    user = User.find_or_initialize_by(username: auth.info.login)
    user.full_name = auth.extra.raw_info.usual_full_name
    user.photo_url = auth.extra.raw_info.image.versions.medium

    user.save!

    log_in(user)
    flash[:info] = 'Successfully logged in.'
    # logger.info auth
    redirect_to root_url
  end

  # Destroys the session cookie and logs the user out.
  def destroy
    log_out

    flash[:info] = 'Successfully logged out.'
    redirect_to root_url
  end

  # Endpoint reached when something goes wrong during OAuth
  def failure
    flash[:warning] = 'Login was unsuccessful, please try again!'
    redirect_to root_url
  end

  private

  def already_logged_in
    return unless logged_in?

    flash[:warning] = 'You are already logged in!'
    redirect_to root_url
  end
end
