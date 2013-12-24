require 'cases/helper'
require 'models/book'

class EnumTest < ActiveRecord::TestCase
  fixtures :books

  setup do
    @book = books(:awdr)
  end

  test "query state by predicate" do
    assert @book.proposed?
    assert_not @book.written?
    assert_not @book.published?

    assert @book.unread?
  end

  test "query state with strings" do
    assert_equal "proposed", @book.status
    assert_equal "unread", @book.read_status
  end

  test "find via scope" do
    assert_equal @book, Book.proposed.first
    assert_equal @book, Book.unread.first
  end

  test "update by declaration" do
    @book.written!
    assert @book.written?
  end

  test "update by setter" do
    @book.update! status: :written
    assert @book.written?
  end

  test "enum methods are overwritable" do
    assert_equal "do publish work...", @book.published!
    assert @book.published?
  end

  test "direct assignment" do
    @book.status = :written
    assert @book.written?
  end

  test "assign string value" do
    @book.status = "written"
    assert @book.written?
  end

  test "assign non existing value raises an error" do
    e = assert_raises(ArgumentError) do
      @book.status = :unknown
    end
    assert_equal "'unknown' is not a valid status", e.message
  end

  test "assign nil value" do
    @book.status = nil
    assert @book.status.nil?
  end

  test "assign empty string value" do
    @book.status = ''
    assert @book.status.nil?
  end

  test "assign long empty string value" do
    @book.status = '   '
    assert @book.status.nil?
  end

  test "constant to access the mapping" do
    assert_equal 0, Book::STATUS[:proposed]
    assert_equal 1, Book::STATUS["written"]
    assert_equal 2, Book::STATUS[:published]
  end

  test "first_or_initialize with enums' scopes" do
    class Issue < ActiveRecord::Base
      enum status: [:open, :closed]
    end

    assert Issue.open.empty?
    assert Issue.open.first_or_initialize
  end

  test "reserved enum values" do
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = "books"
      enum status: [:proposed, :written, :published]
    end

    # Test against the following categories of conflicts
    conflicts = [
      :new,      # generates a scope that conflicts with a class method
      :proposed, # same value as an existing enum
      :valid,    # generates #valid?, which conflicts with an AR method
      :save      # generates #save!, which conflicts with an AR method
    ]

    conflicts.each do |value|
      assert_raises(ArgumentError) do
        klass.class_eval { enum read_status: [value] }
      end
    end
  end

  test "overriding enum method does not raise" do
    assert_nothing_raised do
      klass = Class.new(ActiveRecord::Base) do
        self.table_name = "books"

        def published!
          super
          "do publish work..."
        end

        enum status: [:proposed, :written, :published]
      end
    end
  end
end
