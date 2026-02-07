# frozen_string_literal: true

class UnitSearchComponent < Bridgetown::Component
  def initialize
    @units = Bridgetown::Current.site.data.units.map { |id, data| Unit.new(id:, data:) }
  end

  private

  attr_reader :units

  def select_data
    {
      placeholder:      "Search units...",
      dropdownClasses:  "top-full left-0 mt-2 z-50 w-full max-h-72 p-1 space-y-0.5 bg-white dark:bg-neutral-900 border border-transparent rounded-lg shadow-xl overflow-hidden overflow-y-auto [&::-webkit-scrollbar]:w-2 [&::-webkit-scrollbar-thumb]:rounded-none [&::-webkit-scrollbar-track]:bg-gray-100 dark:[&::-webkit-scrollbar-track]:bg-neutral-700 [&::-webkit-scrollbar-thumb]:bg-gray-300 dark:[&::-webkit-scrollbar-thumb]:bg-neutral-500",
      optionClasses:    "py-2 px-4 w-full text-sm text-gray-800 dark:text-neutral-200 cursor-pointer hover:bg-gray-100 dark:hover:bg-neutral-800 rounded-lg focus:outline-hidden focus:bg-gray-100 dark:focus:bg-neutral-800 hs-select-disabled:pointer-events-none hs-select-disabled:opacity-50",
      mode:             "tags",
      wrapperClasses:   "relative ps-0.5 pe-9 min-h-11.5 flex items-center flex-wrap text-nowrap w-full bg-white dark:bg-neutral-800 border border-gray-200 dark:border-neutral-700 rounded-lg text-start text-sm focus:border-blue-700 dark:focus:border-blue-600 focus:ring-blue-700 dark:focus:ring-blue-600",
      tagsItemTemplate: "<div class=\"flex flex-nowrap items-center relative z-10 bg-white dark:bg-neutral-800 border border-gray-200 dark:border-neutral-700 rounded-full p-1 m-1\"><div class=\"size-6 me-2\" data-icon></div><div class=\"whitespace-nowrap text-gray-800 dark:text-neutral-200\" data-title></div><div class=\"inline-flex shrink-0 justify-center items-center size-5 ms-2 rounded-full bg-gray-100 dark:bg-neutral-700 text-gray-800 dark:text-neutral-200 hover:bg-gray-200 dark:hover:bg-neutral-600 focus:outline-hidden focus:bg-gray-200 dark:focus:bg-neutral-600 text-sm cursor-pointer\" data-remove><svg class=\"shrink-0 size-3\" xmlns=\"http://www.w3.org/2000/svg\" width=\"24\" height=\"24\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M18 6 6 18\"/><path d=\"m6 6 12 12\"/></svg></div></div>",
      tagsInputId:      "units-tag-select-input",
      tagsInputClasses: "py-2.5 sm:py-3 px-2 min-w-20 rounded-lg order-1 bg-transparent border-transparent text-gray-800 dark:text-neutral-200 placeholder:text-gray-500 dark:placeholder:text-neutral-400 focus:ring-0 sm:text-sm outline-hidden",
      searchNoResultTemplate: "<span></span>",
      searchNoResultClasses:  "hidden",
      optionTemplate:   "<div class=\"flex items-center\"><div class=\"size-8 me-2\" data-icon></div><div><div class=\"text-sm font-semibold text-gray-800 dark:text-neutral-200\" data-title></div></div><div class=\"ms-auto\"><span class=\"hidden hs-selected:block\"><svg class=\"shrink-0 size-4 text-blue-600 dark:text-blue-500\" xmlns=\"http://www.w3.org/2000/svg\" width=\"16\" height=\"16\" fill=\"currentColor\" viewBox=\"0 0 16 16\"><path d=\"M12.736 3.97a.733.733 0 0 1 1.047 0c.286.289.29.756.01 1.05L7.88 12.01a.733.733 0 0 1-1.065.02L3.217 8.384a.757.757 0 0 1 0-1.06.733.733 0 0 1 1.047 0l3.052 3.093 5.4-6.425a.247.247 0 0 1 .02-.022Z\"/></svg></span></div></div>",
      isAddTagOnEnter:  false,
      extraMarkup:      "<div class=\"absolute top-1/2 end-3 -translate-y-1/2\"><svg class=\"shrink-0 size-3.5 text-gray-500 dark:text-neutral-400\" xmlns=\"http://www.w3.org/2000/svg\" width=\"24\" height=\"24\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"m7 15 5 5 5-5\"/><path d=\"m7 9 5-5 5 5\"/></svg></div>"
    }
  end

  def unit_options
    unit_faction_options + unit_tag_options
  end

  def unit_tag_options
    units.flat_map(&:tags).uniq.sort.map do |tag|
      icon = tag_icon(tag)
      {
        value: tag,
        label: tag,
        json:  {
          icon: icon ? %{<img class="inline-block" src="#{icon.relative_url}" />} : nil
        }.compact
      }
    end
  end

  def unit_faction_options
    units.map(&:faction).uniq.sort.map do |faction|
      icon_path = units.find { |u| u.faction == faction }&.faction_icon_path
      {
        value: faction,
        label: faction.capitalize,
        json:  {
          icon: %{<img class="inline-block rounded-full" src="#{relative_url icon_path}" />}
        }
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
