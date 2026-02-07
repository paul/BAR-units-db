# frozen_string_literal: true

require "bridgetown"

Bridgetown.load_tasks

# Run rake without specifying any command to execute a deploy build by default.
task default: :deploy

#
# Standard set of tasks, which you can customize if you wish:
#
desc "Build the Bridgetown site for deployment"
task deploy: [:clean, "frontend:build"] do
  Bridgetown::Commands::Build.start
end

desc "Build the site in a test environment"
task :test do
  ENV["BRIDGETOWN_ENV"] = "test"
  Bridgetown::Commands::Build.start
end

desc "Runs the clean command"
task :clean do
  Bridgetown::Commands::Clean.start
end

namespace :frontend do
  desc "Build the frontend with esbuild for deployment"
  task :build do
    sh "npm run esbuild"
  end

  desc "Watch the frontend with esbuild during development"
  task :dev do
    sh "npm run esbuild-dev"
  rescue Interrupt
  end
end

desc "Pull BAR data, regenerate assets, and build site"
task publish: [
  "bar:pull",
  "src/_data/units.json",
  "src/_locales/en.yml",
  "src/_data/game_data.yml",
  :convert_buildpics,
  :deploy
]

#
# Add your own Rake tasks here! You can use `environment` as a prerequisite
# in order to write automations or other commands requiring a loaded site.
#
# task :my_task => :environment do
#   puts site.root_dir
#   automation do
#     say_status :rake, "I'm a Rake tast =) #{site.config.url}"
#   end
# end

BAR_REPO_DIR = "Beyond-All-Reason"
BAR_REPO_URL = "https://github.com/beyond-all-reason/Beyond-All-Reason.git"

namespace :bar do
  desc "Clone Beyond-All-Reason repo into Beyond-All-Reason/ (shallow)"
  task :clone do
    if Dir.exist?(BAR_REPO_DIR)
      puts "#{BAR_REPO_DIR} already exists; skipping clone"
      next
    end

    sh "git", "clone", "--depth", "1", BAR_REPO_URL, BAR_REPO_DIR
  end

  desc "Pull latest changes in Beyond-All-Reason repo (shallow)"
  task :pull do
    if Dir.exist?(BAR_REPO_DIR)
      Dir.chdir(BAR_REPO_DIR) do
        branch = `git rev-parse --abbrev-ref HEAD`.strip
        sh "git", "fetch", "--depth", "1", "origin", branch
        sh "git", "reset", "--hard", "FETCH_HEAD"
      end
    else
      puts "#{BAR_REPO_DIR} missing; running bar:clone"
      Rake::Task["bar:clone"].invoke
      next
    end
  end
end

file "src/_data/units.json" => ["Beyond-All-Reason/units"] do |t|
  sh "lua", "units2json.lua", t.name
end

file "src/_locales/en.yml" => ["Beyond-All-Reason/language/en/units.json"] do |t|
  require "json"
  require "yaml"

  # Read BAR language file
  bar_data = JSON.parse(File.read("Beyond-All-Reason/language/en/units.json"))

  names = bar_data.dig("units", "names") || {}
  descriptions = bar_data.dig("units", "descriptions") || {}

  # Merge into i18n structure
  units = {}
  (names.keys | descriptions.keys).each do |unit_id|
    units[unit_id] = {
      "name"        => names[unit_id],
      "description" => descriptions[unit_id]
    }.compact
  end

  # Build final YAML structure
  locale_data = { "en" => { "units" => units } }

  # Ensure directory exists and write
  FileUtils.mkdir_p(File.dirname(t.name))
  File.write(t.name, locale_data.to_yaml)

  puts "Generated #{t.name} with #{units.size} units"
end

task :convert_buildpics

if File.exist?("src/_data/units.json")
  units = JSON.parse(File.read("src/_data/units.json"))
  buildpics = units.map { |k, v| v["buildpic"].downcase }.uniq

  buildpics.each do |buildpic|
    src = Pathname("./Beyond-All-Reason/unitpics").join(buildpic)
    dst = Pathname("./src/images/unitpics").join(buildpic).sub_ext(".png")

    file dst => src do |t|
      sh "magick", src.to_s, dst.to_s
    end
    Rake::Task[:convert_buildpics].enhance([dst])
  end

end

file "src/_data/game_data.yml" => ["Beyond-All-Reason/units",
                                   "Beyond-All-Reason/modinfo.lua"] do |t|
  require "yaml"
  require "fileutils"
  require "json"
  require "net/http"
  require "uri"

  uri = URI("https://api.github.com/repos/beyond-all-reason/BYAR-Chobby/releases/latest")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true

  request = Net::HTTP::Get.new(uri.request_uri)
  request["User-Agent"] = "bar_units_db"
  response = http.request(request)
  release = JSON.parse(response.body)
  puts release.inspect
  version = release["tag_name"]

  last_updated = `git -C #{BAR_REPO_DIR} log -1 --format=%cI -- units`.strip

  data = {
    "game_version" => version,
    "last_updated" => last_updated
  }

  FileUtils.mkdir_p(File.dirname(t.name))
  File.write(t.name, data.to_yaml)
  puts "Generated #{t.name}"
end
