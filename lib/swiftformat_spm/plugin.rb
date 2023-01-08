module Danger
  # This is your plugin class. Any attributes or methods you expose here will
  # be available from within your Dangerfile.
  #
  # To be published on the Danger plugins site, you will need to have
  # the public interface documented. Danger uses [YARD](http://yardoc.org/)
  # for generating documentation from your plugin source, and you can verify
  # by running `danger plugins lint` or `bundle exec rake spec`.
  #
  # You should replace these comments with a public description of your library.
  #
  # @example Ensure people are well warned about merging on Mondays
  #
  #          my_plugin.warn_on_mondays
  #
  # @see  Eric Hsu/danger-swiftformat_spm
  # @tags monday, weekends, time, rattata
  #
  class DangerSwiftformatSpm < Plugin
    # The path to SwiftFormat's executable
    #
    # @return [String]
    attr_accessor :binary_path

    # Additional swiftformat command line arguments
    #
    # @return [String]
    attr_accessor :additional_args

    # Additional message to be appended the report
    #
    # @return [String]
    attr_accessor :additional_message

    # An array of file and directory paths to exclude
    #
    # @return [Array<String>]
    attr_accessor :exclude

    # The project Swift version
    #
    # @return [String]
    attr_accessor :swiftversion

    # Runs swiftformat
    #
    # @param [Boolean] fail_on_error
    #
    # @return [void]
    #
    def check_format(fail_on_error: false)
      # Check if SwiftFormat is installed
      raise "Could not find SwiftFormat executable" unless swiftformat.installed?

      # Find Swift files
      swift_files = find_swift_files

      # Stop processing if there are no swift files
      return if swift_files.empty?

      # Run swiftformat
      results = swiftformat.check_format(swift_files, additional_args, swiftversion)

      # Stop processing if the errors array is empty
      return if results[:errors].empty?

      # Process the errors
      message = "### SwiftFormat found issues:\n\n"
      message << "| File | Rules |\n"
      message << "| ---- | ----- |\n"
      results[:errors].uniq.each do |error|
        message << "| #{error[:file].gsub("#{Dir.pwd}/", '')} | #{error[:rules].join(', ')} |\n"
      end

      unless additional_message.nil?
        message << "\n" << additional_message
      end

      markdown message

      if fail_on_error
        fail "SwiftFormat found issues"
      end
    end

    # Find the files on which SwiftFormat should be run
    #
    # @return [Array<String]
    def find_swift_files
      renamed_files_hash = git.renamed_files.map { |rename| [rename[:before], rename[:after]] }.to_h

      post_rename_modified_files = git.modified_files
        .map { |modified_file| renamed_files_hash[modified_file] || modified_file }

      files = (post_rename_modified_files - git.deleted_files) + git.added_files

      @exclude = %w() if @exclude.nil?

      files
        .select { |file| file.end_with?(".swift") }
        .reject { |file| @exclude.any? { |glob| File.fnmatch(glob, file) } }
        .uniq
        .sort
    end

    # Constructs the SwiftFormat class
    #
    # @return [SwiftFormat]
    def swiftformat
      SwiftFormat.new(binary_path)
    end
  end
end
