// Course headings stay identical to the Markdown; only navigation entries are filtered.
let releaseCourseNavigation: (() => void) | undefined

function setupCourseNavigation() {
  releaseCourseNavigation?.()
  const article = document.querySelector<HTMLElement>(".center article")
  const original = document.querySelector<HTMLElement>(".toc")
  const existing = document.querySelector<HTMLElement>(".course-toc")
  if (!article || (!original && !existing)) return

  const labelFor = new Map(
    [...(original?.querySelectorAll<HTMLAnchorElement>("a[data-for]") ?? [])].map((a) => [a.dataset.for!, a.textContent!.trim()]),
  )
  const headings = [...article.querySelectorAll<HTMLElement>("h2[id], h3[id]")].filter((h) => {
    const label = labelFor.get(h.id) ?? h.textContent?.replace(/\s*#$/, "").trim() ?? ""
    return !/^À connaître\s*:/i.test(label)
  })
  if (!headings.length) { original?.remove(); existing?.remove(); return }

  const nav = document.createElement("nav")
  nav.className = "course-toc"
  nav.setAttribute("aria-label", "Dans ce chapitre")
  const toggle = document.createElement("button")
  toggle.className = "course-toc-toggle"
  toggle.type = "button"
  toggle.setAttribute("aria-controls", "course-toc-links")
  const title = document.createElement("span")
  title.textContent = "Dans ce chapitre"
  const chevron = document.createElement("span")
  chevron.setAttribute("aria-hidden", "true")
  toggle.append(title, chevron)
  const list = document.createElement("ul")
  list.id = "course-toc-links"
  list.className = "course-toc-list"
  nav.append(toggle, list)

  const groups: { item: HTMLLIElement; sublist: HTMLUListElement }[] = []
  const entries: { heading: HTMLElement; anchor: HTMLAnchorElement; group: number }[] = []
  let group = -1
  headings.forEach((heading) => {
    if (heading.tagName === "H2" || group < 0) {
      group++
      const item = document.createElement("li")
      item.className = "course-toc-item"
      const sublist = document.createElement("ul")
      sublist.className = "course-toc-sublist"
      sublist.hidden = true
      item.append(sublist)
      list.append(item)
      groups.push({ item, sublist })
    }
    const anchor = document.createElement("a")
    anchor.href = "#" + heading.id
    anchor.textContent = labelFor.get(heading.id) ?? heading.textContent?.replace(/\s*#$/, "").trim() ?? ""
    anchor.dataset.courseHeading = heading.id
    if (heading.tagName === "H2" || groups[group].item.children.length === 1 && !groups[group].item.querySelector("a")) {
      groups[group].item.prepend(anchor)
    } else {
      const child = document.createElement("li")
      child.append(anchor)
      groups[group].sublist.append(child)
    }
    entries.push({ heading, anchor, group })
  })

  ;(original ?? existing)!.replaceWith(nav)
  const desktop = matchMedia("(min-width: 1201px)")
  let expanded = desktop.matches
  function renderExpanded() {
    list.hidden = !expanded
    toggle.setAttribute("aria-expanded", String(expanded))
    chevron.textContent = expanded ? "−" : "+"
  }
  function placeNavigation() {
    if (desktop.matches) document.querySelector(".sidebar.right")?.prepend(nav)
    else article!.before(nav)
    expanded = desktop.matches
    renderExpanded()
  }
  function setActive(index: number) {
    entries.forEach((e, i) => {
      if (i === index) e.anchor.setAttribute("aria-current", "location")
      else e.anchor.removeAttribute("aria-current")
    })
    groups.forEach((g, i) => {
      const active = i === entries[index].group
      g.item.classList.toggle("is-section-active", active)
      g.sublist.hidden = !active || !g.sublist.children.length
    })
  }
  function updatePosition() {
    let index = 0
    entries.forEach((e, i) => { if (e.heading.getBoundingClientRect().top <= 140) index = i })
    setActive(index)
  }
  let frame = 0
  function onScroll() {
    if (frame) return
    frame = requestAnimationFrame(() => { frame = 0; updatePosition() })
  }
  entries.forEach((e, i) => e.anchor.addEventListener("click", () => setActive(i)))
  toggle.addEventListener("click", () => { expanded = !expanded; renderExpanded() })
  desktop.addEventListener("change", placeNavigation)
  window.addEventListener("scroll", onScroll, { passive: true })
  window.addEventListener("resize", onScroll)
  placeNavigation()
  updatePosition()
  try {
    const hash = decodeURIComponent(location.hash.slice(1))
    const selected = entries.findIndex((e) => e.heading.id === hash)
    if (selected >= 0) setActive(selected)
  } catch { /* A malformed URL fragment does not block the navigation. */ }

  function markCurrentChapter() {
    document.querySelectorAll<HTMLAnchorElement>(".explorer-content a[href]").forEach((a) => {
    const path = new URL(a.href, location.href).pathname.replace(/\/$/, "").replace(/\/index(?:\.html)?$/, "")
    const current = location.pathname.replace(/\/$/, "").replace(/\/index(?:\.html)?$/, "")
    if (path === current) { a.classList.add("course-current-page"); a.setAttribute("aria-current", "page") }
    })
  }
  markCurrentChapter()
  const explorer = document.querySelector(".explorer-content")
  const explorerObserver = new MutationObserver(markCurrentChapter)
  if (explorer) explorerObserver.observe(explorer, { childList: true, subtree: true })
  releaseCourseNavigation = () => {
    cancelAnimationFrame(frame)
    desktop.removeEventListener("change", placeNavigation)
    window.removeEventListener("scroll", onScroll)
    window.removeEventListener("resize", onScroll)
    explorerObserver.disconnect()
  }
  window.addCleanup?.(releaseCourseNavigation)
}
document.addEventListener("nav", setupCourseNavigation)
document.addEventListener("render", setupCourseNavigation)
