# frozen_string_literal: true

module Girb
  # IRBセッション中の全入力を行番号付きで管理し、
  # メソッド定義を追跡するクラス
  class SessionHistory
    Entry = Struct.new(:line_no, :code, :method_definition, :is_ai_question, :ai_response, :ai_reasoning, keyword_init: true)
    MethodDef = Struct.new(:name, :start_line, :end_line, :code, keyword_init: true)

    class << self
      def instance
        @instance ||= new
      end

      def reset!
        @instance = new
      end

      # 委譲メソッド
      def record(line_no, code, is_ai_question: false)
        instance.record(line_no, code, is_ai_question: is_ai_question)
      end

      def entries
        instance.entries
      end

      def method_definitions
        instance.method_definitions
      end

      def find_by_line(line_no)
        instance.find_by_line(line_no)
      end

      def find_by_line_range(start_line, end_line)
        instance.find_by_line_range(start_line, end_line)
      end

      def find_method(name)
        instance.find_method(name)
      end

      def all_with_line_numbers
        instance.all_with_line_numbers
      end

      def method_index
        instance.method_index
      end

      def record_ai_response(line_no, response, reasoning = nil)
        instance.record_ai_response(line_no, response, reasoning)
      end

      def get_ai_detail(line_no)
        instance.get_ai_detail(line_no)
      end

      def ai_conversations
        instance.ai_conversations
      end
    end

    attr_reader :entries, :method_definitions

    def initialize
      @entries = []
      @method_definitions = []
      @pending_method = nil
    end

    # IRBからの入力を記録
    def record(line_no, code, is_ai_question: false)
      code = code.to_s.chomp

      entry = Entry.new(line_no: line_no, code: code, method_definition: nil, is_ai_question: is_ai_question)

      # メソッド定義の開始を検出
      if code.match?(/^\s*def\s+\w+/)
        @pending_method = {
          start_line: line_no,
          code_lines: [code]
        }
      elsif @pending_method
        @pending_method[:code_lines] << code

        # メソッド定義の終了を検出（簡易的なend検出）
        if code.strip == "end" || code.match?(/^\s*end\s*$/)
          method_name = extract_method_name(@pending_method[:code_lines].first)
          full_code = @pending_method[:code_lines].join("\n")

          method_def = MethodDef.new(
            name: method_name,
            start_line: @pending_method[:start_line],
            end_line: line_no,
            code: full_code
          )
          @method_definitions << method_def
          entry.method_definition = method_def
          @pending_method = nil
        end
      end

      @entries << entry
    end

    # 特定の行番号のエントリを取得
    def find_by_line(line_no)
      @entries.find { |e| e.line_no == line_no }
    end

    # 行範囲のエントリを取得
    def find_by_line_range(start_line, end_line)
      @entries.select { |e| e.line_no >= start_line && e.line_no <= end_line }
    end

    # メソッド名でメソッド定義を検索
    def find_method(name)
      name = name.to_s
      @method_definitions.find { |m| m.name == name }
    end

    # 全履歴を行番号付きで取得
    def all_with_line_numbers
      @entries.map do |e|
        if e.is_ai_question
          # AI会話は質問と回答をまとめて表示
          response_preview = if e.ai_response
                               truncate(e.ai_response, 100)
                             else
                               "(回答待ち)"
                             end
          "#{e.line_no}: [USER] #{e.code} => [AI] #{response_preview}"
        else
          "#{e.line_no}: #{e.code}"
        end
      end
    end

    def truncate(str, max_length)
      str.length > max_length ? str[0, max_length] + "..." : str
    end

    # メソッド定義のインデックス（メソッド名: 行範囲）
    def method_index
      @method_definitions.map do |m|
        if m.start_line == m.end_line
          "#{m.name}: #{m.start_line}行目"
        else
          "#{m.name}: #{m.start_line}-#{m.end_line}行目"
        end
      end
    end

    # AI質問への回答と思考の過程を記録
    def record_ai_response(line_no, response, reasoning = nil)
      entry = find_by_line(line_no)
      return unless entry

      entry.ai_response = response
      entry.ai_reasoning = reasoning
    end

    # 特定の行のAI詳細情報を取得
    def get_ai_detail(line_no)
      entry = find_by_line(line_no)
      return nil unless entry&.ai_response

      {
        line_no: entry.line_no,
        question: entry.code,
        response: entry.ai_response,
        reasoning: entry.ai_reasoning
      }
    end

    # AI会話の一覧（質問と回答のみ、思考の過程は含まない）
    def ai_conversations
      @entries.select { |e| e.is_ai_question && e.ai_response }.map do |e|
        {
          line_no: e.line_no,
          question: e.code,
          response: e.ai_response
        }
      end
    end

    private

    def extract_method_name(def_line)
      # "def foo" や "def foo(bar)" からメソッド名を抽出
      match = def_line.match(/def\s+(\w+[?!=]?)/)
      match ? match[1] : "unknown"
    end
  end
end
