require "spec_helper"
require "support/active_record"

app_require "controllers/debug_controller"

describe "DebugController" do
  describe "GET /debug" do
    before do
      delayed_job = double "Delayed::Job"
      allow(delayed_job).to receive(:count).and_return(42)
      stub_const("Delayed::Job", delayed_job)

      migration_status_instance = double "migration_status_instance"
      allow(migration_status_instance).to receive(:pending_migrations).and_return ["Migration B - 2", "Migration C - 3"]
      migration_status = double "MigrationStatus"
      allow(migration_status).to receive(:new).and_return(migration_status_instance)
      stub_const("MigrationStatus", migration_status)
    end

    it "displays the current Ruby version" do
      get "/debug"

      page = last_response.body
      expect(page).to have_tag("dd", text: /#{RUBY_VERSION}/)
    end

    it "displays the user agent" do
      get "/debug", {}, "HTTP_USER_AGENT" => "test"

      page = last_response.body
      expect(page).to have_tag("dd", text: /test/)
    end

    it "displays the delayed job count" do
      get "/debug"

      page = last_response.body
      expect(page).to have_tag("dd", text: /42/)
    end

    it "displays pending migrations" do
      get "/debug"

      page = last_response.body
      expect(page).to have_tag("li", text: /Migration B - 2/)
      expect(page).to have_tag("li", text: /Migration C - 3/)
    end
  end

  describe "#heroku" do
    it "displays Heroku instructions" do
      get("/heroku")

      expect(last_response.body).to include("add an hourly task")
    end
  end
end
