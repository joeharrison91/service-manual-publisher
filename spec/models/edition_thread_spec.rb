require 'rails_helper'

RSpec.describe EditionThread, "#events" do
  describe "new draft event" do
    it "the first event is a 'new draft' event" do
      most_recent_edition = create(:edition, version: 1)

      event = described_class.new(most_recent_edition).events.first

      expect(event).to be_a(EditionThread::NewDraftEvent)
    end

    it "relates to the first edition in the thread" do
      first_edition = create(:edition, version: 1, created_at: 1.day.ago)
      most_recent_edition = create(:edition, version: 1)

      event = described_class.new(most_recent_edition).events.first

      expect(event.edition).to eq(first_edition)
    end
  end

  describe "assigned to event" do
    it "the second event is an 'assigned to' event" do
      most_recent_edition = create(:edition, version: 1)

      event = described_class.new(most_recent_edition).events.second

      expect(event).to be_a(EditionThread::AssignedToEvent)
    end

    it "relates to the first edition in the thread" do
      first_edition = create(:edition, version: 1, created_at: 1.day.ago)
      most_recent_edition = create(:edition, version: 1)

      event = described_class.new(most_recent_edition).events.second

      expect(event.edition).to eq(first_edition)
    end
  end

  describe "comment event" do
    it "is a 'comment' event" do
      most_recent_edition = create(:edition, version: 1)
      most_recent_edition.comments.create!(comment: "My words are gold")

      event = described_class.new(most_recent_edition).events.third

      expect(event).to be_a(EditionThread::CommentEvent)
    end

    it "has a reference to the comment" do
      most_recent_edition = create(:edition, version: 1)
      comment = most_recent_edition.comments.create!(comment: "My words are gold")

      event = described_class.new(most_recent_edition).events.third

      expect(event.comment).to eq(comment)
    end

    it "returns them chronologically" do
      most_recent_edition = create(:edition, version: 1)
      most_recent_edition.comments.create!(comment: "My words are gold", created_at: 1.day.ago)
      most_recent_edition.comments.create!(comment: "Are you sure?", created_at: 2.day.ago)

      events = described_class.new(most_recent_edition).events

      expect(events.third.comment.comment).to eq("Are you sure?")
      expect(events.fourth.comment.comment).to eq("My words are gold")
    end
  end

  describe "state change event" do
    it "is a 'state change' event" do
      first_edition = create(:edition, version: 1, created_at: 1.day.ago)
      most_recent_edition = create(:edition, version: 1, state: 'review_requested')

      event = described_class.new(most_recent_edition).events.third

      expect(event).to be_a(EditionThread::StateChangeEvent)
    end

    it "has a reference to the edition in which the state changed" do
      first_edition = create(:edition, version: 1, created_at: 1.day.ago)
      most_recent_edition = create(:edition, version: 1, state: 'review_requested')

      event = described_class.new(most_recent_edition).events.third

      expect(event.edition).to eq(most_recent_edition)
    end

    it "adds a state change event if the state changes back" do
      draft_edition = create(:edition, version: 1, created_at: 1.day.ago)
      review_requested_edition = create(:edition, version: 1, state: 'review_requested')
      next_draft_edition = create(:edition, version: 1, state: 'draft')

      events = described_class.new(next_draft_edition).events

      expect(events.third.edition).to eq(review_requested_edition)
      expect(events.fourth.edition).to eq(next_draft_edition)
    end
  end
end
