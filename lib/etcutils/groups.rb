# frozen_string_literal: true

module EtcUtils
  # GroupCollection provides an enumerable interface to system groups
  #
  # This class wraps the backend's group iteration methods and provides
  # a Ruby-idiomatic API for accessing group data.
  #
  # @example Iterate all groups
  #   EtcUtils.groups.each { |group| puts group.name }
  #
  # @example Find a group by name
  #   group = EtcUtils.groups.get("wheel")
  #
  # @example Find a group by GID
  #   group = EtcUtils.groups[0]  # shorthand for get
  #
  # @example Find with block (Enumerable-style)
  #   group = EtcUtils.groups.get { |g| g.members.include?("alice") }
  #
  class GroupCollection
    include Enumerable

    def initialize(backend = nil)
      @backend = backend
    end

    # Iterate all groups from the system database
    #
    # @yield [Group] each group entry
    # @return [Enumerator] if no block given
    def each(&block)
      return to_enum(:each) unless block_given?

      backend.each_group do |attrs|
        yield Group.new(**attrs)
      end
    end

    # Find a group by name, GID, or block
    #
    # When called with an identifier, searches for a group by name (String)
    # or GID (Integer). When called with a block, returns the first group
    # for which the block returns truthy.
    #
    # @param identifier [String, Integer, nil] group name or GID (optional if block given)
    # @yield [Group] optional block for custom matching
    # @return [Group, nil] the found group or nil
    #
    # @example Find by name
    #   EtcUtils.groups.get("wheel")  # => Group
    #
    # @example Find by GID
    #   EtcUtils.groups.get(0)  # => Group
    #
    # @example Find with block
    #   EtcUtils.groups.get { |g| g.members.length > 5 }  # => Group
    def get(identifier = nil, &block)
      if block_given?
        # Enumerable-style: find first matching
        find(&block)
      elsif identifier
        # Direct lookup by name or GID
        attrs = backend.find_group(identifier)
        attrs ? Group.new(**attrs) : nil
      else
        raise ArgumentError, "get requires an identifier or a block"
      end
    end

    # Find a group by name, GID, or block; raise if not found
    #
    # Same semantics as #get but raises NotFoundError instead of returning nil.
    #
    # @param identifier [String, Integer, nil] group name or GID (optional if block given)
    # @yield [Group] optional block for custom matching
    # @return [Group] the found group
    # @raise [NotFoundError] if no group matches
    #
    # @example
    #   EtcUtils.groups.fetch("nonexistent")  # raises NotFoundError
    def fetch(identifier = nil, &block)
      result = get(identifier, &block)
      return result if result

      if block_given?
        raise NotFoundError.new("No group matching block", entity_type: :group)
      else
        raise NotFoundError.new("Group not found: #{identifier}", entity_type: :group, identifier: identifier)
      end
    end

    # Shorthand for #get
    #
    # @param identifier [String, Integer] group name or GID
    # @return [Group, nil] the found group or nil
    #
    # @example
    #   EtcUtils.groups["wheel"]  # => Group
    #   EtcUtils.groups[0]        # => Group
    def [](identifier)
      get(identifier)
    end

    # Check if a group exists
    #
    # @param identifier [String, Integer] group name or GID
    # @return [Boolean] true if group exists
    def exists?(identifier)
      !get(identifier).nil?
    end

    # Return all groups as an array
    #
    # @return [Array<Group>] all groups
    def to_a
      each.to_a
    end

    # Return the count of groups
    #
    # Note: This iterates all groups, which may be slow on systems with many groups.
    #
    # @return [Integer] number of groups
    def count
      each.count
    end

    private

    def backend
      @backend || Backend::Registry.current
    end
  end
end
