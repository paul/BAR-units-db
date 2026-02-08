# Beyond All Reason Units DB

This project builds a static unit database table from the Beyond All Reason game files.

## How It Works

1. Clone the game data repo to access the source files.
2. Run `units2json.lua` to convert unit definitions into `src/_data/units.json`.
3. Convert i18n unit names and descriptions into `src/_locales/en.yml`.
4. Convert buildpics (`Beyond-All-Reason/unitpics`) to optimized PNGs in `src/images/unitpics`.
5. Copy and optimize unit icons (`Beyond-All-Reason/icons`) into `src/images/icons`.
6. Use Bridgetown to generate the static site and table view.

## Local Development

1. Install tool versions:
   - `mise install`
2. Install dependencies:
   - `bundle install`
   - `npm install`
   - `luarocks install luafilesystem`
   - `luarocks install dkjson`
3. Clone the BAR game repo:
   - `rake bar:clone`
4. Generate the unit data:
   - `rake publish`
5. Start the dev server:
   - `./bin/bt dev`
