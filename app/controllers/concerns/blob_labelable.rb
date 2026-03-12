# Generic concern for persisting user-supplied labels into ActiveStorage blob metadata.
# Include in any controller that needs to save label params to blob records.
#
# Usage:
#   process_blob_labels(record, :assets, label_key: :asset_labels)
#   process_blob_labels(record, :deliverables, label_key: :deliverable_labels)
#
# For has_one_attached (single file), use process_single_blob_label instead:
#   process_single_blob_label(record, :cover_art, label_key: :cover_art_labels)
module BlobLabelable
  extend ActiveSupport::Concern

  private

  # Persist labels for a has_many_attached collection (e.g. assets, deliverables).
  def process_blob_labels(record, attachment_name, label_key:)
    labels = blob_label_hash(label_key) || {}
    json_labels = blob_label_json(:"#{label_key}_json") || {}
    return if labels.blank? && json_labels.blank?

    record.public_send(attachment_name).attachments.each do |attachment|
      filename = attachment.filename.to_s
      labels[attachment.id.to_s] = json_labels[filename] if json_labels[filename].present?
    end

    record.public_send(attachment_name).attachments.each do |attachment|
      label_value = labels[attachment.id.to_s].presence || labels[attachment.blob.id.to_s].presence
      next if label_value.blank?

      update_blob_label(attachment.blob, label_value)
    end
  end

  # Persist label for a has_one_attached file (e.g. cover_art).
  def process_single_blob_label(record, attachment_name, label_key:)
    attached = record.public_send(attachment_name)
    return unless attached.attached?

    blob = attached.blob
    attachment = attached.attachment
    return unless blob && attachment

    labels = blob_label_hash(label_key) || {}
    json_labels = blob_label_json(:"#{label_key}_json") || {}

    labels[blob.id.to_s] = json_labels[blob.filename.to_s] if json_labels[blob.filename.to_s].present?

    label_value = labels[attachment.id.to_s].presence || labels[blob.id.to_s].presence
    return if label_value.blank?

    update_blob_label(blob, label_value)
  end

  # Read a label hash (id => label) from top-level params or params[:episode/:podcast].
  def blob_label_hash(key)
    raw = params[key].presence || params.dig(:episode, key).presence || params.dig(:podcast, key).presence
    return {} if raw.blank?

    raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw.to_h
  rescue StandardError
    {}
  end

  # Read a label JSON map (filename => label) from top-level params or nested params.
  def blob_label_json(key)
    raw = params[key].presence || params.dig(:episode, key).presence || params.dig(:podcast, key).presence
    return {} if raw.blank?

    JSON.parse(raw.to_s)
  rescue JSON::ParserError
    {}
  end

  def update_blob_label(blob, label_value)
    return if blob.blank? || label_value.blank?

    new_metadata = blob.metadata.merge("label" => label_value.to_s.strip)
    blob.update!(metadata: new_metadata)
  rescue StandardError
    # Silently ignore metadata update errors
  end
end
