# frozen_string_literal: true

require "json"
require "fileutils"

module Girb
  # デバッグセッションの会話履歴を永続化するクラス
  # 明示的にGirb.debug_sessionを設定した場合のみ保存される
  class SessionPersistence
    SESSIONS_DIR = ".girb/sessions"

    class << self
      attr_accessor :current_session_id

      # セッションが有効か（明示的にIDが指定されているか）
      def enabled?
        !!Girb.debug_session
      end

      # セッションディレクトリを取得（プロジェクトルートから）
      def sessions_dir
        # カレントディレクトリから.girbディレクトリを探す
        dir = Dir.pwd
        while dir != "/"
          girb_dir = File.join(dir, ".girb")
          if Dir.exist?(girb_dir)
            return File.join(girb_dir, "sessions")
          end
          dir = File.dirname(dir)
        end

        # 見つからなければカレントディレクトリに作成
        File.join(Dir.pwd, SESSIONS_DIR)
      end

      # セッションファイルのパスを取得
      def session_file_path(session_id)
        File.join(sessions_dir, "#{session_id}.json")
      end

      # セッションを開始（既存があれば読み込み）
      # Girb.debug_sessionが設定されている場合のみ有効
      def start_session
        return unless enabled?

        @current_session_id = Girb.debug_session

        file_path = session_file_path(@current_session_id)
        if File.exist?(file_path)
          load_session(file_path)
          puts "[girb] Resumed session: #{@current_session_id}"
        else
          ConversationHistory.reset!
          puts "[girb] New session: #{@current_session_id}"
        end

        @current_session_id
      end

      # セッションを保存
      def save_session
        return unless enabled? && @current_session_id

        file_path = session_file_path(@current_session_id)
        FileUtils.mkdir_p(File.dirname(file_path))

        data = {
          session_id: @current_session_id,
          saved_at: Time.now.to_s,
          messages: serialize_messages
        }

        File.write(file_path, JSON.pretty_generate(data))
      rescue => e
        puts "[girb] Failed to save session: #{e.message}"
      end

      # セッションを読み込み
      def load_session(file_path)
        data = JSON.parse(File.read(file_path), symbolize_names: true)

        ConversationHistory.reset!
        deserialize_messages(data[:messages])

        message_count = data[:messages]&.size || 0
        puts "[girb] Loaded #{message_count} messages from previous session"
      rescue => e
        puts "[girb] Failed to load session: #{e.message}"
        ConversationHistory.reset!
      end

      # 現在のセッションをクリア（ファイルも削除）
      def clear_session
        if @current_session_id
          delete_session(@current_session_id)
          @current_session_id = nil
        end
        ConversationHistory.reset!
        puts "[girb] Session cleared"
      end

      # セッション一覧を取得
      def list_sessions
        dir = sessions_dir
        return [] unless Dir.exist?(dir)

        Dir.glob(File.join(dir, "*.json")).map do |file|
          data = JSON.parse(File.read(file), symbolize_names: true)
          {
            id: data[:session_id],
            saved_at: data[:saved_at],
            message_count: data[:messages]&.size || 0
          }
        rescue
          nil
        end.compact
      end

      # セッションを削除
      def delete_session(session_id)
        file_path = session_file_path(session_id)
        if File.exist?(file_path)
          File.delete(file_path)
          puts "[girb] Session deleted: #{session_id}"
          true
        else
          puts "[girb] Session not found: #{session_id}"
          false
        end
      end

      private

      def serialize_messages
        ConversationHistory.messages.map do |msg|
          {
            role: msg.role,
            content: msg.content,
            tool_calls: msg.tool_calls
          }
        end
      end

      def deserialize_messages(messages)
        return unless messages

        messages.each do |msg|
          case msg[:role]
          when "user"
            ConversationHistory.add_user_message(msg[:content])
          when "model"
            # tool_callsがある場合は先にpending_tool_callsに追加
            if msg[:tool_calls]&.any?
              msg[:tool_calls].each do |tc|
                ConversationHistory.add_tool_call(
                  tc[:name],
                  tc[:args],
                  tc[:result],
                  id: tc[:id],
                  metadata: tc[:metadata]
                )
              end
            end
            ConversationHistory.add_assistant_message(msg[:content])
          end
        end
      end
    end
  end
end
