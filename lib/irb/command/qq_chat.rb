# frozen_string_literal: true

require "irb/command"

module IRB
  module Command
    class QqChat < Base
      category "AI Assistant"
      description "Toggle AI chat mode - ask questions without qq prefix"

      def execute(_arg)
        Girb::AiMode.toggle(irb_context)
      end
    end
  end
end

IRB::Command.register(:"qq-chat", IRB::Command::QqChat)
