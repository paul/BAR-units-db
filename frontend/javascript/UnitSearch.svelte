<script>
  import { onMount } from "svelte"

  /**
   * @typedef {{ value: string, label: string, kind: "tag" | "faction", icon?: string }} SearchOption
   */

  /** @type {SearchOption[]} */
  let { options = [] } = $props()

  // --- State ---

  /** @type {SearchOption[]} */
  let selectedItems = $state([])
  let inputValue = $state("")
  let showDropdown = $state(false)
  let highlightIndex = $state(-1)

  /** @type {HTMLInputElement|undefined} */
  let inputEl = $state()
  /** @type {HTMLDivElement|undefined} */
  let dropdownEl = $state()
  /** @type {HTMLDivElement|undefined} */
  let rootEl = $state()

  // --- Derived ---

  let filteredOptions = $derived.by(() => {
    const query = inputValue.toLowerCase().trim()
    return options.filter((opt) => {
      // Hide already-selected items
      if (selectedItems.some((s) => s.value === opt.value && s.kind === opt.kind)) return false
      // Filter by query
      if (query && !opt.label.toLowerCase().includes(query)) return false
      return true
    })
  })

  let selectedTags = $derived(selectedItems.filter((s) => s.kind === "tag").map((s) => s.value))
  let selectedFactions = $derived(selectedItems.filter((s) => s.kind === "faction").map((s) => s.value))

  // --- URL state ---

  function serializeToURL() {
    const url = new URL(window.location.href)
    const factions = selectedFactions
    const tags = selectedTags
    const text = inputValue.trim()

    if (factions.length) {
      url.searchParams.set("faction", factions.join(","))
    } else {
      url.searchParams.delete("faction")
    }

    if (tags.length) {
      url.searchParams.set("tags", tags.join(","))
    } else {
      url.searchParams.delete("tags")
    }

    if (text) {
      url.searchParams.set("q", text)
    } else {
      url.searchParams.delete("q")
    }

    // URLSearchParams encodes commas as %2C; restore them for readability
    window.history.replaceState(null, "", url.toString().replaceAll("%2C", ","))
  }

  function restoreFromURL() {
    const url = new URL(window.location.href)
    const factionParam = url.searchParams.get("faction")
    const tagsParam = url.searchParams.get("tags")
    const qParam = url.searchParams.get("q")

    /** @type {SearchOption[]} */
    const restored = []

    if (factionParam) {
      for (const f of factionParam.split(",")) {
        const opt = options.find((o) => o.kind === "faction" && o.value === f.trim())
        if (opt) restored.push(opt)
      }
    }

    if (tagsParam) {
      for (const t of tagsParam.split(",")) {
        const opt = options.find((o) => o.kind === "tag" && o.value === t.trim())
        if (opt) restored.push(opt)
      }
    }

    if (restored.length) {
      selectedItems = restored
    }

    if (qParam) {
      inputValue = qParam
    }
  }

  // --- DataTable integration ---

  /** @type {any} */
  let dataTable = $state(null)
  let filterBound = false

  function escapeRegex(value) {
    return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
  }

  function matchesToken(haystack, token) {
    const escaped = escapeRegex(token.toLowerCase())
    const pattern = new RegExp(`(?:^|\\s)${escaped}(?:\\s|$)`, "i")
    return pattern.test(haystack)
  }

  function bindDataTableFilter() {
    if (filterBound || !dataTable) return
    filterBound = true

    window.jQuery.fn.dataTable.ext.search.push((settings, _data, dataIndex) => {
      if (settings.nTable !== dataTable.table().node()) return true
      const node = dataTable.row(dataIndex).node()
      const nameDesc = (node?.getAttribute("data-units-name-desc") || "").toLowerCase()
      const tagsText = (node?.getAttribute("data-units-tags") || "").toLowerCase()
      const factionText = (node?.getAttribute("data-units-faction") || "").toLowerCase()

      for (const tag of selectedTags) {
        if (!matchesToken(tagsText, tag)) return false
      }

      for (const faction of selectedFactions) {
        if (!matchesToken(factionText, faction)) return false
      }

      const text = inputValue.trim().toLowerCase()
      if (text && !nameDesc.includes(text)) return false

      return true
    })
  }

  function applySearch() {
    if (!dataTable) return
    bindDataTableFilter()
    dataTable.draw()
    serializeToURL()
  }

  // Reactively apply search when selected items or input change
  $effect(() => {
    // Read reactive dependencies to track them
    void selectedTags.length
    void selectedFactions.length
    void inputValue.trim()
    applySearch()
  })

  // --- Actions ---

  function selectOption(opt) {
    if (selectedItems.some((s) => s.value === opt.value && s.kind === opt.kind)) return
    selectedItems = [...selectedItems, opt]
    inputValue = ""
    highlightIndex = -1
  }

  function removeItem(item) {
    selectedItems = selectedItems.filter((s) => !(s.value === item.value && s.kind === item.kind))
  }

  function clearAll() {
    selectedItems = []
    inputValue = ""
    highlightIndex = -1
    showDropdown = false
    inputEl?.blur()
  }

  /**
   * Add a tag/faction from outside the component (e.g. clicking a tag in the table).
   * Exported so the mounting code can call it.
   * @param {string} value
   */
  export function addTag(value) {
    const opt = options.find((o) => o.value === value)
    if (opt) selectOption(opt)
    showDropdown = false
    highlightIndex = -1
  }

  // --- Keyboard handling ---

  function onKeydown(event) {
    if (event.key === "ArrowDown") {
      event.preventDefault()
      showDropdown = true
      highlightIndex = Math.min(highlightIndex + 1, filteredOptions.length - 1)
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      highlightIndex = Math.max(highlightIndex - 1, 0)
    } else if (event.key === "Enter") {
      event.preventDefault()
      if (highlightIndex >= 0 && highlightIndex < filteredOptions.length) {
        selectOption(filteredOptions[highlightIndex])
      } else if (filteredOptions.length === 1) {
        selectOption(filteredOptions[0])
      }
    } else if (event.key === "Escape") {
      showDropdown = false
      highlightIndex = -1
    } else if (event.key === "Backspace" && !inputValue && selectedItems.length) {
      // Remove last badge
      selectedItems = selectedItems.slice(0, -1)
    }
  }

  function onInput() {
    showDropdown = true
    highlightIndex = -1
  }

  function onFocus() {
    showDropdown = true
  }

  // --- Click outside ---

  function onDocumentClick(event) {
    if (rootEl && !rootEl.contains(event.target)) {
      showDropdown = false
      highlightIndex = -1
    }
  }

  // --- Scroll highlighted item into view ---

  $effect(() => {
    if (highlightIndex >= 0 && dropdownEl) {
      const items = dropdownEl.querySelectorAll("[data-option-index]")
      items[highlightIndex]?.scrollIntoView({ block: "nearest" })
    }
  })

  // --- Lifecycle ---

  onMount(() => {
    // Wait for DataTable to initialize
    const tableWrapper = document.querySelector("[data-units-table]")
    if (!tableWrapper || !window.jQuery) return

    const waitForDT = () => {
      const tableEl = tableWrapper.querySelector("table")
      if (tableEl && window.jQuery.fn.dataTable.isDataTable(tableEl)) {
        dataTable = window.jQuery(tableEl).DataTable()
        restoreFromURL()
        applySearch()
      } else {
        setTimeout(waitForDT, 50)
      }
    }
    waitForDT()

    // Listen for tag clicks from the table (capture phase to beat DataTables/Preline handlers)
    tableWrapper.addEventListener("mousedown", (event) => {
      const target = event.target.closest("[data-units-tag]")
      if (!target) return
      event.preventDefault()
      event.stopPropagation()
      const value = target.getAttribute("data-units-tag")
      if (value) addTag(value)
    }, true)

    // Prevent the click from further propagation too
    tableWrapper.addEventListener("click", (event) => {
      const target = event.target.closest("[data-units-tag]")
      if (!target) return
      event.preventDefault()
      event.stopPropagation()
    }, true)

    document.addEventListener("click", onDocumentClick)
    return () => document.removeEventListener("click", onDocumentClick)
  })
</script>

<!-- Search bar -->
<div class="py-3 px-4 min-w-2xl" bind:this={rootEl}>
  <div class="relative w-full">
    <!-- svelte-ignore a11y_click_events_have_key_events -->
    <!-- svelte-ignore a11y_no_static_element_interactions -->
    <div
      class="relative ps-0.5 pe-9 min-h-11.5 flex items-center flex-wrap text-nowrap w-full bg-white dark:bg-neutral-800 border border-gray-200 dark:border-neutral-700 rounded-lg text-start text-sm focus-within:border-blue-700 dark:focus-within:border-blue-600 focus-within:ring-1 focus-within:ring-blue-700 dark:focus-within:ring-blue-600 cursor-text"
      onclick={() => inputEl?.focus()}
    >
      <!-- Badges -->
      {#each selectedItems as item (item.value + item.kind)}
        <div class="flex flex-nowrap items-center relative z-10 bg-white dark:bg-neutral-800 border border-gray-200 dark:border-neutral-700 rounded-full p-1 m-1">
          {#if item.icon}
            <div class="size-6 me-2">
              {@html item.icon}
            </div>
          {/if}
          <div class="whitespace-nowrap text-gray-800 dark:text-neutral-200 text-sm">{item.label}</div>
          <button
            type="button"
            class="inline-flex shrink-0 justify-center items-center size-5 ms-2 rounded-full bg-gray-100 dark:bg-neutral-700 text-gray-800 dark:text-neutral-200 hover:bg-gray-200 dark:hover:bg-neutral-600 focus:outline-hidden focus:bg-gray-200 dark:focus:bg-neutral-600 text-sm cursor-pointer"
            onclick={(e) => { e.stopPropagation(); removeItem(item) }}
            aria-label="Remove {item.label}"
          >
            <svg class="shrink-0 size-3" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6 6 18"/><path d="m6 6 12 12"/></svg>
          </button>
        </div>
      {/each}

      <!-- Input -->
      <input
        bind:this={inputEl}
        bind:value={inputValue}
        oninput={onInput}
        onkeydown={onKeydown}
        onfocus={onFocus}
        type="text"
        class="py-2.5 sm:py-3 px-2 min-w-20 rounded-lg order-1 bg-transparent border-transparent text-gray-800 dark:text-neutral-200 placeholder:text-gray-500 dark:placeholder:text-neutral-400 focus:ring-0 sm:text-sm outline-hidden grow"
        placeholder={selectedItems.length ? "" : "Search units..."}
        autocomplete="off"
      />

      <!-- Clear all button -->
      {#if selectedItems.length || inputValue}
        <button
          type="button"
          class="absolute top-1/2 end-3 -translate-y-1/2 text-gray-500 dark:text-neutral-400 hover:text-gray-700 dark:hover:text-neutral-200 cursor-pointer"
          onclick={(e) => { e.stopPropagation(); clearAll() }}
          aria-label="Clear search"
        >
          <svg class="shrink-0 size-4" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6 6 18"/><path d="m6 6 12 12"/></svg>
        </button>
      {:else}
        <div class="absolute top-1/2 end-3 -translate-y-1/2">
          <svg class="shrink-0 size-3.5 text-gray-500 dark:text-neutral-400" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/></svg>
        </div>
      {/if}
    </div>

    <!-- Dropdown -->
    {#if showDropdown && filteredOptions.length > 0}
      <div
        bind:this={dropdownEl}
        class="absolute top-full left-0 mt-2 z-50 w-full max-h-72 p-1 space-y-0.5 bg-white dark:bg-neutral-900 border border-gray-200 dark:border-neutral-700 rounded-lg shadow-xl overflow-hidden overflow-y-auto [&::-webkit-scrollbar]:w-2 [&::-webkit-scrollbar-thumb]:rounded-none [&::-webkit-scrollbar-track]:bg-gray-100 dark:[&::-webkit-scrollbar-track]:bg-neutral-700 [&::-webkit-scrollbar-thumb]:bg-gray-300 dark:[&::-webkit-scrollbar-thumb]:bg-neutral-500"
      >
        {#each filteredOptions as opt, i (opt.value + opt.kind)}
          <!-- svelte-ignore a11y_click_events_have_key_events -->
          <!-- svelte-ignore a11y_no_static_element_interactions -->
          <div
            data-option-index={i}
            class="py-2 px-4 w-full text-sm text-gray-800 dark:text-neutral-200 cursor-pointer rounded-lg focus:outline-hidden {highlightIndex === i ? 'bg-gray-100 dark:bg-neutral-800' : 'hover:bg-gray-100 dark:hover:bg-neutral-800'}"
            onmousedown={(e) => { e.preventDefault(); selectOption(opt) }}
            onmouseenter={() => highlightIndex = i}
          >
            <div class="flex items-center">
              {#if opt.icon}
                <div class="size-8 me-2">
                  {@html opt.icon}
                </div>
              {/if}
              <div class="text-sm font-semibold text-gray-800 dark:text-neutral-200">{opt.label}</div>
            </div>
          </div>
        {/each}
      </div>
    {/if}
  </div>
</div>
