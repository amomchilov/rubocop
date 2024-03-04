# frozen_string_literal: true

module RuboCop
  class CLI
    module Command
      # Suggest RuboCop extensions to install based on Gemfile dependencies.
      # Only primary dependencies are evaluated, so if a dependency depends on a
      # gem with an extension, it is not suggested. However, if an extension is
      # a transitive dependency, it will not be suggested.
      # @api private
      class SuggestExtensions < Base
        # Combination of short and long formatter names.
        INCLUDED_FORMATTERS = %w[p progress fu fuubar pa pacman].freeze

        self.command_name = :suggest_extensions

        def run
          return if skip? || extensions.none?

          print_install_suggestions if not_installed_extensions.any?
          print_load_suggestions if installed_and_not_loaded_extensions.any?

          print_opt_out_instruction

          puts if @options[:display_time]
        end

        private

        def skip?
          # Disable outputting the notification:
          # 1. On CI
          # 2. When given RuboCop options that it doesn't make sense for
          # 3. For all formatters except specified in `INCLUDED_FORMATTERS'`
          ENV.fetch('CI', nil) ||
            @options[:only] || @options[:debug] || @options[:list_target_files] ||
            @options[:out] || @options[:stdin] ||
            !INCLUDED_FORMATTERS.include?(current_formatter)
        end

        def print_install_suggestions
          puts
          puts 'Tip: Based on detected gems, the following ' \
               'RuboCop extension libraries might be helpful:'

          not_installed_extensions.sort.each do |extension|
            puts "  * #{extension} (https://rubygems.org/gems/#{extension})"
          end
        end

        def print_load_suggestions
          puts
          puts 'The following RuboCop extension libraries are installed but not loaded in config:'

          installed_and_not_loaded_extensions.sort.each do |extension|
            puts "  * #{extension}"
          end
        end

        def print_opt_out_instruction
          puts
          puts 'You can opt out of this message by adding the following to your config ' \
               '(see https://docs.rubocop.org/rubocop/extensions.html#extension-suggestions ' \
               'for more options):'
          puts '  AllCops:'
          puts '    SuggestExtensions: false'
        end

        def current_formatter
          @options[:format] || @config_store.for_pwd.for_all_cops['DefaultFormatter'] || 'p'
        end

        def all_extensions
          return [] unless installed_gems.any?

          should_suggest_extensions = @config_store.for_pwd.for_all_cops['SuggestExtensions']

          suggested_extensions = case should_suggest_extensions
                                 when true
                                   ConfigLoader.default_configuration.for_all_cops['SuggestExtensions']
                                 when false, nil
                                   {}
                                 end

          suggested_extensions.filter_map do |suggested_extension, relevant_gems|
            Array(relevant_gems).intersect?(dependent_gems) ? suggested_extension : nil
          end
        end

        def extensions
          not_installed_extensions + installed_and_not_loaded_extensions
        end

        def installed_extensions
          all_extensions & installed_gems
        end

        def not_installed_extensions
          all_extensions - installed_gems
        end

        def loaded_extensions
          @config_store.for_pwd.loaded_features.to_a
        end

        def installed_and_not_loaded_extensions
          installed_extensions - loaded_extensions
        end

        def lockfile
          @lockfile ||= Lockfile.new
        end

        def dependent_gems
          @dependent_gems ||= lockfile.gem_versions(include_transitive_dependencies: false).keys
        end

        def installed_gems
          @installed_gems ||= lockfile.gem_versions(include_transitive_dependencies: true).keys
        end

        def puts(*args)
          output = (@options[:stderr] ? $stderr : $stdout)
          output.puts(*args)
        end
      end
    end
  end
end
