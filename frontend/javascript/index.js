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
  initUnitsAdvancedSelect(tableWrapper, dataTable)

}

const initUnitsAdvancedSelect = (tableWrapper, dataTable) => {
  const select = tableWrapper.querySelector("#units-tag-select")
  if (!select || select.hasAttribute("data-units-advanced-select-bound")) return
  select.setAttribute("data-units-advanced-select-bound", "true")

  requestAnimationFrame(() => {
    const wrapper = select.closest(".hs-select")
    if (wrapper) {
      wrapper.style.position = "relative"
    }
  })

  const escapeRegex = (value) => value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")

  const tagsInput = document.querySelector("#units-tag-select-input")
  let selectedValues = []
  let selectedTags = []
  let selectedFactions = []
  let freeText = ""
  let suppressNextOpen = false

  const getAttr = (node, name) =>
    (node?.getAttribute(name) || "").toLowerCase()

  const matchesToken = (haystack, token) => {
    const escaped = escapeRegex(token.toLowerCase())
    const pattern = new RegExp(`(?:^|\\s)${escaped}(?:\\s|$)`, "i")
    return pattern.test(haystack)
  }

  const applySearch = () => {
    const selectedOptions = Array.from(select.selectedOptions).filter((option) => option.value)
    selectedValues = selectedOptions.map((option) => option.value)
    selectedTags = selectedOptions
      .filter((option) => option.dataset.unitsKind === "tag")
      .map((option) => option.value)
    selectedFactions = selectedOptions
      .filter((option) => option.dataset.unitsKind === "faction")
      .map((option) => option.value)
    freeText = tagsInput?.value?.trim().toLowerCase() || ""
    dataTable.draw()
  }

  if (!tableWrapper.hasAttribute("data-units-advanced-filter-bound")) {
    tableWrapper.setAttribute("data-units-advanced-filter-bound", "true")
    window.jQuery.fn.dataTable.ext.search.push((settings, data, dataIndex) => {
      if (settings.nTable !== dataTable.table().node()) return true
      const node = dataTable.row(dataIndex).node()
      const nameDesc = getAttr(node, "data-units-name-desc")
      const tagsText = getAttr(node, "data-units-tags")
      const factionText = getAttr(node, "data-units-faction")

      if (selectedTags?.length) {
        for (const value of selectedTags) {
          if (!matchesToken(tagsText, value)) return false
        }
      }

      if (selectedFactions?.length) {
        for (const value of selectedFactions) {
          if (!matchesToken(factionText, value)) return false
        }
      }

      if (freeText && !nameDesc.includes(freeText)) return false

      return true
    })
  }

  select.addEventListener("change", applySearch)
  if (tagsInput) {
    tagsInput.addEventListener("input", applySearch)
    tagsInput.addEventListener("focus", () => {
      if (!suppressNextOpen) return
      suppressNextOpen = false
      window.HSSelect?.close(select)
    })
    tagsInput.addEventListener("keydown", (event) => {
      if (event.key === "Enter") {
        const raw = tagsInput.value.trim()
        if (!raw) return

        const match = Array.from(select.options).find(
          (option) => option.value && option.value.toLowerCase() === raw.toLowerCase()
        )

        event.preventDefault()
        if (match) {
          const instance = window.HSSelect?.getInstance(select)
          if (instance && Array.isArray(instance.value)) {
            const next = instance.value.includes(match.value)
              ? instance.value
              : [...instance.value, match.value]
            instance.setValue(next)
          } else {
            match.selected = true
            select.dispatchEvent(new Event("change", { bubbles: true }))
          }
          tagsInput.value = ""
        }
        requestAnimationFrame(() => tagsInput.focus())
        return
      }

      if (event.key !== "Backspace" || tagsInput.value) return
      const instance = window.HSSelect?.getInstance(select)
      if (instance && Array.isArray(instance.value) && instance.value.length) {
        instance.setValue(instance.value.slice(0, -1))
        requestAnimationFrame(() => tagsInput.focus())
        return
      }
      const options = Array.from(select.selectedOptions)
      if (!options.length) return
      const last = options[options.length - 1]
      last.selected = false
      select.dispatchEvent(new Event("change", { bubbles: true }))
      requestAnimationFrame(() => tagsInput.focus())
    })

    select.addEventListener("change", () => {
      requestAnimationFrame(() => tagsInput.focus())
    })
  }

  tableWrapper.addEventListener(
    "mousedown",
    (event) => {
      const target = event.target.closest("[data-units-tag]")
      if (!target) return
      event.preventDefault()
      event.stopPropagation()

      const value = target.getAttribute("data-units-tag")
      if (!value) return

      const instance = window.HSSelect?.getInstance(select)
      if (instance && Array.isArray(instance.value)) {
        const next = instance.value.includes(value) ? instance.value : [...instance.value, value]
        instance.setValue(next)
      } else {
        const option = Array.from(select.options).find((opt) => opt.value === value)
        if (option) {
          option.selected = true
          select.dispatchEvent(new Event("change", { bubbles: true }))
        }
      }

      applySearch()
      window.HSSelect?.close(select)
      suppressNextOpen = true
      requestAnimationFrame(() => {
        tagsInput?.focus()
        window.HSSelect?.close(select)
      })
    },
    true
  )

  tableWrapper.addEventListener(
    "click",
    (event) => {
      const target = event.target.closest("[data-units-tag]")
      if (!target) return
      event.preventDefault()
      event.stopPropagation()
      window.HSSelect?.close(select)
    },
    true
  )
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
