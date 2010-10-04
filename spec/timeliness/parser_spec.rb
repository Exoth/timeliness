require 'spec_helper'

describe Timeliness::Parser do

  describe "format proc generator" do
    it "should generate proc which outputs date array with values in correct order" do
      generate_method('yyyy-mm-dd').call('2000', '1', '2').should == [2000,1,2,nil,nil,nil,nil]
   end

    it "should generate proc which outputs date array from format with different order" do
      generate_method('dd/mm/yyyy').call('2', '1', '2000').should == [2000,1,2,nil,nil,nil,nil]
    end

    it "should generate proc which outputs time array" do
      generate_method('hh:nn:ss').call('01', '02', '03').should == [nil,nil,nil,1,2,3,nil]
    end

    it "should generate proc which outputs time array with meridian 'pm' adjusted hour" do
      generate_method('hh:nn:ss ampm').call('01', '02', '03', 'pm').should == [nil,nil,nil,13,2,3,nil]
    end

    it "should generate proc which outputs time array with meridian 'am' unadjusted hour" do
      generate_method('hh:nn:ss ampm').call('01', '02', '03', 'am').should == [nil,nil,nil,1,2,3,nil]
    end

    it "should generate proc which outputs time array with microseconds" do
      generate_method('hh:nn:ss.u').call('01', '02', '03', '99').should == [nil,nil,nil,1,2,3,990000]
    end

    it "should generate proc which outputs datetime array with zone offset" do
      generate_method('yyyy-mm-dd hh:nn:ss.u zo').call('2001', '02', '03', '04', '05', '06', '99', '+10:00').should == [2001,2,3,4,5,6,990000,36000]
    end
  end

  describe "validate regexps" do

    describe "for time formats" do
      format_tests = {
        'hh:nn:ss'  => {:pass => ['12:12:12', '01:01:01'], :fail => ['1:12:12', '12:1:12', '12:12:1', '12-12-12']},
        'hh-nn-ss'  => {:pass => ['12-12-12', '01-01-01'], :fail => ['1-12-12', '12-1-12', '12-12-1', '12:12:12']},
        'h:nn'      => {:pass => ['12:12', '1:01'], :fail => ['12:2', '12-12']},
        'h.nn'      => {:pass => ['2.12', '12.12'], :fail => ['2.1', '12:12']},
        'h nn'      => {:pass => ['2 12', '12 12'], :fail => ['2 1', '2.12', '12:12']},
        'h-nn'      => {:pass => ['2-12', '12-12'], :fail => ['2-1', '2.12', '12:12']},
        'h:nn_ampm' => {:pass => ['2:12am', '2:12 pm', '2:12 AM', '2:12PM'], :fail => ['1:2am', '1:12  pm', '2.12am']},
        'h.nn_ampm' => {:pass => ['2.12am', '2.12 pm'], :fail => ['1:2am', '1:12  pm', '2:12am']},
        'h nn_ampm' => {:pass => ['2 12am', '2 12 pm'], :fail => ['1 2am', '1 12  pm', '2:12am']},
        'h-nn_ampm' => {:pass => ['2-12am', '2-12 pm'], :fail => ['1-2am', '1-12  pm', '2:12am']},
        'h_ampm'    => {:pass => ['2am', '2 am', '12 pm'], :fail => ['1.am', '12  pm', '2:12am']},
      }
      format_tests.each do |format, values|
        it "should correctly validate times in format '#{format}'" do
          regexp = generate_regexp(format)
          values[:pass].each {|value| value.should match(regexp)}
          values[:fail].each {|value| value.should_not match(regexp)}
        end
      end
    end

    describe "for date formats" do
      format_tests = {
        'yyyy/mm/dd' => {:pass => ['2000/02/01'], :fail => ['2000\02\01', '2000/2/1', '00/02/01']},
        'yyyy-mm-dd' => {:pass => ['2000-02-01'], :fail => ['2000\02\01', '2000-2-1', '00-02-01']},
        'yyyy.mm.dd' => {:pass => ['2000.02.01'], :fail => ['2000\02\01', '2000.2.1', '00.02.01']},
        'm/d/yy'     => {:pass => ['2/1/01', '02/01/00', '02/01/2000'], :fail => ['2/1/0', '2.1.01']},
        'd/m/yy'     => {:pass => ['1/2/01', '01/02/00', '01/02/2000'], :fail => ['1/2/0', '1.2.01']},
        'm\d\yy'     => {:pass => ['2\1\01', '2\01\00', '02\01\2000'], :fail => ['2\1\0', '2/1/01']},
        'd\m\yy'     => {:pass => ['1\2\01', '1\02\00', '01\02\2000'], :fail => ['1\2\0', '1/2/01']},
        'd-m-yy'     => {:pass => ['1-2-01', '1-02-00', '01-02-2000'], :fail => ['1-2-0', '1/2/01']},
        'd.m.yy'     => {:pass => ['1.2.01', '1.02.00', '01.02.2000'], :fail => ['1.2.0', '1/2/01']},
        'd mmm yy'   => {:pass => ['1 Feb 00', '1 Feb 2000', '1 February 00', '01 February 2000'],
                          :fail => ['1 Fe 00', 'Feb 1 2000', '1 Feb 0']}
      }
      format_tests.each do |format, values|
        it "should correctly validate dates in format '#{format}'" do
          regexp = generate_regexp(format)
          values[:pass].each {|value| value.should match(regexp)}
          values[:fail].each {|value| value.should_not match(regexp)}
        end
      end
    end

    describe "for datetime formats" do
      format_tests = {
        'ddd mmm d hh:nn:ss zo yyyy'  => {:pass => ['Sat Jul 19 12:00:00 +1000 2008'], :fail => []},
        'yyyy-mm-ddThh:nn:ss(?:Z|zo)' => {:pass => ['2008-07-19T12:00:00+10:00', '2008-07-19T12:00:00Z'], :fail => ['2008-07-19T12:00:00Z+10:00']},
      }
      format_tests.each do |format, values|
        it "should correctly validate datetimes in format '#{format}'" do
          regexp = generate_regexp(format)
          values[:pass].each {|value| value.should match(regexp)}
          values[:fail].each {|value| value.should_not match(regexp)}
        end
      end
    end
  end

  # describe "parse" do
  #   it "should ignore time when extracting date and strict is false" do
  #     time_array = formats.parse('2000-02-01 12:13', :date)
  #     time_array.should == [2000,2,1,nil,nil,nil,nil]
  #   end

  #   it "should ignore time when extracting date from format with trailing year and strict is false" do
  #     time_array = formats.parse('01-02-2000 12:13', :date)
  #     time_array.should == [2000,2,1,nil,nil,nil,nil]
  #   end

  #   it "should ignore date when extracting time and strict is false" do
  #     time_array = formats.parse('2000-02-01 12:13', :time)
  #     time_array.should == [2000,1,1,12,13,nil,nil]
  #   end

  # end

  describe "_parse" do

    it "should return time array from date string" do
      time_array = formats._parse('12:13:14', :time, :strict => true)
      time_array.should == [2000,1,1,12,13,14,nil]
    end

    it "should return nil if time hour is out of range for AM meridian" do
      time_array = formats._parse('13:14 am', :time, :strict => true)
      time_array.should == nil
      time_array = formats._parse('00:14 am', :time, :strict => true)
      time_array.should == nil
    end

    it "should return date array from time string" do
      time_array = formats._parse('2000-02-01', :date, :strict => true)
      time_array.should == [2000,2,1,nil,nil,nil,nil]
    end

    it "should return datetime array from string value" do
      time_array = formats._parse('2000-02-01 12:13:14', :datetime, :strict => true)
      time_array.should == [2000,2,1,12,13,14,nil]
    end

    it "should parse date string when type is datetime" do
      time_array = formats._parse('2000-02-01', :datetime, :strict => false)
      time_array.should == [2000,2,1,nil,nil,nil,nil]
    end

    it "should return zone offset when :include_offset option is true" do
      time_array = formats._parse('2000-02-01T12:13:14-10:30', :datetime, :include_offset => true)
      time_array.should == [2000,2,1,12,13,14,nil,-37800]
    end

    # context "with format option" do
    #   it "should return values if string matches specified format" do
    #     time_array = formats._parse('2000-02-01 12:13:14', :datetime, :format => 'yyyy-mm-dd hh:nn:ss')
    #     time_array.should == [2000,2,1,12,13,14,nil]
    #   end

    #   it "should return nil if string does not match specified format" do
    #     time_array = formats._parse('2000-02-01 12:13', :datetime, :format => 'yyyy-mm-dd hh:nn:ss')
    #     time_array.should be_nil
    #   end
    # end

    context "date with ambiguous year" do
      it "should return year in current century if year below threshold" do
        time_array = formats._parse('01-02-29', :date)
        time_array.should == [2029,2,1,nil,nil,nil,nil]
      end

      it "should return year in last century if year at or above threshold" do
        time_array = formats._parse('01-02-30', :date)
        time_array.should == [1930,2,1,nil,nil,nil,nil]
      end

      it "should allow custom threshold" do
        default = Timeliness.ambiguous_year_threshold
        Timeliness.ambiguous_year_threshold = 40
        time_array = formats._parse('01-02-39', :date)
        time_array.should == [2039,2,1,nil,nil,nil,nil]
        time_array = formats._parse('01-02-40', :date)
        time_array.should == [1940,2,1,nil,nil,nil,nil]
        Timeliness.ambiguous_year_threshold = default
      end
    end
  end

  describe "parse" do
    it "should return time object for valid time string" do
      parse("2000-01-01 12:13:14", :datetime).should be_kind_of(Time)
    end
    
    it "should return nil for time string with invalid date part" do
      parse("2000-02-30 12:13:14", :datetime).should be_nil
    end
    
    it "should return nil for time string with invalid time part" do
      parse("2000-02-01 25:13:14", :datetime).should be_nil      
    end
    
    it "should return Time object when passed a Time object" do
      parse(Time.now, :datetime).should be_kind_of(Time)
    end
        
    it "should convert time string into current timezone" do
      Time.zone = 'Melbourne'
      time = parse("2000-01-01 12:13:14", :datetime, :timezone_aware => true)
      Time.zone.utc_offset.should == 10.hours
    end

    it "should return nil for invalid date string" do
      parse("2000-02-30", :date).should be_nil      
    end
        
    def parse(*args)
      Timeliness::Parser.parse(*args)
    end
  end

  describe "make_time" do
    it "should create time using current timezone" do
      time = Timeliness::Parser.make_time([2000,1,1,12,0,0])
      time.zone.should == "UTC"
    end

    it "should create time using current timezone" do
      Time.zone = 'Melbourne'
      time = Timeliness::Parser.make_time([2000,1,1,12,0,0], true)
      time.zone.should == "EST"
    end
  end

  describe "removing formats" do
    it "should remove format from format array" do
      formats.remove_formats(:time, 'h.nn_ampm')
      formats.time_formats.should_not include("h o'clock")
    end

    it "should not match time after its format is removed" do
      validate('2.12am', :time).should be_true
      formats.remove_formats(:time, 'h.nn_ampm')
      validate('2.12am', :time).should be_false
    end

    it "should raise error if format does not exist" do
      lambda { formats.remove_formats(:time, "ss:hh:nn") }.should raise_error()
    end

    after do
      formats.time_formats << 'h.nn_ampm'
      formats.compile_format_expressions
    end
  end

  describe "adding formats" do
    before do
      formats.compile_format_expressions
    end

    it "should add format to format array" do
      formats.add_formats(:time, "h o'clock")
      formats.time_formats.should include("h o'clock")
    end

    it "should match new format after its added" do
      validate("12 o'clock", :time).should be_false
      formats.add_formats(:time, "h o'clock")
      validate("12 o'clock", :time).should be_true
    end

    it "should add format before specified format and be higher precedence" do
      formats.add_formats(:time, "ss:hh:nn", :before => 'hh:nn:ss')
      validate("59:23:58", :time).should be_true
      time_array = formats._parse('59:23:58', :time)
      time_array.should == [2000,1,1,23,58,59,nil]
    end

    it "should raise error if format exists" do
      lambda { formats.add_formats(:time, "hh:nn:ss") }.should raise_error()
    end

    it "should raise error if format exists" do
      lambda { formats.add_formats(:time, "ss:hh:nn", :before => 'nn:hh:ss') }.should raise_error()
    end

    after do
      formats.time_formats.delete("h o'clock")
      formats.time_formats.delete("ss:hh:nn")
      # reload class instead
    end
  end

  describe "removing US formats" do
    it "should validate a date as European format when US formats removed" do
      time_array = formats._parse('01/02/2000', :date)
      time_array.should == [2000,1,2,nil,nil,nil,nil]
      formats.remove_us_formats
      time_array = formats._parse('01/02/2000', :date)
      time_array.should == [2000,2,1,nil,nil,nil,nil]
    end

    after do
      # reload class
    end
  end


  def formats
    Timeliness::Parser
  end

  def validate(time_string, type)
    !(formats.send("#{type}_regexp") =~ time_string).nil?
  end

  def generate_regexp(format)
    # wrap in line start and end anchors to emulate extract values method
    /\A#{formats.send(:generate_format_regexp, format).last}\Z/
  end

  def generate_regexp_str(format)
    formats.send(:generate_format_regexp, format).last.inspect
  end

  def generate_method(format)
    formats.send(:generate_format_regexp, format)
    Timeliness::Parser.method(:"format_#{format}")
  end

  def delete_format(type, format)
    formats.send("#{type}_formats").delete(format)
  end
end
