# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "json"

RSpec.describe Girb::SessionPersistence do
  let(:tmpdir) { Dir.mktmpdir }

  after(:each) do
    FileUtils.remove_entry(tmpdir) if File.exist?(tmpdir)
  end

  describe ".enabled?" do
    it "returns false when debug_session is nil" do
      Girb.debug_session = nil
      expect(described_class.enabled?).to be false
    end

    it "returns true when debug_session is set" do
      Girb.debug_session = "test-session"
      expect(described_class.enabled?).to be true
    end

    it "returns false when debug_session is false" do
      Girb.debug_session = false
      expect(described_class.enabled?).to be false
    end
  end

  describe ".sessions_dir" do
    context "when .girb directory exists in current directory" do
      it "returns sessions path under .girb" do
        girb_dir = File.join(tmpdir, ".girb")
        Dir.mkdir(girb_dir)
        allow(Dir).to receive(:pwd).and_return(tmpdir)

        expect(described_class.sessions_dir).to eq(File.join(girb_dir, "sessions"))
      end
    end

    context "when .girb directory exists in parent" do
      it "traverses upward to find .girb" do
        parent = tmpdir
        child = File.join(tmpdir, "sub", "dir")
        FileUtils.mkdir_p(child)
        girb_dir = File.join(parent, ".girb")
        Dir.mkdir(girb_dir)
        allow(Dir).to receive(:pwd).and_return(child)

        expect(described_class.sessions_dir).to eq(File.join(girb_dir, "sessions"))
      end
    end

    context "when no .girb directory exists" do
      it "defaults to current directory" do
        allow(Dir).to receive(:pwd).and_return(tmpdir)

        expected = File.join(tmpdir, ".girb/sessions")
        expect(described_class.sessions_dir).to eq(expected)
      end
    end
  end

  describe ".session_file_path" do
    it "returns a JSON file path for the session ID" do
      allow(Dir).to receive(:pwd).and_return(tmpdir)
      path = described_class.session_file_path("my-session")
      expect(path).to end_with("my-session.json")
    end
  end

  describe ".start_session" do
    before do
      girb_dir = File.join(tmpdir, ".girb")
      Dir.mkdir(girb_dir)
      allow(Dir).to receive(:pwd).and_return(tmpdir)
    end

    context "when not enabled" do
      it "returns nil" do
        Girb.debug_session = nil
        expect(described_class.start_session).to be_nil
      end
    end

    context "when enabled with new session" do
      it "sets current_session_id" do
        Girb.debug_session = "new-session"
        described_class.start_session
        expect(described_class.current_session_id).to eq("new-session")
      end

      it "resets conversation history" do
        Girb::ConversationHistory.add_user_message("old message")
        Girb.debug_session = "new-session"
        described_class.start_session
        expect(Girb::ConversationHistory.messages).to be_empty
      end
    end

    context "when enabled with existing session file" do
      it "loads existing session" do
        sessions_dir = File.join(tmpdir, ".girb", "sessions")
        FileUtils.mkdir_p(sessions_dir)

        data = {
          session_id: "existing",
          saved_at: Time.now.iso8601,
          messages: [
            { role: "user", content: "hello" },
            { role: "model", content: "hi there" }
          ]
        }
        File.write(File.join(sessions_dir, "existing.json"), JSON.pretty_generate(data))

        Girb.debug_session = "existing"
        described_class.start_session

        expect(Girb::ConversationHistory.messages.size).to eq(2)
      end
    end
  end

  describe ".save_session" do
    before do
      girb_dir = File.join(tmpdir, ".girb")
      Dir.mkdir(girb_dir)
      allow(Dir).to receive(:pwd).and_return(tmpdir)
    end

    context "when not enabled" do
      it "does nothing" do
        Girb.debug_session = nil
        described_class.save_session
        sessions_dir = File.join(tmpdir, ".girb", "sessions")
        expect(Dir.exist?(sessions_dir)).to be false
      end
    end

    context "when enabled" do
      before do
        Girb.debug_session = "save-test"
        described_class.current_session_id = "save-test"
        Girb::ConversationHistory.add_user_message("test question")
        Girb::ConversationHistory.add_assistant_message("test answer")
      end

      it "creates session file" do
        described_class.save_session
        file = described_class.session_file_path("save-test")
        expect(File.exist?(file)).to be true
      end

      it "saves messages as JSON" do
        described_class.save_session
        file = described_class.session_file_path("save-test")
        data = JSON.parse(File.read(file), symbolize_names: true)
        expect(data[:session_id]).to eq("save-test")
        expect(data[:messages].size).to eq(2)
        expect(data[:messages][0][:role]).to eq("user")
        expect(data[:messages][1][:role]).to eq("model")
      end

      it "includes saved_at timestamp" do
        described_class.save_session
        file = described_class.session_file_path("save-test")
        data = JSON.parse(File.read(file), symbolize_names: true)
        expect(data[:saved_at]).not_to be_nil
      end

      it "creates sessions directory if needed" do
        described_class.save_session
        sessions_dir = File.join(tmpdir, ".girb", "sessions")
        expect(Dir.exist?(sessions_dir)).to be true
      end
    end
  end

  describe ".load_session" do
    it "loads and deserializes messages" do
      data = {
        session_id: "load-test",
        saved_at: Time.now.iso8601,
        messages: [
          { role: "user", content: "question" },
          { role: "model", content: "answer" }
        ]
      }
      file = File.join(tmpdir, "session.json")
      File.write(file, JSON.pretty_generate(data))

      described_class.load_session(file)

      messages = Girb::ConversationHistory.messages
      expect(messages.size).to eq(2)
      expect(messages[0].role).to eq("user")
      expect(messages[0].content).to eq("question")
      expect(messages[1].role).to eq("model")
      expect(messages[1].content).to eq("answer")
    end

    it "loads messages with tool calls" do
      data = {
        session_id: "tc-test",
        saved_at: Time.now.iso8601,
        messages: [
          { role: "user", content: "do something" },
          {
            role: "model",
            content: "done",
            tool_calls: [{ id: "tc1", name: "evaluate_code", args: { code: "1" }, result: { result: "1" } }]
          }
        ]
      }
      file = File.join(tmpdir, "session.json")
      File.write(file, JSON.pretty_generate(data))

      described_class.load_session(file)

      messages = Girb::ConversationHistory.messages
      expect(messages.size).to eq(2)
      expect(messages[1].tool_calls).to be_an(Array)
      expect(messages[1].tool_calls.size).to eq(1)
    end

    it "handles invalid JSON gracefully" do
      file = File.join(tmpdir, "bad.json")
      File.write(file, "not json")

      expect { described_class.load_session(file) }.not_to raise_error
      expect(Girb::ConversationHistory.messages).to be_empty
    end
  end

  describe ".clear_session" do
    before do
      girb_dir = File.join(tmpdir, ".girb")
      Dir.mkdir(girb_dir)
      allow(Dir).to receive(:pwd).and_return(tmpdir)
    end

    it "resets conversation history" do
      Girb::ConversationHistory.add_user_message("hello")
      described_class.clear_session
      expect(Girb::ConversationHistory.messages).to be_empty
    end

    it "clears current_session_id" do
      described_class.current_session_id = "test"
      described_class.clear_session
      expect(described_class.current_session_id).to be_nil
    end

    it "deletes session file if exists" do
      sessions_dir = File.join(tmpdir, ".girb", "sessions")
      FileUtils.mkdir_p(sessions_dir)
      file = File.join(sessions_dir, "test.json")
      File.write(file, "{}")

      described_class.current_session_id = "test"
      described_class.clear_session
      expect(File.exist?(file)).to be false
    end
  end

  describe ".list_sessions" do
    before do
      girb_dir = File.join(tmpdir, ".girb")
      Dir.mkdir(girb_dir)
      allow(Dir).to receive(:pwd).and_return(tmpdir)
    end

    it "returns empty array when no sessions dir" do
      expect(described_class.list_sessions).to eq([])
    end

    it "returns session info for each file" do
      sessions_dir = File.join(tmpdir, ".girb", "sessions")
      FileUtils.mkdir_p(sessions_dir)

      2.times do |i|
        data = {
          session_id: "session-#{i}",
          saved_at: Time.now.iso8601,
          messages: [{ role: "user", content: "msg" }]
        }
        File.write(File.join(sessions_dir, "session-#{i}.json"), JSON.pretty_generate(data))
      end

      sessions = described_class.list_sessions
      expect(sessions.size).to eq(2)
      expect(sessions.first[:id]).to start_with("session-")
      expect(sessions.first[:message_count]).to eq(1)
    end

    it "skips invalid session files" do
      sessions_dir = File.join(tmpdir, ".girb", "sessions")
      FileUtils.mkdir_p(sessions_dir)
      File.write(File.join(sessions_dir, "bad.json"), "not json")

      expect(described_class.list_sessions).to eq([])
    end
  end

  describe ".delete_session" do
    before do
      girb_dir = File.join(tmpdir, ".girb")
      Dir.mkdir(girb_dir)
      allow(Dir).to receive(:pwd).and_return(tmpdir)
    end

    it "deletes existing session file and returns true" do
      sessions_dir = File.join(tmpdir, ".girb", "sessions")
      FileUtils.mkdir_p(sessions_dir)
      file = File.join(sessions_dir, "to-delete.json")
      File.write(file, "{}")

      expect(described_class.delete_session("to-delete")).to be true
      expect(File.exist?(file)).to be false
    end

    it "returns false for non-existent session" do
      expect(described_class.delete_session("nonexistent")).to be false
    end
  end
end
