# frozen_string_literal: true

class SortHeaderComponent < Bridgetown::Component
  def initialize(label:, sort_key:, align: "end", extra_classes: "")
    @label = label
    @sort_key = sort_key
    @align = align
    @extra_classes = extra_classes
  end

  attr_reader :label, :sort_key, :align, :extra_classes

  def th_classes
    classes = "py-1 group text-#{align} font-normal focus:outline-hidden"
    classes += " #{extra_classes}" unless extra_classes.empty?
    classes
  end
end
