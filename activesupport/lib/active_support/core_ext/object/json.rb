# Hack to load json gem first so we can overwrite its to_json.
require 'json'
require 'bigdecimal'
require 'active_support/core_ext/big_decimal/conversions' # for #to_s
require 'active_support/core_ext/hash/except'
require 'active_support/core_ext/hash/slice'
require 'active_support/core_ext/object/instance_variables'
require 'time'
require 'active_support/core_ext/time/conversions'
require 'active_support/core_ext/date_time/conversions'
require 'active_support/core_ext/date/conversions'

# The JSON gem adds a few modules to Ruby core classes containing :to_json definition, overwriting
# their default behavior. That said, we need to define the basic to_json method in all of them,
# otherwise they will always use to_json gem implementation, which is backwards incompatible in
# several cases (for instance, the JSON implementation for Hash does not work) with inheritance
# and consequently classes as ActiveSupport::OrderedHash cannot be serialized to json.
[Object, Array, FalseClass, Float, Hash, Integer, NilClass, String, TrueClass].each do |klass|
  klass.class_eval do
    # Preserve the to_json added by JSON gem
    alias_method :__to_json__, :to_json if method_defined? :to_json

    # Dumps object in JSON (JavaScript Object Notation). See www.json.org for more info.
    def to_json(options = nil)
      ActiveSupport::JSON.encode(self, options)
    end
  end
end

class Object
  def as_json(options = nil) #:nodoc:
    if respond_to?(:to_hash)
      to_hash.as_json(options)
    else
      instance_values.as_json(options)
    end
  end
end

class Struct #:nodoc:
  def as_json(options = nil)
    Hash[members.zip(values)].as_json(options)
  end
end

class TrueClass
  def as_json(options = nil) #:nodoc:
    self
  end
end

class FalseClass
  def as_json(options = nil) #:nodoc:
    self
  end
end

class NilClass
  def as_json(options = nil) #:nodoc:
    self
  end
end

class String
  def as_json(options = nil) #:nodoc:
    self
  end
end

class Symbol
  def as_json(options = nil) #:nodoc:
    to_s
  end
end

class Numeric
  def as_json(options = nil) #:nodoc:
    self
  end
end

class Float
  # Encoding Infinity or NaN to JSON should return "null". The default returns
  # "Infinity" or "NaN" which are not valid JSON.
  def as_json(options = nil) #:nodoc:
    finite? ? self : nil
  end
end

class BigDecimal
  # A BigDecimal would be naturally represented as a JSON number. Most libraries,
  # however, parse non-integer JSON numbers directly as floats. Clients using
  # those libraries would get in general a wrong number and no way to recover
  # other than manually inspecting the string with the JSON code itself.
  #
  # That's why a JSON string is returned. The JSON literal is not numeric, but
  # if the other end knows by contract that the data is supposed to be a
  # BigDecimal, it still has the chance to post-process the string and get the
  # real value.
  #
  # Use <tt>ActiveSupport.use_standard_json_big_decimal_format = true</tt> to
  # override this behavior.
  def as_json(options = nil) #:nodoc:
    if finite?
      ActiveSupport.encode_big_decimal_as_string ? to_s : self
    else
      nil
    end
  end
end

class Regexp
  def as_json(options = nil) #:nodoc:
    to_s
  end
end

module Enumerable
  def as_json(options = nil) #:nodoc:
    to_a.as_json(options)
  end
end

class Range
  def as_json(options = nil) #:nodoc:
    to_s
  end
end

class Array
  def as_json(options = nil) #:nodoc:
    map { |v| v.as_json(options && options.dup) }
  end
end

class Hash
  def as_json(options = nil) #:nodoc:
    # create a subset of the hash by applying :only or :except
    subset = if options
      if attrs = options[:only]
        slice(*Array(attrs))
      elsif attrs = options[:except]
        except(*Array(attrs))
      else
        self
      end
    else
      self
    end

    Hash[subset.map { |k, v| [k.to_s, v.as_json(options && options.dup)] }]
  end
end

class Time
  def as_json(options = nil) #:nodoc:
    if ActiveSupport.use_standard_json_time_format
      xmlschema
    else
      %(#{strftime("%Y/%m/%d %H:%M:%S")} #{formatted_offset(false)})
    end
  end
end

class Date
  def as_json(options = nil) #:nodoc:
    if ActiveSupport.use_standard_json_time_format
      strftime("%Y-%m-%d")
    else
      strftime("%Y/%m/%d")
    end
  end
end

class DateTime
  def as_json(options = nil) #:nodoc:
    if ActiveSupport.use_standard_json_time_format
      xmlschema
    else
      strftime('%Y/%m/%d %H:%M:%S %z')
    end
  end
end

class Process::Status
  def as_json(options = nil)
    { :exitstatus => exitstatus, :pid => pid }
  end
end
