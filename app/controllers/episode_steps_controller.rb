class EpisodeStepsController < ApplicationController
  include Wicked::Wizard
  steps :overview, :assets, :details, :summary

  before_action :set_podcast
  before_action :set_episode
  before_action :set_steps
  before_action -> { authorize_resource_access(@episode) }

  def show
    session.delete(:validation_errors)
    render_wizard
  end

  def update
    session.delete(:validation_errors)

    # (reverted) no JSON upload handling here

    if params[:episode].present?
      filtered_params = episode_params

      # Prevent blank file inputs from purging existing attachments
      filtered_params = filtered_params.except(:assets) if filtered_params[:assets]&.all?(&:blank?)
      filtered_params = filtered_params.except(:raw_audio) if filtered_params[:raw_audio].blank?
      filtered_params = filtered_params.except(:cover_art) if filtered_params[:cover_art].blank?

      @episode.assign_attributes(filtered_params) if filtered_params.present?
    end

    valid = case step
    when :overview
              @episode.valid?(:overview_step)
    when :details
              @episode.valid?(:details_step)
    else
              true
    end

    if valid
      if @episode.save(validate: false)
        if step == steps.last
          redirect_to_finish_wizard
        else
          redirect_to next_wizard_path
        end
      else
        render step
      end
    else
      session[:validation_errors] = @episode.errors.full_messages
      render step
    end
  end

  private

  def set_podcast
    @podcast = Podcast.find(params[:podcast_id])
  end

  def set_episode
    @episode = @podcast.episodes.find(params[:episode_id])
  end

  def set_steps
    @steps = steps
  end

  def episode_params
    params.require(:episode).permit(
      :name,
      :number,
      :description,
      :links,
      :release_date,
      :format,
      :notes,
      :raw_audio,
      :cover_art,
      assets: []
    )
  end

  def redirect_to_finish_wizard
    redirect_to podcast_episode_path(@podcast, @episode), notice: "Episode created successfully."
  end
end
