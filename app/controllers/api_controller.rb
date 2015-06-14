class ApiController < ApplicationController
  include ActionController::Live

  # The run_remote method will be secured with a key so shouldn't need csrf token authentication
  skip_before_filter :verify_authenticity_token, :only => [:run_remote]

  # Receive code from a remote client, run it and return the result.
  # This will be a long running request
  def run_remote
    puts "**** IN RUN_REMOTE ****"
    # TODO: Get the id of the person making the request and set current_user.
    user = User.find_by_api_key(params[:api_key])
    if user.nil?
      render :text => "API key is not valid", status: 401
    elsif !user.ability.can? :create, Run
      response.headers['Content-Type'] = 'text/event-stream'
      response.stream.write({stream: "stdout", text: "You currently can't start a scraper run. See https://morph.io for more details"}.to_json + "\n")
      response.stream.close
    else
      run = Run.create(queued_at: Time.now, auto: false, owner_id: user.id)

      # TODO: Shouldn't need to untar here because it just gets retarred
      Archive::Tar::Minitar.unpack(params[:code].tempfile, run.repo_path)

      result = []
      response.headers['Content-Type'] = 'text/event-stream'
      Morph::Runner.new(run).go do |s,text|
        response.stream.write({stream: s, text: text}.to_json + "\n")
      end
      response.stream.close

      # Cleanup run
      FileUtils.rm_rf(run.data_path)
      FileUtils.rm_rf(run.repo_path)
    end
  end
end
