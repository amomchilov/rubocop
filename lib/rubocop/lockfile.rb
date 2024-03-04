# frozen_string_literal: true

begin
  # We might not be running with `bundle exec`, so we need to pull in Bundler ourselves,
  # in order to use `Bundler::LockfileParser`.
  require 'bundler'
rescue LoadError
  nil
end

module RuboCop
  # Encapsulation of a lockfile for use when checking for gems.
  # Does not actually resolve gems, just parses the lockfile.
  # @api private
  class Lockfile
    # @param [String, Pathname, nil] lockfile_path
    def initialize(lockfile_path = nil)
      lockfile_path ||= begin
        ::Bundler.default_lockfile if bundler_lock_parser_defined?
      rescue ::Bundler::GemfileNotFound
        nil # We might not be a folder with a Gemfile, but that's okay.
      end

      @lockfile_path = lockfile_path
    end

    # Returns the locked versions of gems from this lockfile.
    # @param [Boolean] include_transitive_dependencies: When false, only direct dependencies
    #   are returned, i.e. those listed explicitly in the `Gemfile`.
    # @returns [Hash{String => Gem::Version}] The locked gem versions, keyed by the gems' names.
    def gem_versions(include_transitive_dependencies: true)
      return {} unless parser

      if include_transitive_dependencies
        gem_version_including_transitive
      else
        gem_version_excluding_transitive
      end
    end

    private

    def gem_version_including_transitive
      @gem_version_including_transitive ||= parser.specs.to_h { |spec| [spec.name, spec.version] }
    end

    def gem_version_excluding_transitive
      @gem_version_excluding_transitive ||= begin
        direct_dep_names = parser.dependencies.keys
        gem_version_including_transitive.slice(*direct_dep_names)
      end
    end

    # @return [Bundler::LockfileParser, nil]
    def parser
      return @parser if defined?(@parser)

      @parser = if @lockfile_path && File.exist?(@lockfile_path) && bundler_lock_parser_defined?
                  begin
                    lockfile = ::Bundler.read_file(@lockfile_path)
                    ::Bundler::LockfileParser.new(lockfile) if lockfile
                  rescue ::Bundler::BundlerError
                    nil
                  end
                end
    end

    def bundler_lock_parser_defined?
      Object.const_defined?(:Bundler) && Bundler.const_defined?(:LockfileParser)
    end
  end
end
