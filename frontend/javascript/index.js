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
    initSortSync()
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

// --- Sort URL sync ---

const initSortSync = () => {
  const tableWrapper = document.querySelector("[data-units-table]")
  if (!tableWrapper) return

  const waitForDT = () => {
    const tableEl = tableWrapper.querySelector("table")
    if (tableEl && jQuery.fn.dataTable.isDataTable(tableEl)) {
      const dt = jQuery(tableEl).DataTable()
      setupSortSync(dt, tableEl)
    } else {
      setTimeout(waitForDT, 50)
    }
  }
  waitForDT()
}

const setupSortSync = (dt, tableEl) => {
  // Build a map of sort_key -> column index from data-sort-key attributes
  const headers = tableEl.querySelectorAll("thead th[data-sort-key]")
  const keyToIndex = {}
  const indexToKey = {}
  headers.forEach((th, i) => {
    const key = th.getAttribute("data-sort-key")
    if (key) {
      keyToIndex[key] = i
      indexToKey[i] = key
    }
  })

  // Restore sort from URL on load
  const url = new URL(window.location.href)
  const sortParam = url.searchParams.get("sort")
  if (sortParam) {
    const desc = sortParam.startsWith("-")
    const key = desc ? sortParam.slice(1) : sortParam
    const colIndex = keyToIndex[key]
    if (colIndex !== undefined) {
      dt.order([colIndex, desc ? "desc" : "asc"]).draw()
    }
  }

  // Update URL when sort changes
  jQuery(tableEl).on("order.dt", () => {
    const order = dt.order()
    const url = new URL(window.location.href)

    if (!order || !order.length) {
      // Unsorted state — remove sort param
      url.searchParams.delete("sort")
    } else {
      const [colIndex, direction] = order[0]
      const key = indexToKey[colIndex]
      if (!key) return

      const sortValue = direction === "desc" ? `-${key}` : key
      url.searchParams.set("sort", sortValue)
    }

    window.history.replaceState(null, "", url.toString())
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
