module Timeliness
  # A date and time parsing library which allows you to add custom formats using
  # simple predefined tokens. This makes it much easier to catalogue and customize
  # the formats rather than dealing directly with regular expressions.
  #
  # Formats can be added or removed to customize the set of valid date or time
  # string values.
  #
  module Parser
    extend Helpers

    mattr_reader :time_expressions, :date_expressions, :datetime_expressions

    # Format tokens:
    #       y = year
    #       m = month
    #       d = day
    #       h = hour
    #       n = minute
    #       s = second
    #       u = micro-seconds
    #    ampm = meridian (am or pm) with or without dots (e.g. am, a.m, or a.m.)
    #       _ = optional space
    #      tz = Timezone abbreviation (e.g. UTC, GMT, PST, EST)
    #      zo = Timezone offset (e.g. +10:00, -08:00, +1000)
    #
    #   All other characters are considered literal. You can embed regexp in the
    #   format but no guarantees that it will remain intact. If you avoid the use
    #   of any token characters and regexp dots or backslashes as special characters
    #   in the regexp, it may well work as expected. For special characters use
    #   POSIX character classes for safety.
    #
    # Repeating tokens:
    #       x = 1 or 2 digits for unit (e.g. 'h' means an hour can be '9' or '09')
    #      xx = 2 digits exactly for unit (e.g. 'hh' means an hour can only be '09')
    #
    # Special Cases:
    #      yy = 2 or 4 digit year
    #    yyyy = exactly 4 digit year
    #     mmm = month long name (e.g. 'Jul' or 'July')
    #     ddd = Day name of 3 to 9 letters (e.g. Wed or Wednesday)
    #       u = microseconds matches 1 to 6 digits
    #
    #   Any other invalid combination of repeating tokens will be swallowed up
    #   by the next lowest length valid repeating token (e.g. yyy will be
    #   replaced with yy)

    mattr_accessor :time_formats
    @@time_formats = [
      'hh:nn:ss',
      'hh-nn-ss',
      'h:nn',
      'h.nn',
      'h nn',
      'h-nn',
      'h:nn_ampm',
      'h.nn_ampm',
      'h nn_ampm',
      'h-nn_ampm',
      'h_ampm'
    ]

    mattr_accessor :date_formats
    @@date_formats = [
      'yyyy-mm-dd',
      'yyyy/mm/dd',
      'yyyy.mm.dd',
      'm/d/yy',
      'd/m/yy',
      'm\d\yy',
      'd\m\yy',
      'd-m-yy',
      'dd-mm-yyyy',
      'd.m.yy',
      'd mmm yy'
    ]

    mattr_accessor :datetime_formats
    @@datetime_formats = [
      'yyyy-mm-dd hh:nn:ss',
      'yyyy-mm-dd h:nn',
      'yyyy-mm-dd h:nn_ampm',
      'yyyy-mm-dd hh:nn:ss.u',
      'm/d/yy h:nn:ss',
      'm/d/yy h:nn_ampm',
      'm/d/yy h:nn',
      'd/m/yy hh:nn:ss',
      'd/m/yy h:nn_ampm',
      'd/m/yy h:nn',
      'dd-mm-yyyy hh:nn:ss',
      'dd-mm-yyyy h:nn_ampm',
      'dd-mm-yyyy h:nn',
      'ddd, dd mmm yyyy hh:nn:ss tz', # RFC 822
      'ddd, dd mmm yyyy hh:nn:ss zo', # RFC 822
      'ddd mmm d hh:nn:ss zo yyyy', # Ruby time string
      'yyyy-mm-ddThh:nn:ssZ', # iso 8601 without zone offset
      'yyyy-mm-ddThh:nn:sszo' # iso 8601 with zone offset
    ]

    # All tokens available for format construction. The token array is made of
    # regexp and key for format component mapping, if any.
    #
    mattr_accessor :format_tokens
    @@format_tokens = {
      'ddd'  => [ '\w{3,9}' ],
      'dd'   => [ '\d{2}',   :day ],
      'd'    => [ '\d{1,2}', :day ],
      'mmm'  => [ '\w{3,9}', :month ],
      'mm'   => [ '\d{2}',   :month ],
      'm'    => [ '\d{1,2}', :month ],
      'yyyy' => [ '\d{4}',   :year ],
      'yy'   => [ '\d{4}|\d{2}', :year ],
      'hh'   => [ '\d{2}',   :hour ],
      'h'    => [ '\d{1,2}', :hour ],
      'nn'   => [ '\d{2}',   :min ],
      'n'    => [ '\d{1,2}', :min ],
      'ss'   => [ '\d{2}',   :sec ],
      's'    => [ '\d{1,2}', :sec ],
      'u'    => [ '\d{1,6}', :usec ],
      'ampm' => [ '[aApP]\.?[mM]\.?', :meridian ],
      'zo'   => [ '[+-]\d{2}:?\d{2}', :offset ],
      'tz'   => [ '[A-Z]{1,4}' ],
      '_'    => [ '\s?' ]
    }

    # Component argument values will be passed to the format method if matched in
    # the time string. The key should match the key defined in the format tokens.
    #
    # The array consists of the position the value should be inserted in
    # the time array, and the code to place in the time array.
    #
    # If the position is nil, then the value won't be put in the time array. If the
    # code slot is empty, then just the raw value is used.
    #
    mattr_accessor :format_components
    @@format_components = {
      :year     => [ 0, 'unambiguous_year(year)'],
      :month    => [ 1, 'month_index(month)'],
      :day      => [ 2 ],
      :hour     => [ 3, 'full_hour(hour, meridian ||= nil)'],
      :min      => [ 4 ],
      :sec      => [ 5 ],
      :usec     => [ 6, 'microseconds(usec)'],
      :offset   => [ 7, 'offset_in_seconds(offset)'],
      :meridian => [ nil ]
    }

    @@type_wrapper = {
      :date     => [/\A/, nil],
      :time     => [nil , /\Z/],
      :datetime => [/\A/, /\Z/]
    }

    mattr_accessor :date_regexp, :time_regexp, :datetime_regexp
    class << self

      def compile_format_expressions
        @@time_expressions, @@time_regexp = compile_formats(@@time_formats)
        @@date_expressions, @@date_regexp = compile_formats(@@date_formats)
        @@datetime_expressions, @@datetime_regexp = compile_formats(@@datetime_formats)
      end

      def parse(value, type, options={})
        return value unless value.is_a?(String)

        time_array = _parse(value, type, options)
        return nil if time_array.nil?

        time_array[3..7] = nil if type == :date
        make_time(time_array[0..7], options[:timezone_aware])
      end

      def make_time(time_array, timezone_aware=false)
        # Enforce strict date part validity which Time class does not
        return nil unless Date.valid_civil?(*time_array[0..2])

        if timezone_aware
          Time.zone.local(*time_array)
        else
          Time.time_with_datetime_fallback(Timeliness.default_timezone, *time_array)
        end
      rescue ArgumentError, TypeError
        nil
      end

      def _parse(string, type, options={})
        options.reverse_merge!(:strict => true)

        md  = nil
        set = expression_set(type, string)
        expressions, regexp = set.find {|expressions, regexp| md = regexp.match(string) }

        if md
          captures = md.captures[1..-1]
          last     = options[:include_offset] ? 8 : 7
          format ||= begin
            index = captures.index(string)
            expressions.rassoc(index).first
          end
          values     = captures[(index+1)..(index+1+last)].compact
          time_array = send(:"format_#{format}", *values)
          time_array[0..2] = Timeliness.dummy_date_for_time_type if type == :time
          time_array
        end
      rescue => e
        nil
      end

      # Delete formats of specified type. Error raised if format not found.
      #
      def remove_formats(type, *remove_formats)
        remove_formats.each do |format|
          unless self.send("#{type}_formats").delete(format)
            raise "Format #{format} not found in #{type} formats"
          end
        end
        compile_format_expressions
      end

      # Adds new formats. Must specify format type and can specify a :before
      # option to nominate which format the new formats should be inserted in
      # front on to take higher precedence.
      #
      # Error is raised if format already exists or if :before format is not found.
      #
      def add_formats(type, *add_formats)
        formats = send("#{type}_formats")
        options = add_formats.extract_options!
        before  = options[:before]
        raise "Format for :before option #{format} was not found." if before && !formats.include?(before)

        add_formats.each do |format|
          raise "Format #{format} is already included in #{type} formats" if formats.include?(format)

          index = before ? formats.index(before) : -1
          formats.insert(index, format)
        end
        compile_format_expressions
      end

      # Removes formats where the 1 or 2 digit month comes first, to eliminate
      # formats which are ambiguous with the European style of day then month.
      # The mmm token is ignored as its not ambiguous.
      #
      def remove_us_formats
        us_format_regexp = /\Am{1,2}[^m]/
        date_formats.reject! { |format| us_format_regexp =~ format }
        datetime_formats.reject! { |format| us_format_regexp =~ format }
        compile_format_expressions
      end

    private

      # Generate regular expression from format string
      def generate_format_regexp(string_format)
        format = string_format.dup
        format.gsub!(/([\.\\])/, '\\\\\1') # escapes dots and backslashes
        found_tokens, token_order, value_token_count = [], [], 0

        tokens = format_tokens.keys.sort {|a,b| a.size <=> b.size }.reverse

        # Substitute tokens with numbered placeholder
        tokens.each do |token|
          regexp_str, arg_key = *format_tokens[token]
          if format.gsub!(/#{token}/, "%<#{found_tokens.size}>")
            if arg_key
              regexp_str = "(#{regexp_str})" 
              value_token_count += 1
            end
            found_tokens << [regexp_str, arg_key]
          end
        end

        # Replace placeholders with token regexps
        format.scan(/%<(\d)>/).each {|token_index|
          token_index = token_index.first
          token = found_tokens[token_index.to_i]
          format.gsub!("%<#{token_index}>", token[0])
          token_order << token[1]
        }

        compile_format_method(token_order.compact, string_format)
        return value_token_count, format
      rescue
        raise "The following format regular expression failed to compile: #{format}\n from format #{string_format}."
      end

      # Compiles a format method which maps the regexp capture groups to method
      # arguments based on order captured. A time array is built using the argument
      # values placed in the position defined by the component.
      #
      def compile_format_method(components, name)
        values = [nil] * 7
        components.each do |component|
          position, code = *format_components[component]
          values[position] = code || "#{component}.to_i" if position
        end
        class_eval <<-DEF
          class << self
            define_method(:"format_#{name}") do |#{components.join(',')}|
              [#{values.map {|i| i || 'nil' }.join(',')}]
            end
          end
        DEF
      end

      def compile_formats(formats)
        regexp = ''
        expressions = []
        formats.inject(0) { |match_index, format|
          token_count, regexp_string = generate_format_regexp(format)
          regexp = "#{regexp}(#{regexp_string})|"
          expressions << [ format, match_index ]
          match_index += token_count + 1 # add one for wrapper capture
        }
        return expressions, Regexp.new("^(#{regexp.chop})$")
      end

      # Pick expression set and combine date and datetimes for
      # datetime attributes to allow date string as datetime
      def expression_set(type, string)
        case type
        when :date
          [ [ date_expressions, date_regexp], [ datetime_expressions, datetime_regexp] ]
        when :time
          [ [ time_expressions, time_regexp], [ datetime_expressions, datetime_regexp] ]
        when :datetime
          # gives a speed-up for date string as datetime attributes
          if string.length < 11
            [ [ date_expressions, date_regexp], [ datetime_expressions, datetime_regexp] ] 
          else
            [ [ datetime_expressions, datetime_regexp], [ date_expressions, date_regexp] ] 
          end
        end
      end

      def wrap_regexp(regexp, type, strict=false)
        type = strict ? :datetime : type
        /#{@@type_wrapper[type][0]}#{regexp}#{@@type_wrapper[type][1]}/
      end

    end
  end
end

Timeliness::Parser.compile_format_expressions
