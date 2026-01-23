class EpisodesController < ApplicationController
  before_action :set_podcast
  before_action :set_episode, only: [ :show, :edit, :update, :destroy, :submit_episode, :start_editing, :complete_editing, :revert_to_draft, :re_submit_for_editing, :approve_episode, :publish_episode ]
  before_action -> { authorize_resource_access(@episode) }, only: [ :show, :edit, :update, :destroy, :submit_episode, :start_editing, :complete_editing, :revert_to_draft, :re_submit_for_editing, :approve_episode, :publish_episode ]
  before_action :authorize_editing, only: [ :edit, :update ]
  before_action -> { authorize_resource_access(@podcast) }, only: [ :index ]

  def index
    # All episodes for this podcast. Authorization above ensures access.
    @episodes = @podcast.episodes
  end

  def start_wizard
    next_number = (@podcast.episodes.maximum(:number) || 0) + 1
    @episode = @podcast.episodes.build(
      status: :draft,
      name: "",
      number: next_number
    )
    @episode.save!(validate: false)
    redirect_to podcast_episode_wizard_path(@podcast.id, @episode.id, :overview), notice: "Started creating your episode."
  end

  def new
    @episode = @podcast.episodes.build
  end

  def create
    @episode = @podcast.episodes.build(episode_params)
    if @episode.save
      redirect_to podcast_episode_path(@podcast, @episode), notice: "Episode was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def edit
    # Only allow editing if episode is in draft or edit_requested status
    unless @episode.draft?
      redirect_to podcast_episode_path(@podcast, @episode), alert: "Cannot edit episode while it's being edited by a producer."
    end
  end

  def update
    # Only allow updating if episode is in draft or edit_requested status
    unless @episode.draft?
      redirect_to podcast_episode_path(@podcast, @episode), alert: "Cannot edit episode while it's being edited by a producer."
    end

    if @episode.update(episode_params)
      redirect_to podcast_episode_path(@podcast, @episode), notice: "Episode was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @episode.destroy
    redirect_to podcast_episodes_path(@podcast), notice: "Episode was successfully deleted."
  end

  def submit_episode
    if @episode.submit_for_editing!
      redirect_to podcast_episode_path(@podcast, @episode), notice: "Episode submitted for editing successfully."
    else
      redirect_to podcast_episode_path(@podcast, @episode), alert: "Unable to submit episode for editing."
    end
  end

  def revert_to_draft
    if @episode.revert_to_draft!
      redirect_to podcast_episode_path(@podcast, @episode), notice: "Episode reverted to draft successfully."
    else
      redirect_to podcast_episode_path(@podcast, @episode), alert: "Unable to revert episode to draft."
    end
  end

  def start_editing
    if @episode.start_editing!
      redirect_to podcast_episode_path(@podcast, @episode), notice: "Started editing episode."
    else
      redirect_to podcast_episode_path(@podcast, @episode), alert: "Unable to start editing episode."
    end
  end

  def complete_editing
    unless @episode.edited_audio.attached?
      return redirect_to podcast_episode_path(@podcast, @episode), alert: "Please upload the edited audio before submitting for review."
    end

    if @episode.complete_editing!
      redirect_to podcast_episode_path(@podcast, @episode), notice: "Submitted edited episode for user review."
    else
      redirect_to podcast_episode_path(@podcast, @episode), alert: "Unable to submit edited episode."
    end
  end

  def re_submit_for_editing
    if @episode.re_submit_for_editing!
      redirect_to podcast_episode_path(@podcast, @episode), notice: "Episode has been re-submitted for editing."
    else
      redirect_to podcast_episode_path(@podcast, @episode), alert: "Unable to re-submit episode for editing."
    end
  end

  def approve_episode
    if @episode.approve_episode!
      redirect_to podcast_episode_path(@podcast, @episode), notice: "Approved. Producer can now publish."
    else
      redirect_to podcast_episode_path(@podcast, @episode), alert: "Unable to approve episode."
    end
  end

def publish_episode
  if @episode.publish!
    redirect_to podcast_episode_path(@podcast, @episode), notice: "Episode published."
  else
    redirect_to podcast_episode_path(@podcast, @episode), alert: "Unable to publish episode."
  end
end

  private

  def set_podcast
    @podcast = Podcast.find(params[:podcast_id])
  end

  def set_episode
    @episode = @podcast.episodes.find(params[:id])
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
      :guests,
      :output_formats,
      :deliver_mp3,
      :deliver_mp4,
      :deliver_mov,
      :raw_audio,
      :edited_audio,
      :cover_art,
      output_formats: [],
      assets: []
    )
  end

  # This method can stay as-is since it has specific business logic
  def authorize_editing
    if Current.user.user?
      redirect_to podcast_episodes_path(@podcast), alert: "Access denied." unless @episode.podcast.user == Current.user
    end
  end
end
