# frozen_string_literal: true

module Builders
  class Helpers < SiteBuilder
    def build
      helper :format_number do |value, precision: 0|
        next "" if value.nil?

        # Round to precision and split into integer and decimal parts
        rounded = value.to_f.round(precision)
        int_part, dec_part = rounded.to_s.split(".")

        # Add thin space (U+2009) as thousands separator
        formatted_int = int_part.reverse.gsub(/(\d{3})(?=\d)/, '\\1 ').reverse

        if precision > 0 && dec_part
          "#{formatted_int}.#{dec_part.ljust(precision, '0')}"
        else
          formatted_int
        end
      end
    end
  end
end
