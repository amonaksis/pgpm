# frozen_string_literal: true

module Pgpm
  module OS
    class Base
      attr_reader :arch

      include Pgpm::Aspects::InheritanceTracker

      def self.name
        "unknown"
      end

      def name
        self.class.name
      end

      def self.builder
        nil
      end

      def with_scope(&block)
        LSpace.with(pgpm_target_operating_system: self) do
          block.yield
        end
      end
    end

    def self.auto_detect
      return unless RUBY_PLATFORM =~ /linux$/

      Pgpm::OS::Linux.auto_detect
    end

    def self.in_scope
      LSpace[:pgpm_target_operating_system]
    end
  end
end
