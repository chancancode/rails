require 'active_support/core_ext/object/json'
require 'active_support/core_ext/module/delegation'
require 'json'

module ActiveSupport
  class << self
    delegate :use_standard_json_time_format, :use_standard_json_time_format=,
      :escape_html_entities_in_json, :escape_html_entities_in_json=,
      :encode_big_decimal_as_string, :encode_big_decimal_as_string=,
      :default_json_encoder, :default_json_encoder=,
      :to => :'ActiveSupport::JSON::Encoding'
  end

  module JSON
    # Dumps objects in JSON (JavaScript Object Notation).
    # See www.json.org for more info.
    #
    #   ActiveSupport::JSON.encode({ team: 'rails', players: '36' })
    #   # => "{\"team\":\"rails\",\"players\":\"36\"}"
    def self.encode(value, options = nil)
      Encoding.default_json_encoder.new(options).encode(value)
    end

    module Encoding #:nodoc:
      class JsonGemEncoder
        attr_reader :options

        def initialize(options = nil)
          @options = options || {}
        end

        def encode(value)
          Encoding.escape generate jsonify(value)
        end
 
        private
          # Prepare the value before passing it to the backend (e.g. calling as_json)
          def jsonify(value)
            unless short_circuit?
              # First call as_json with options
              if value.respond_to?(:as_json)
                value = value.as_json(options.dup)
              end

              # Then call as_json without options again to jsonify the value returned by the user
              if value.respond_to?(:as_json)
                value = value.as_json
              end
            end

            value
          end

          # Generate a json string from value by passing it to the backend
          def generate(value)
            if short_circuit?
              if value.is_a?(BigDecimal)
                value.to_s
              else
                value.__to_json__(options)
              end
            else
              ::JSON.generate(value, quirks_mode: true, max_nesting: false)
            end
          end

          # JSON gem doesn't know how to encode this value and it tried to call value#to_json
          def short_circuit?
            @options.is_a?(::JSON::State)
          end
      end

      ESCAPED_CHARS = {
        "\u2028" => '\u2028',
        "\u2029" => '\u2029',
        '>'      => '\u003E',
        '<'      => '\u003C',
        '&'      => '\u0026',
        }

      class << self
        # If true, use ISO 8601 format for dates and times. Otherwise, fall back
        # to the Active Support legacy format.
        attr_accessor :use_standard_json_time_format

        # If false, serializes BigDecimal objects as numeric instead of wrapping
        # them in a string.
        attr_accessor :encode_big_decimal_as_string

        attr_accessor :escape_regex
        attr_reader :escape_html_entities_in_json

        attr_accessor :default_json_encoder

        def escape_html_entities_in_json=(value)
          self.escape_regex = \
            if @escape_html_entities_in_json = value
              /[\u2028\u2029><&]/u
            else
              /[\u2028\u2029]/u
            end
        end

        def escape(string)
          string.gsub(escape_regex) { |s| ESCAPED_CHARS[s] }
        end

        # Deprecate CircularReferenceError
        def const_missing(name)
          if name == :CircularReferenceError
            message = "The JSON encoder in Rails 4.1 no longer offers protection from circular references. " \
                      "You are seeing this warning because you are rescuing from (or otherwise referencing) " \
                      "ActiveSupport::Encoding::CircularReferenceError. In the future, this error will be " \
                      "removed from Rails. You should remove these rescue blocks from your code and ensure " \
                      "that your data structures are free of circular references so they can be properly " \
                      "serialized into JSON.\n\n" \
                      "For example, the following Hash contains a circular reference to itself:\n" \
                      "   h = {}\n" \
                      "   h['circular'] = h\n" \
                      "In this case, calling h.to_json would not work properly."

            ActiveSupport::Deprecation.warn message

            SystemStackError
          else
            super
          end
        end
      end

      self.use_standard_json_time_format = true
      self.escape_html_entities_in_json  = true
      self.encode_big_decimal_as_string  = true
      self.default_json_encoder = JsonGemEncoder
    end
  end
end
