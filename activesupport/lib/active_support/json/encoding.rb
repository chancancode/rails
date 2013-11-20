require 'active_support/core_ext/object/json'
require 'active_support/core_ext/module/delegation'

module ActiveSupport
  class << self
    delegate :use_standard_json_time_format, :use_standard_json_time_format=,
      :escape_html_entities_in_json, :escape_html_entities_in_json=,
      :encode_big_decimal_as_string, :encode_big_decimal_as_string=,
      :json_encoder, :json_encoder=,
      :to => :'ActiveSupport::JSON::Encoding'
  end

  module JSON
    # Dumps objects in JSON (JavaScript Object Notation).
    # See www.json.org for more info.
    #
    #   ActiveSupport::JSON.encode({ team: 'rails', players: '36' })
    #   # => "{\"team\":\"rails\",\"players\":\"36\"}"
    def self.encode(value, options = nil)
      Encoding.json_encoder.new(options).encode(value)
    end

    module Encoding #:nodoc:
      class JSONGemEncoder
        attr_reader :options

        def initialize(options = nil)
          @options = options || {}
        end

        def encode(value)
          stringify jsonify value.as_json(options.dup)
        end

        private
          class EscapedString < String
            def to_json(*)
              Encoding.escape(super)
            end
          end

          def jsonify(value)
            if value.is_a?(Hash)
              Hash[value.map { |k, v| [jsonify(k), jsonify(v)] }]
            elsif value.is_a?(Array)
              value.map { |v| jsonify(v) }
            elsif value.is_a?(String)
              EscapedString.new(value)
            elsif value.is_a?(Numeric)
              value
            elsif value == true
              true
            elsif value == false
              false
            elsif value == nil
              nil
            else
              jsonify value.as_json
            end
          end

          def stringify(jsonified)
            ::JSON.generate(jsonified, quirks_mode: true, max_nesting: false)
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

        attr_accessor :escape_regex
        attr_reader :escape_html_entities_in_json
        attr_accessor :json_encoder

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
      self.json_encoder = JSONGemEncoder
    end
  end
end
