module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Json < Type::Value # :nodoc:
          include Type::Mutable

          def type
            :json
          end

          def type_cast_from_database(value)
            if value.is_a?(::String)
              ::ActiveSupport::JSON.decode(value)
            else
              super
            end
          end

          def type_cast_for_database(value)
            if value.is_a?(::Array) || value.is_a?(::Hash)
              ::ActiveSupport::JSON.encode(value)
            else
              super
            end
          end

          def accessor
            ActiveRecord::Store::StringKeyedHashAccessor
          end
        end

        class Jsonb < Json # :nodoc:
          def type
            :jsonb
          end

          def changed_in_place?(raw_old_value, new_value)
            # Postgres does not preserve the insignificat whitespaces when
            # roundtripping jsonb columns. This causes some false positives for
            # the comparision here. Therefore, we need to parse and re-dump the
            # raw value here to ensure the (insignificant) whitespaces are
            # consitent with our encoder's output.
            raw_old_value = type_cast_for_database(type_cast_from_database(raw_old_value))
            super
          end
        end
      end
    end
  end
end
