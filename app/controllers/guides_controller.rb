class GuidesController < ApplicationController
  def index
    @state_options = Edition::STATES.map { |s| [s.titleize, s] }

    # TODO: :content_owner not being included is resulting in an N+1 query
    @guides = Guide.includes(editions: [:author]).references(:editions)
                   .by_author(params[:author])
                   .in_state(params[:state])
                   .owned_by(params[:content_owner])
                   .page(params[:page])

    if params[:q].present?
      @guides = @guides.search(params[:q])
    else
      @guides = @guides.order(updated_at: :desc)
    end
  end

  def new
    type = params[:type].presence_in(%w{ GuideCommunity Point })

    @guide_form = GuideForm.new(
      guide: Guide.new(type: type),
      edition: Edition.new,
      user: current_user,
      )
  end

  def create
    guide = Guide.new(type: guide_form_params[:type])
    edition = guide.editions.build
    @guide_form = GuideForm.new(
      guide: guide,
      edition: edition,
      user: current_user,
      )
    @guide_form.assign_attributes(guide_form_params)

    publication = Publisher.new(content_model: @guide_form)
                    .save_draft(GuideFormPublicationPresenter.new(@guide_form))
    if publication.success?
      redirect_to edit_guide_path(@guide_form), notice: 'Guide has been created'
    else
      flash.now[:error] = publication.error
      render 'new'
    end
  end

  def edit
    guide = Guide.find(params[:id])
    edition = guide.latest_edition

    @guide_form = GuideForm.new(
      guide: guide,
      edition: edition,
      user: current_user
      )
  end

  def update
    guide = Guide.find(params[:id])
    edition = guide.editions.build(guide.latest_edition.dup.attributes)

    @guide_form = GuideForm.new(
      guide: guide,
      edition: edition,
      user: current_user
      )

    if params[:send_for_review].present?
      send_for_review
    elsif params[:approve_for_publication].present?
      approve_for_publication
    elsif params[:publish].present?
      publish
    elsif params[:discard].present?
      discard
    else
      save_draft
    end
  end

private

  def send_for_review
    ApprovalProcess.new(content_model: @guide_form.guide).request_review

    redirect_to edit_guide_path(@guide_form), notice: "A review has been requested"
  end

  def approve_for_publication
    ApprovalProcess.new(content_model: @guide_form.guide).give_approval(approver: current_user)

    redirect_to edit_guide_path(@guide_form), notice: "Thanks for approving this guide"
  end

  def publish
    unless @guide_form.guide.included_in_a_topic?
      flash[:error] = "This guide could not be published because it is not included in a topic page."
      render 'edit'
      return
    end

    @guide_form.edition.assign_attributes(state: 'published')

    publication = Publisher.new(content_model: @guide_form.guide).publish
    if publication.success?
      index_for_search(@guide_form.guide)

      unless @guide_form.edition.notification_subscribers == [current_user]
        NotificationMailer.published(@guide_form.guide, current_user).deliver_later
      end

      redirect_to edit_guide_path(@guide_form), notice: "Guide has been published"
    else
      flash.now[:error] = publication.error
      render 'edit'
    end
  end

  def discard
    discard_draft = Publisher.new(content_model: @guide_form.guide)
      .discard_draft
    if discard_draft.success?
      redirect_to root_path, notice: "Draft has been discarded"
    else
      flash.now[:error] = discard_draft.error
      render 'edit'
    end
  end

  def save_draft
    @guide_form.assign_attributes(guide_form_params)

    publication = Publisher.new(content_model: @guide_form)
                    .save_draft(GuideFormPublicationPresenter.new(@guide_form))
    if publication.success?
      redirect_to edit_guide_path(@guide_form), notice: "Guide has been updated"
    else
      flash.now[:error] = publication.error
      render 'edit'
    end
  end

  def guide_form_params
    params.fetch(:guide, {})
  end

  def index_for_search(guide)
    GuideSearchIndexer.new(guide).index
  rescue => e
    notify_airbrake(e)
    Rails.logger.error(e.message)
  end
end
