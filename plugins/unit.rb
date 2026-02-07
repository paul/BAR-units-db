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

  def type
    key = icon_key
    return "Building" if key.empty?
    return "Bot" if key == "commander"

    case key
    when "air" then "Air"
    when "bot", "kbot" then "Bot"
    when "vehicle" then "Vehicle"
    when "hover" then "Hover"
    when "ship" then "Ship"
    when "sub" then "Submarine"
    when "amphib" then "Amphibious"
    else
      "Building"
    end
  end

  def role
    return "Commander" if icon_key == "commander"

    if type == "Air" && transport?
      return "Transport"
    end

    raw_group = data.dig("customparams", "unitgroup")
    normalized = case raw_group
                 when "builder", "buildert2", "buildert3" then "Builder"
                 when "weapon", "weaponaa", "weaponsub" then "Weapon"
                 when "aa" then "Anti-Air"
                 when "sub" then "Sub"
                 when "util" then "Utility"
                 when "metal" then "Metal"
                 when "energy" then "Energy"
                 when "explo" then "Explosive"
                 when "emp" then "EMP"
                 when "antinuke" then "Anti-Nuke"
                 when "nuke" then "Nuke"
                 else
                   nil
                 end

    return "" unless normalized

    if type == "Building" && icon_key == "factory"
      return "Factory"
    end

    if type == "Building" && normalized == "Weapon"
      return "Artillery" if game_ender_artillery?

      return "Defense"
    end

    normalized
  end

  def tags
    tags = []
    tags << (type == "Building" ? "Building" : "Unit")
    tags << type unless type == "Building"

    role_tag = role.to_s.strip
    if type == "Building"
      if role_tag == "Artillery"
        tags << "Defense"
        tags << "Artillery"
      elsif !role_tag.empty?
        tags << role_tag
      end
    elsif !role_tag.empty?
      tags << role_tag
    end

    tags << "Constructor" if constructor?
    tags << "T#{tech_level || 1}"

    tags.uniq
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

  def construction_speed
    data["workertime"]
  end

  def build_time
    data["buildtime"]
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

  private

  def icon_key
    return "" unless data["icon"]

    icon_name = File.basename(data["icon"].to_s, File.extname(data["icon"].to_s))
    return "commander" if icon_name.match?(/\A(arm|cor|leg)com/)

    icon_key = icon_name.split("_").first
    icon_key.sub(/\d+\z/, "")
  end

  def transport?
    data["transportcapacity"].to_i > 0
  end

  def game_ender_artillery?
    return false unless type == "Building"

    %w[armbrtha corint armvulc corbuzz leglrpc legstarfall].include?(id)
  end
end
