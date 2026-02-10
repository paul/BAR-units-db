# frozen_string_literal: true

class UnitSearchComponent < Bridgetown::Component
  def initialize
    @units = Bridgetown::Current.site.data.units.map { |id, data| Unit.new(id:, data:) }
  end

  def search_options
    (unit_faction_options + unit_tag_options).to_json
  end

  private

  attr_reader :units

  def unit_tag_options
    units.flat_map(&:tags).uniq.sort.map do |tag|
      icon = tag_icon(tag)
      icon_path = "images/icons/#{icon.name}" if icon
      {
        value: tag,
        label: tag,
        kind:  "tag",
        icon:  icon ? %{<img class="inline-block" src="#{relative_url icon_path}" />} : nil
      }.compact
    end
  end

  def unit_faction_options
    units.map(&:faction).uniq.sort.map do |faction|
      icon_path = units.find { |u| u.faction == faction }&.faction_icon_path
      {
        value: faction,
        label: faction.capitalize,
        kind:  "faction",
        icon:  %{<img class="inline-block rounded-full" src="#{relative_url icon_path}" />}
      }
    end
  end

  def tag_icon(tag)
    icon_files.find { |file| file.basename.downcase == tag.downcase }
  end

  def icon_files
    @icon_files ||= Bridgetown::Current.site.static_files.select { |file| file.path.include?("/icons/") }
  end
end
