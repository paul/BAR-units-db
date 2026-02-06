# frozen_string_literal: true

Unit = Data.define(:id, :data) do
  def icon_path
    "/images/#{data['icon']}" if data["icon"]
  end

  def buildpic_path
    return unless data["buildpic"]

    image_name = data["buildpic"].downcase.sub(/\.dds$/, ".png")
    "/images/unitpics/#{image_name}"
  end

  def name
    id
  end

  def faction
    case id
    when /^arm/ then "Armada"
    when /^cor/ then "Cortex"
    when /^leg/ then "Legion"
    else
      "Unknown"
    end
  end

  def faction_icon_path
    "/images/factions/#{faction.downcase}.png"
  end

  def unit_type
    return "" unless data["icon"]

    icon_name = File.basename(data["icon"].to_s, File.extname(data["icon"].to_s))
    return "Commander" if icon_name.match?(/\A(arm|cor|leg)com/)

    icon_key = icon_name.split("_").first
    icon_key = icon_key.sub(/\d+\z/, "")

    case icon_key
    when "air" then "Air"
    when "bot", "kbot" then "Bot"
    when "vehicle" then "Vehicle"
    when "hover" then "Hover"
    when "ship" then "Ship"
    when "sub" then "Submarine"
    when "amphib" then "Amphibious"
    # when "factory" then "Factory"
    # when "defence", "def" then "Defense"
    # when "wall" then "Wall"
    # when "mex" then "Metal Extractor"
    # when "radar" then "Radar"
    # when "energy", "energystorage" then "Energy"
    # when "jammer" then "Jammer"
    # when "shield" then "Shield"
    # when "targetting", "targeting" then "Targeting"
    # when "aa" then "Anti-Air"
    else
      "Building"
    end
  end

  def tech_level
    data.dig("customparams", "techlevel") || 1
  end

  def metal_cost
    data["metalcost"] || data["buildcostmetal"]
  end

  def energy_cost
    data["energycost"] || data["buildcostenergy"]
  end

  def health
    data["health"]
  end

  def sight_distance
    data["sightdistance"]
  end

  def speed
    data["speed"]
  end

  def weapon_range
    return nil unless data["weapons"].is_a?(Array) && data["weapons"].any? && data["weapondefs"]

    ranges = data["weapons"].filter_map do |w|
      weapon_def_name = w["def"]&.downcase
      data.dig("weapondefs", weapon_def_name, "range") if weapon_def_name
    end
    ranges.max if ranges.any?
  end

  def constructor?
    data["buildoptions"].is_a?(Array) && data["buildoptions"].any?
  end
end
