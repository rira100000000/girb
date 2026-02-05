# frozen_string_literal: true

module Girb
  # デバッグセッション中の入力とAI会話を管理するクラス
  class DebugSessionHistory
    Entry = Struct.new(:type, :content, :response, :timestamp, keyword_init: true)

    class << self
      def instance
        @instance ||= new
      end

      def reset!
        @instance = new
      end

      # 委譲メソッド
      def record_command(command)
        instance.record_command(command)
      end

      def record_ai_question(question)
        instance.record_ai_question(question)
      end

      def record_ai_response(response)
        instance.record_ai_response(response)
      end

      def entries
        instance.entries
      end

      def recent(count = 20)
        instance.recent(count)
      end

      def ai_conversations
        instance.ai_conversations
      end

      def format_history(count = 20)
        instance.format_history(count)
      end
    end

    attr_reader :entries

    def initialize
      @entries = []
      @pending_ai_entry = nil
    end

    # デバッガーコマンドを記録
    def record_command(command)
      return if command.nil? || command.strip.empty?

      @entries << Entry.new(
        type: :command,
        content: command.strip,
        response: nil,
        timestamp: Time.now
      )
    end

    # AI質問を記録（回答は後から追加）
    def record_ai_question(question)
      entry = Entry.new(
        type: :ai_question,
        content: question,
        response: nil,
        timestamp: Time.now
      )
      @entries << entry
      @pending_ai_entry = entry
    end

    # AI回答を記録
    def record_ai_response(response)
      if @pending_ai_entry
        @pending_ai_entry.response = response
        @pending_ai_entry = nil
      end
    end

    # 最近のエントリを取得
    def recent(count = 20)
      @entries.last(count)
    end

    # AI会話のみを取得
    def ai_conversations
      @entries.select { |e| e.type == :ai_question && e.response }
    end

    # フォーマットされた履歴を取得
    def format_history(count = 20)
      recent(count).map do |entry|
        case entry.type
        when :command
          "[cmd] #{entry.content}"
        when :ai_question
          if entry.response
            response_preview = truncate(entry.response, 150)
            "[ai] Q: #{entry.content}\n     A: #{response_preview}"
          else
            "[ai] Q: #{entry.content} (pending...)"
          end
        end
      end.join("\n")
    end

    private

    def truncate(str, max_length)
      return str if str.nil?

      str.length > max_length ? "#{str[0, max_length]}..." : str
    end
  end
end
