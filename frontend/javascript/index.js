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

// Initialize Preline on page load and Turbo navigation
const initPreline = () => {
  if (window.HSStaticMethods) {
    window.HSStaticMethods.autoInit()
  }

  requestAnimationFrame(() => {
    initUnitsFilters()
  })
}

const initUnitsFilters = () => {
  const tableWrapper = document.querySelector("[data-units-table]")
  if (!tableWrapper || !window.jQuery) return

  const tableEl = tableWrapper.querySelector("table")
  if (!tableEl) return

  if (!window.jQuery.fn.dataTable.isDataTable(tableEl)) {
    if (!tableWrapper.hasAttribute("data-units-filters-pending")) {
      tableWrapper.setAttribute("data-units-filters-pending", "true")
      setTimeout(initUnitsFilters, 50)
    }
    return
  }

  tableWrapper.removeAttribute("data-units-filters-pending")

  const dataTable = window.jQuery(tableEl).DataTable()
  const filters = tableWrapper.querySelectorAll("[data-units-filter]")

  filters.forEach((filter) => {
    if (filter.hasAttribute("data-units-filter-bound")) return
    filter.setAttribute("data-units-filter-bound", "true")

    filter.addEventListener("select.hs.combobox", () => {
      const columnIndex = Number(filter.getAttribute("data-units-filter"))
      const input = filter.querySelector("[data-hs-combo-box-input]")
      const rawValue = input?.value?.trim() || ""
      const placeholder = filter.getAttribute("data-units-filter-placeholder")
      const anyLabel = filter.getAttribute("data-units-filter-any") || "Any"
      const filterType = filter.getAttribute("data-units-filter-type")

      if (!rawValue || rawValue === anyLabel || (placeholder && rawValue === placeholder)) {
        if (input && placeholder) {
          input.value = ""
          filter.classList.remove("has-value")
        }
        dataTable.column(columnIndex).search("").draw()
        return
      }

      const escaped = rawValue.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
      dataTable.column(columnIndex).search(`^${escaped}$`, true, false).draw()
    })
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
