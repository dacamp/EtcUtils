# frozen_string_literal: true

module EtcUtils
  # DryRunResult contains the results of a dry-run write operation
  #
  # When a write method is called with `dry_run: true`, it performs all
  # validation and generates the output that would be written, but does
  # not actually modify any files. This class encapsulates those results.
  #
  # @example Dry run a passwd write
  #   result = EtcUtils.write_passwd(entries, dry_run: true)
  #   puts result.content       # See what would be written
  #   puts result.valid?        # Check if validation passed
  #   puts result.changes       # See what changed
  #
  class DryRunResult
    # @return [String] the content that would be written to the file
    attr_reader :content

    # @return [String] the path that would be written to
    attr_reader :path

    # @return [Array<Hash>] list of changes that would be made
    attr_reader :changes

    # @return [Array<String>] validation warnings (non-fatal issues)
    attr_reader :warnings

    # @return [Array<String>] validation errors (fatal issues)
    attr_reader :errors

    # @return [Hash] additional metadata about the operation
    attr_reader :metadata

    # Create a new DryRunResult
    #
    # @param content [String] the content that would be written
    # @param path [String] the target file path
    # @param changes [Array<Hash>] list of changes
    # @param warnings [Array<String>] validation warnings
    # @param errors [Array<String>] validation errors
    # @param metadata [Hash] additional metadata
    def initialize(content:, path:, changes: [], warnings: [], errors: [], metadata: {})
      @content = content
      @path = path
      @changes = changes.freeze
      @warnings = warnings.freeze
      @errors = errors.freeze
      @metadata = metadata.freeze
    end

    # Check if the dry run passed validation
    #
    # @return [Boolean] true if there are no errors
    def valid?
      errors.empty?
    end

    # Check if there are any warnings
    #
    # @return [Boolean] true if there are warnings
    def warnings?
      !warnings.empty?
    end

    # Count of entries that would be written
    #
    # @return [Integer] number of entries
    def entry_count
      metadata[:entry_count] || 0
    end

    # Summary of changes
    #
    # @return [Hash] counts of added, modified, removed entries
    def change_summary
      {
        added: changes.count { |c| c[:type] == :added },
        modified: changes.count { |c| c[:type] == :modified },
        removed: changes.count { |c| c[:type] == :removed }
      }
    end

    # Human-readable summary of the dry run
    #
    # @return [String] summary description
    def summary
      status = valid? ? "VALID" : "INVALID"
      summary = change_summary
      parts = [
        "[#{status}] Would write #{entry_count} entries to #{path}",
        "Changes: #{summary[:added]} added, #{summary[:modified]} modified, #{summary[:removed]} removed"
      ]
      parts << "Warnings: #{warnings.length}" if warnings?
      parts << "Errors: #{errors.length}" unless valid?
      parts.join("\n")
    end

    # Preview the content with line numbers
    #
    # @param limit [Integer, nil] maximum lines to show (nil for all)
    # @return [String] numbered preview of content
    def preview(limit: nil)
      lines = content.lines
      lines = lines.first(limit) if limit
      lines.each_with_index.map { |line, i| "#{i + 1}: #{line}" }.join
    end

    # Convert to hash representation
    #
    # @return [Hash] all result data
    def to_h
      {
        path: path,
        valid: valid?,
        entry_count: entry_count,
        changes: changes,
        warnings: warnings,
        errors: errors,
        metadata: metadata
      }
    end

    # String representation
    #
    # @return [String]
    def to_s
      summary
    end

    # Detailed inspect output
    #
    # @return [String]
    def inspect
      "#<#{self.class} path=#{path.inspect} valid=#{valid?} entries=#{entry_count} changes=#{changes.length}>"
    end
  end
end
