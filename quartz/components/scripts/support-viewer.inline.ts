function setupFocusToggle(toggle: HTMLButtonElement) {
  let focused = false
  try { focused = sessionStorage.getItem("support-focus") === "true" } catch {}
  function renderFocus() {
    document.body.classList.toggle("support-focus", focused)
    toggle.textContent = focused ? "Afficher les menus" : "Masquer les menus"
    toggle.setAttribute("aria-pressed", String(focused))
  }
  function changeFocus() {
    focused = !focused
    renderFocus()
    try { sessionStorage.setItem("support-focus", String(focused)) } catch {}
  }
  toggle.addEventListener("click", changeFocus)
  renderFocus()

  return () => {
    toggle.removeEventListener("click", changeFocus)
    document.body.classList.remove("support-focus")
  }
}

let releaseSupportViewer: (() => void) | undefined

function setupSupportViewer() {
  releaseSupportViewer?.()
  const viewer = document.querySelector<HTMLElement>(".support-viewer")
  if (!viewer) {
    const toggle = document.querySelector<HTMLButtonElement>(".chapter-resources .support-focus-toggle")
    if (toggle) {
      releaseSupportViewer = setupFocusToggle(toggle)
      window.addCleanup?.(releaseSupportViewer)
    }
    return
  }
  const courseKey = viewer.dataset.courseKey!
  const frame = viewer.querySelector<HTMLIFrameElement>(".support-frame")!
  const toggle = document.querySelector<HTMLButtonElement>(".chapter-resources .support-focus-toggle")!
  const registry = JSON.parse(document.getElementById("course-resource-data")?.textContent ?? "{}")
  const resources: { kind: string; label: string; detail: string; href: string }[] = registry[courseKey] ?? []
  const cleanups: (() => void)[] = []
  const panel = document.createElement("nav")
  panel.className = "support-navigation course-toc"
  panel.setAttribute("aria-label", "Navigation du support")
  const title = document.createElement("button")
  title.type = "button"
  title.className = "support-toc-toggle"
  title.textContent = viewer.dataset.supportKind === "quiz" ? "Dans ce quiz" : "Dans ce support"
  const sections = document.createElement("div")
  sections.className = "support-sections"
  sections.id = "support-section-links"
  title.setAttribute("aria-controls", "support-section-links support-section-status")
  const status = document.createElement("p")
  status.className = "support-status"
  status.id = "support-section-status"
  status.setAttribute("aria-live", "polite")
  panel.append(title, sections, status)
  const desktop = matchMedia("(min-width: 1201px)")
  const compact = matchMedia("(max-width: 800px)")
  let collapsed = compact.matches
  function renderCollapsed() {
    panel.classList.toggle("is-collapsed", collapsed)
    title.setAttribute("aria-expanded", String(!collapsed))
    sections.hidden = collapsed
    status.hidden = collapsed
  }
  const toggleSections = () => { collapsed = !collapsed; renderCollapsed() }
  title.addEventListener("click", toggleSections)
  const compactChanged = () => { collapsed = compact.matches; renderCollapsed() }
  compact.addEventListener("change", compactChanged)
  renderCollapsed()
  function placeNavigation() {
    if (desktop.matches) document.querySelector(".sidebar.right")?.prepend(panel)
    else viewer!.before(panel)
  }
  desktop.addEventListener("change", placeNavigation)
  placeNavigation()
  document.body.classList.add("has-support-viewer")

  const releaseFocus = setupFocusToggle(toggle)

  // Existing HTML/quiz links navigate the outer site, including inside an embedded quiz.
  const routes = new Map<string, string>()
  for (const [key, entries] of Object.entries(registry) as [string, typeof resources][]) {
    const track = key.startsWith("bash/") ? "bash/" : ""
    const slug = key.split("/").pop()
    for (const kind of ["html", "quiz"]) {
      const raw = kind === "html" ? `cours/${key}-interactif.html` : `cours/${key}-quiz.html`
      const resource = entries.find((r) => r.kind === kind)
      if (resource) routes.set(new URL(raw, entries[0].href.replace(new RegExp(key + "/$"), "")).pathname, resource.href)
    }
  }
  const wired = new WeakSet<Document>()
  function wireLinks(doc: Document) {
    if (wired.has(doc)) return
    wired.add(doc)
    // Reference sites often forbid iframes; open them beside the course instead.
    doc.querySelectorAll<HTMLAnchorElement>("a[href]").forEach((anchor) => {
      const url = new URL(anchor.href, doc.baseURI)
      if (/^https?:$/.test(url.protocol) && url.origin !== location.origin) {
        anchor.target = "_blank"
        anchor.rel = "noopener noreferrer"
      }
    })
    const click = (event: MouseEvent) => {
      if (event.defaultPrevented || event.button !== 0 || event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) return
      const anchor = (event.target as Element)?.closest<HTMLAnchorElement>("a[href]")
      if (!anchor || anchor.hasAttribute("download") || anchor.target === "_blank" || anchor.getAttribute("href")?.startsWith("#")) return
      const url = new URL(anchor.href, doc.baseURI)
      if (url.origin !== location.origin) return
      // Hash links belong to the support; retain its native scrolling.
      if (url.pathname === new URL(doc.URL).pathname && url.hash) return
      const target = routes.get(url.pathname)
      const siteRoot = new URL(resources[0]?.href ?? location.href).pathname.replace(courseKey + "/", "")
      if (!target && (!url.pathname.startsWith(siteRoot) || /\.(html|svg|png|jpg|zip|gz|md)$/i.test(url.pathname))) return
      event.preventDefault()
      window.location.assign(target ? target + url.hash : url.href)
    }
    doc.addEventListener("click", click)
    cleanups.push(() => doc.removeEventListener("click", click))
    const wireChild = (child: HTMLIFrameElement) => { try { if (child.contentDocument) wireLinks(child.contentDocument) } catch {} }
    const loaded = (event: Event) => { if ((event.target as Element)?.tagName === "IFRAME") wireChild(event.target as HTMLIFrameElement) }
    doc.addEventListener("load", loaded, true)
    cleanups.push(() => doc.removeEventListener("load", loaded, true))
    doc.querySelectorAll("iframe").forEach(wireChild)
  }

  let resize: ResizeObserver | undefined
  let mutations: MutationObserver | undefined
  function mountFrame() {
    resize?.disconnect()
    mutations?.disconnect()
    const doc = frame.contentDocument
    if (!doc?.body || !doc.body.children.length) return
    wireLinks(doc)
    // Keep one theme control in the outer site and one return/navigation bar.
    const style = doc.createElement("style")
    style.textContent = ".theme-toolbar,.toolbar,.course-site-nav,.bash-site-nav,.quiz-topbar{display:none!important}html{scroll-behavior:auto;min-height:0!important;height:auto!important}body{overflow-x:hidden;min-height:0!important;height:auto!important}"
    doc.head.append(style)
    function height() {
      if (!doc?.body) return
      const bodyHeight = doc.body.getBoundingClientRect().height + parseFloat(doc.defaultView!.getComputedStyle(doc.body).marginTop || "0") + parseFloat(doc.defaultView!.getComputedStyle(doc.body).marginBottom || "0")
      const next = Math.max(640, Math.ceil(Math.max(bodyHeight, doc.body.scrollHeight, doc.documentElement.getBoundingClientRect().height) + 2))
      if (Math.abs(parseFloat(frame.style.height || "0") - next) > 2) frame.style.height = next + "px"
    }
    function progress() {
      if (viewer!.dataset.supportKind !== "quiz") return
      const result = doc!.getElementById("result-panel")
      status.textContent = result?.classList.contains("visible")
        ? "Résultat : " + (doc!.getElementById("result-score")?.textContent ?? "")
        : doc!.getElementById("current-question")?.textContent ?? "20 questions · une réponse expliquée à chaque étape"
    }
    const tabs = [...doc.querySelectorAll<HTMLButtonElement>("[role=tab], .tabs button, .nav button, nav button[onclick^='showTab'], .tab-btn, button.tab")]
    sections.replaceChildren()
    const buttons: HTMLButtonElement[] = []
    tabs.forEach((tab) => {
      const button = document.createElement("button")
      button.type = "button"
      button.textContent = tab.textContent?.trim().replace(/^(\d{2})(?=\S)/, "$1 · ") ?? ""
      button.addEventListener("click", () => { tab.click(); height(); viewer!.scrollIntoView({ block: "start" }) })
      sections.append(button)
      buttons.push(button)
    })
    function refresh() {
      buttons.forEach((button, i) => button.setAttribute("aria-pressed", String(tabs[i].getAttribute("aria-selected") === "true" || tabs[i].classList.contains("active"))))
      progress()
      height()
    }
    resize = new ResizeObserver(height)
    resize.observe(doc.body)
    mutations = new MutationObserver(refresh)
    mutations.observe(doc.body, { subtree: true, childList: true, attributes: true, characterData: true })
    refresh()
    syncTheme()
  }
  function syncTheme() {
    const theme = document.documentElement.getAttribute("saved-theme") === "dark" ? "dark" : "light"
    frame.contentWindow?.postMessage({ type: "linux-theme", theme }, location.origin)
  }
  const themeObserver = new MutationObserver(syncTheme)
  themeObserver.observe(document.documentElement, { attributes: true, attributeFilter: ["saved-theme"] })
  const source = new URL(frame.dataset.supportSrc!, location.href).href
  if (frame.src !== source) frame.src = source
  frame.addEventListener("load", mountFrame)
  if (frame.contentDocument?.readyState === "complete") mountFrame()
  releaseSupportViewer = () => {
    resize?.disconnect(); mutations?.disconnect(); themeObserver.disconnect()
    frame.removeEventListener("load", mountFrame)
    releaseFocus()
    cleanups.forEach((cleanup) => cleanup())
    desktop.removeEventListener("change", placeNavigation)
    compact.removeEventListener("change", compactChanged)
    title.removeEventListener("click", toggleSections)
    panel.remove()
    document.body.classList.remove("has-support-viewer", "support-focus")
  }
  window.addCleanup?.(releaseSupportViewer)
}
document.addEventListener("nav", setupSupportViewer)
document.addEventListener("render", setupSupportViewer)
