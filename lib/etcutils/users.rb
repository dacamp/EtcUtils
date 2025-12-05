# frozen_string_literal: true

module EtcUtils
  # UserCollection provides an enumerable interface to system users
  #
  # This class wraps the backend's user iteration methods and provides
  # a Ruby-idiomatic API for accessing user data.
  #
  # @example Iterate all users
  #   EtcUtils.users.each { |user| puts user.name }
  #
  # @example Find a user by name
  #   user = EtcUtils.users.get("root")
  #
  # @example Find a user by UID
  #   user = EtcUtils.users["root"]  # shorthand for get
  #
  # @example Find with block (Enumerable-style)
  #   user = EtcUtils.users.get { |u| u.uid > 1000 }
  #
  class UserCollection
    include Enumerable

    def initialize(backend = nil)
      @backend = backend
    end

    # Iterate all users from the system database
    #
    # @yield [User] each user entry
    # @return [Enumerator] if no block given
    def each(&block)
      return to_enum(:each) unless block_given?

      backend.each_user do |attrs|
        yield User.new(**attrs)
      end
    end

    # Find a user by name, UID, or block
    #
    # When called with an identifier, searches for a user by name (String)
    # or UID (Integer). When called with a block, returns the first user
    # for which the block returns truthy.
    #
    # @param identifier [String, Integer, nil] username or UID (optional if block given)
    # @yield [User] optional block for custom matching
    # @return [User, nil] the found user or nil
    #
    # @example Find by name
    #   EtcUtils.users.get("root")  # => User
    #
    # @example Find by UID
    #   EtcUtils.users.get(0)  # => User
    #
    # @example Find with block
    #   EtcUtils.users.get { |u| u.shell == "/bin/bash" }  # => User
    def get(identifier = nil, &block)
      if block_given?
        # Enumerable-style: find first matching
        find(&block)
      elsif identifier
        # Direct lookup by name or UID
        attrs = backend.find_user(identifier)
        attrs ? User.new(**attrs) : nil
      else
        raise ArgumentError, "get requires an identifier or a block"
      end
    end

    # Find a user by name, UID, or block; raise if not found
    #
    # Same semantics as #get but raises NotFoundError instead of returning nil.
    #
    # @param identifier [String, Integer, nil] username or UID (optional if block given)
    # @yield [User] optional block for custom matching
    # @return [User] the found user
    # @raise [NotFoundError] if no user matches
    #
    # @example
    #   EtcUtils.users.fetch("nonexistent")  # raises NotFoundError
    def fetch(identifier = nil, &block)
      result = get(identifier, &block)
      return result if result

      if block_given?
        raise NotFoundError.new("No user matching block", entity_type: :user)
      else
        raise NotFoundError.new("User not found: #{identifier}", entity_type: :user, identifier: identifier)
      end
    end

    # Shorthand for #get
    #
    # @param identifier [String, Integer] username or UID
    # @return [User, nil] the found user or nil
    #
    # @example
    #   EtcUtils.users["root"]  # => User
    #   EtcUtils.users[0]       # => User
    def [](identifier)
      get(identifier)
    end

    # Check if a user exists
    #
    # @param identifier [String, Integer] username or UID
    # @return [Boolean] true if user exists
    def exists?(identifier)
      !get(identifier).nil?
    end

    # Return all users as an array
    #
    # @return [Array<User>] all users
    def to_a
      each.to_a
    end

    # Return the count of users
    #
    # Note: This iterates all users, which may be slow on systems with many users.
    #
    # @return [Integer] number of users
    def count
      each.count
    end

    private

    def backend
      @backend || Backend::Registry.current
    end
  end
end
