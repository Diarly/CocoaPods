require 'colored'
require 'claide'
require 'molinillo/errors'

module Molinillo
  class ResolverError
    include CLAide::InformativeError
  end
end

module Pod
  class PlainInformative
    include CLAide::InformativeError
  end

  class Command < CLAide::Command
    require 'cocoapods/command/options/repo_update'
    require 'cocoapods/command/options/project_directory'
    include Options

    require 'cocoapods/command/cache'
    require 'cocoapods/command/env'
    require 'cocoapods/command/init'
    require 'cocoapods/command/install'
    require 'cocoapods/command/ipc'
    require 'cocoapods/command/lib'
    require 'cocoapods/command/list'
    require 'cocoapods/command/outdated'
    require 'cocoapods/command/repo'
    require 'cocoapods/command/setup'
    require 'cocoapods/command/spec'
    require 'cocoapods/command/update'

    self.abstract_command = true
    self.command = 'pod'
    self.version = VERSION
    self.description = 'CocoaPods, the Cocoa library package manager.'
    self.plugin_prefixes = %w(claide cocoapods)

    def self.options
      [
        ['--silent', 'Show nothing'],
      ].concat(super)
    end

    def self.run(argv)
      help! 'You cannot run CocoaPods as root.' if Process.uid == 0
      verify_xcode_license_approved!

      super(argv)
    ensure
      UI.print_warnings
    end

    def self.report_error(exception)
      case exception
      when Interrupt
        puts '[!] Cancelled'.red
        Config.instance.verbose? ? raise : exit(1)
      when SystemExit
        raise
      else
        if ENV['COCOA_PODS_ENV'] != 'development'
          puts UI::ErrorReport.report(exception)
          exit 1
        else
          raise exception
        end
      end
    end

    # @todo If a command is run inside another one some settings which where
    #       true might return false.
    #
    # @todo We should probably not even load colored unless needed.
    #
    # @todo Move silent flag to CLAide.
    #
    # @note It is important that the commands don't override the default
    #       settings if their flag is missing (i.e. their value is nil)
    #
    def initialize(argv)
      super
      config.silent = argv.flag?('silent', config.silent)
      config.verbose = self.verbose? unless verbose.nil?
      unless self.ansi_output?
        String.send(:define_method, :colorize) { |string, _| string }
      end
    end

    # Ensure that the master spec repo exists
    #
    # @return [void]
    #
    def ensure_master_spec_repo_exists!
      unless config.sources_manager.master_repo_functional?
        Setup.new(CLAide::ARGV.new([])).run
      end
    end

    #-------------------------------------------------------------------------#

    include Config::Mixin

    private

    # Returns a new {Installer} parametrized from the {Config}.
    #
    # @return [Installer]
    #
    def installer_for_config
      Installer.new(config.sandbox, config.podfile, config.lockfile)
    end

    # Checks that the podfile exists.
    #
    # @raise  If the podfile does not exists.
    #
    # @return [void]
    #
    def verify_podfile_exists!
      unless config.podfile
        raise Informative, "No `Podfile' found in the project directory."
      end
    end

    # Checks that the lockfile exists.
    #
    # @raise  If the lockfile does not exists.
    #
    # @return [void]
    #
    def verify_lockfile_exists!
      unless config.lockfile
        raise Informative, "No `Podfile.lock' found in the project directory, run `pod install'."
      end
    end

    def self.verify_xcode_license_approved!
      if `/usr/bin/xcrun clang 2>&1` =~ /license/ && !$?.success?
        raise Informative, 'You have not agreed to the Xcode license, which ' \
          'you must do to use CocoaPods. Agree to the license by running: ' \
          '`xcodebuild -license`.'
      end
    end
  end
end
