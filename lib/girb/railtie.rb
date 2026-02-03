# frozen_string_literal: true

module Girb
  class Railtie < Rails::Railtie
    console do
      require "irb" unless defined?(IRB)
      Girb::GirbrcLoader.load_girbrc(Rails.root)
      Girb.setup!
    end
  end
end
