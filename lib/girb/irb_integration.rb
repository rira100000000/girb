# frozen_string_literal: true

require "irb"
require "irb/command"
require_relative "exception_capture"
require_relative "context_builder"

module Girb
  module IrbIntegration
    def self.setup
      # qq コマンドを登録
      require_relative "../irb/command/qq"

      # 例外キャプチャのインストール
      ExceptionCapture.install
    end
  end
end
