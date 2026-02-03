# frozen_string_literal: true

module Girb
  class Railtie < Rails::Railtie
    console do
      Girb::GirbrcLoader.load_girbrc(Rails.root)
    end
  end
end
