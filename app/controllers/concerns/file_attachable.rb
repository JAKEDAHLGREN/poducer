module FileAttachable
  extend ActiveSupport::Concern

  private

  # Attach uploaded files to an ActiveStorage association.
  #
  # record           - The ActiveRecord model instance
  # attachment_name  - Symbol name of the has_many_attached association (e.g. :assets, :deliverables)
  # success_redirect - Path for HTML format on success
  # error_redirect   - Path for HTML format when no files provided (optional)
  # &turbo_block     - Block yielded for turbo_stream format response
  def attach_files(record, attachment_name, success_redirect:, error_redirect: nil, &turbo_block)
    incoming = params[:files].presence || params[:file].presence

    unless incoming
      respond_to do |format|
        format.json { render json: { error: "No files provided" }, status: :unprocessable_entity }
        format.turbo_stream { head :unprocessable_entity }
        format.html do
          if error_redirect
            redirect_to error_redirect, alert: "No files provided."
          else
            head :unprocessable_entity
          end
        end
      end
      return
    end

    Array(incoming).each { |file| record.public_send(attachment_name).attach(file) }

    respond_to do |format|
      format.json { render json: { ok: true, count: record.public_send(attachment_name).count }, status: :ok }
      format.turbo_stream(&turbo_block) if turbo_block
      format.html { redirect_to success_redirect, notice: "Files uploaded." }
    end
  end
end
