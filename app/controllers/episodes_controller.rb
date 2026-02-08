class EpisodesController < ApplicationController
  include SetPodcastAndEpisode
  include EpisodeLabelable

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
      process_episode_asset_labels(@episode)
      process_episode_cover_art_label(@episode)
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
    perform_transition(:submit_for_editing!,
      notice: "Episode submitted for editing successfully.",
      alert: "Unable to submit episode for editing.")
  end

  def revert_to_draft
    perform_transition(:revert_to_draft!,
      notice: "Episode reverted to draft successfully.",
      alert: "Unable to revert episode to draft.")
  end

  def start_editing
    perform_transition(:start_editing!,
      notice: "Started editing episode.",
      alert: "Unable to start editing episode.")
  end

  def complete_editing
    unless @episode.edited_audio.attached?
      return redirect_to podcast_episode_path(@podcast, @episode),
             alert: "Please upload the edited audio before submitting for review."
    end

    perform_transition(:complete_editing!,
      notice: "Submitted edited episode for user review.",
      alert: "Unable to submit edited episode.")
  end

  def re_submit_for_editing
    perform_transition(:re_submit_for_editing!,
      notice: "Episode has been re-submitted for editing.",
      alert: "Unable to re-submit episode for editing.")
  end

  def approve_episode
    perform_transition(:approve_episode!,
      notice: "Approved. Producer can now publish.",
      alert: "Unable to approve episode.")
  end

  def publish_episode
    perform_transition(:publish!,
      notice: "Episode published.",
      alert: "Unable to publish episode.")
  end

  private

  def perform_transition(method, notice:, alert:)
    if @episode.public_send(method)
      redirect_to podcast_episode_path(@podcast, @episode), notice: notice
    else
      redirect_to podcast_episode_path(@podcast, @episode), alert: alert
    end
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
