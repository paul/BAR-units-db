import "$styles/index.css"
import "$styles/syntax-highlighting.css"

// Import jQuery and DataTables.net (required by Preline DataTable)
import jQuery from "jquery"
import DataTable from "datatables.net-dt"

// Expose jQuery and DataTable globally for Preline
window.jQuery = jQuery
window.$ = jQuery
window.DataTable = DataTable

// Import Preline UI
import "preline/preline"

// Import Preline DataTable plugin (requires jQuery and DataTables.net to be global)
import "@preline/datatable"

// Import all JavaScript & CSS files from src/_components
import components from "$components/**/*.{js,jsx,js.rb,css}"

// Import Svelte component
import { mount } from "svelte"
import UnitSearch from "./UnitSearch.svelte"

// Initialize Preline on page load and Turbo navigation
const initPreline = () => {
  if (window.HSStaticMethods) {
    window.HSStaticMethods.autoInit()
  }

  requestAnimationFrame(() => {
    initUnitSearch()
  })
}

const initUnitSearch = () => {
  const mountTarget = document.getElementById("unit-search-mount")
  const optionsScript = document.getElementById("unit-search-options")

  if (!mountTarget || !optionsScript) return
  // Prevent double-mounting
  if (mountTarget.hasAttribute("data-mounted")) return
  mountTarget.setAttribute("data-mounted", "true")

  let options = []
  try {
    options = JSON.parse(optionsScript.textContent || "[]")
  } catch (e) {
    console.error("Failed to parse unit search options:", e)
  }

  mount(UnitSearch, {
    target: mountTarget,
    props: { options },
  })
}

// Initialize on DOM ready
if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", initPreline)
} else {
  initPreline()
}

// Re-initialize on Turbo navigation (if using Turbo)
document.addEventListener("turbo:load", initPreline)
document.addEventListener("turbo:frame-load", initPreline)

console.info("Bridgetown is loaded!")
