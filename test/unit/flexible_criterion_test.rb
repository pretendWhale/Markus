require File.expand_path(File.join(File.dirname(__FILE__), '..', 'test_helper'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'blueprints', 'helper'))
require 'shoulda'

class FlexibleCriterionTest < ActiveSupport::TestCase
  # Class methods

  CSV_STRING = "criterion1,10.0,\"description1, for criterion 1\"\ncriterion2,10.0,\"description2, \"\"with quotes\"\"\"\ncriterion3,1.6,description3!\n"
  UPLOAD_CSV_STRING = "criterion4,10.0,\"description4, \"\"with quotes\"\"\"\n"
  INVALID_CSV_STRING = "criterion3\n"

  context 'A good FlexibleCriterion model' do
    setup do
      FlexibleCriterion.make
    end

    should belong_to :assignment

    # Not yet functional
    # should have_many :marks

    should validate_presence_of :name
    should validate_presence_of :assignment_id
    should validate_presence_of :max

    should validate_uniqueness_of(
                          :name).scoped_to(
                                :assignment_id).with_message(
                                      'Criterion name already used.')

    should validate_numericality_of(
                          :max).with_message(
                                'must be a number greater than 0.0')

    should allow_value(0.1).for(:max)
    should allow_value(1.0).for(:max)
    should allow_value(100.0).for(:max)
    should_not allow_value(0.0).for(:max)
    should_not allow_value(-1.0).for(:max)
    should_not allow_value(-100.0).for(:max)
  end

  context 'With non-existent criteria' do
    setup do
      @assignment = Assignment.make(marking_scheme_type: 'flexible')
    end

    should 'raise en error message on an empty row' do
      e = assert_raise CSVInvalidLineError do
        FlexibleCriterion.create_or_update_from_csv_row([], @assignment)
      end
      assert_equal t('csv.invalid_row.invalid_format'), e.message
    end

    should 'raise an error message on a 1 element row' do
      e = assert_raise CSVInvalidLineError do
        FlexibleCriterion.create_or_update_from_csv_row(%w(name), @assignment)
      end
      assert_equal t('csv.invalid_row.invalid_format'), e.message
    end

    should 'raise an error message on an invalid maximum value' do
      e = assert_raise CSVInvalidLineError do
        FlexibleCriterion.create_or_update_from_csv_row(%w(name max_value), @assignment)
      end
    end

    should 'raise exceptions in case of an unpredicted error' do
      # Capture exception in variable 'e'
      e = assert_raise CSVInvalidLineError do
        # That should fail because the assignment doesn't yet exists (in the DB)
        FlexibleCriterion.create_or_update_from_csv_row(['name', 10], Assignment.new(marking_scheme_type: 'flexible'))
      end
      assert_instance_of CSVInvalidLineError, e
    end

  end

  context 'An assignment, of type flexible criteria' do
    setup do
      @assignment = Assignment.make(marking_scheme_type: 'flexible')
    end


    should 'overwrite criterion from a 2 element row with no description' do
      criterion = FlexibleCriterion.create_or_update_from_csv_row(['name', 10.0], @assignment)
      assert_not_nil criterion
      assert_equal 'name', criterion.name
      assert_equal 10.0, criterion.max
      assert_equal @assignment, criterion.assignment
    end

    should 'overwrite criterion from a 3 elements row that includes a description' do
      criterion = FlexibleCriterion.create_or_update_from_csv_row(['name', 10.0, 'description'], @assignment)
      assert_not_nil criterion
      assert_equal 'name', criterion.name
      assert_equal 10.0, criterion.max
      assert_equal 'description', criterion.description
      assert_equal @assignment, criterion.assignment
    end

    context 'with three flexible criteria' do
      setup do
        FlexibleCriterion.make(assignment: @assignment,
                               name: 'criterion1',
                               description: 'description1, for criterion 1',
                               max: 10)
        FlexibleCriterion.make(assignment: @assignment,
                               name: 'criterion2',
                               description: 'description2, "with quotes"',
                               max: 10,
                               position: 2)
        FlexibleCriterion.make(assignment: @assignment,
                               name: 'criterion3',
                               description: 'description3!',
                               max: 1.6,
                               position: 3)
        @csv_base_row = ['criterion2', '10', 'description2, "with quotes"']
      end

      should 'allow a criterion with the same name to overwrite' do
        assert_nothing_raised do
          criterion = FlexibleCriterion.create_or_update_from_csv_row(@csv_base_row, @assignment)
          assert_equal 'criterion2', criterion.name
          assert_equal 10, criterion.max
          assert_equal 'description2, "with quotes"', criterion.description
          assert_equal 2, criterion.position
        end
      end

    end
  end  # An assignment of type flexible criteria
end
