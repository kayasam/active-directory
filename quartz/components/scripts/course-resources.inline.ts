// Chapters live in the explorer; support switching lives in the shared chapter bar.
let releaseChapterResources: (() => void) | undefined
function setupChapterResources() {
  releaseChapterResources?.()
  const payload = document.getElementById("course-resource-data")
  const explorer = document.querySelector<HTMLElement>(".explorer-content")
  if (!payload || !explorer) return
  let registry: Record<string, { kind: string; href: string }[]>
  try { registry = JSON.parse(payload.textContent ?? "{}") } catch { return }
  const bar = document.querySelector<HTMLElement>(".chapter-resources")
  const currentKey = bar?.dataset.courseKey
  const coursePath = decodeURIComponent(location.pathname).normalize("NFD").replace(/[\u0300-\u036f]/g, "")
  const kind = document.querySelector<HTMLElement>(".support-viewer")?.dataset.supportKind ?? (/\/tp(?:\/|$)|-(?:correction|corrigev2)(?:\.html)?\/?$/i.test(coursePath) ? "tp" : "markdown")
  let workshops: { key: string; kind: string; order: number; label: string; title: string; symbol: string }[] = []
  try { workshops = JSON.parse(document.getElementById("workshop-data")?.textContent ?? "[]") } catch {}
  bar?.querySelectorAll<HTMLAnchorElement>("[data-resource-kind]").forEach((link) => {
    if (link.dataset.resourceKind === kind) link.setAttribute("aria-current", "page")
    else link.removeAttribute("aria-current")
  })
  function populate() {
    explorer!.querySelectorAll<HTMLAnchorElement>("a.nav-file-title").forEach((link) => {
      const path = decodeURIComponent(new URL(link.href, location.href).pathname).replace(/\/$/, "")
      const entry = workshops.find((item) => path.endsWith("/" + item.key))
      const item = link.closest("li")
      if (!item) return
      if (!path.includes('/annexe/')) return
      if (!entry) {
        if (/-(?:corrig|correction)/i.test(path)) { item.hidden = true; return }
      }
      item.classList.add("workshop-explorer-item")
      item.style.order = String(entry?.order ?? 3)
      item.parentElement?.classList.add("workshop-explorer-list")
      link.classList.add("workshop-explorer-link")
      if (entry && !link.dataset.workshopPrepared) {
        link.textContent = entry.title
        link.dataset.workshopPrepared = "true"
      }
      const key = entry?.key ?? path.normalize("NFD").replace(/[\u0300-\u036f]/g, "")
      if (coursePath.includes(key)) link.setAttribute("aria-current", coursePath.endsWith(key) ? "page" : "location")
      else link.removeAttribute("aria-current")
    })
    explorer!.querySelectorAll<HTMLElement>(".workshop-explorer-list").forEach((list) => {
      const children = Array.from(list.children) as HTMLElement[]
      const sorted = [...children].sort((a, b) => Number(a.style.order || 99) - Number(b.style.order || 99))
      if (children.some((item, index) => item !== sorted[index])) list.append(...sorted)
    })
    explorer!.querySelectorAll<HTMLElement>(".folder-container[data-folderpath]").forEach((folder) => {
      const key = (folder.dataset.folderpath ?? "").replace(/\/index$/, "")
      const chapter = Boolean(registry[key])
      folder.classList.toggle("is-track-root", Object.keys(registry).some((chapterKey) => chapterKey.split("/")[0] === key))
      folder.classList.toggle("is-course-chapter", chapter)
      folder.classList.toggle("support-current-chapter", key === currentKey)
      if (chapter) {
        folder.dataset.chapterNumber = key.split("/").pop()!.slice(0, 2)
        const children = folder.nextElementSibling as HTMLElement | null
        if (children?.classList.contains("folder-outer")) children.hidden = true
        const link = folder.querySelector<HTMLAnchorElement>("a.folder-button")
        if (link) {
          if (key === currentKey) link.setAttribute("aria-current", kind === "markdown" ? "page" : "location")
          else { link.removeAttribute("aria-current"); link.classList.remove("course-current-page", "active", "is-active") }
        }
      } else {
        const disclosure = folder.querySelector<HTMLElement>(".folder-icon")
        if (disclosure) {
          disclosure.setAttribute("role", "button")
          disclosure.setAttribute("tabindex", "0")
          disclosure.setAttribute("aria-label", "Déplier ou replier « " + folder.textContent?.trim() + " »")
          disclosure.setAttribute("aria-expanded", String(folder.nextElementSibling?.classList.contains("open") ?? false))
        }
      }
    })
  }
  const keyboard = (event: KeyboardEvent) => {
    const target = (event.target as Element)?.closest<HTMLElement>(".folder-icon[role=button]")
    if (target && ["Enter", " "].includes(event.key)) { event.preventDefault(); target.dispatchEvent(new MouseEvent("click", { bubbles: true })) }
  }
  const click = () => queueMicrotask(populate)
  populate()
  const observer = new MutationObserver(populate)
  observer.observe(explorer, { childList: true, subtree: true })
  explorer.addEventListener("keydown", keyboard)
  explorer.addEventListener("click", click, true)
  releaseChapterResources = () => { observer.disconnect(); explorer.removeEventListener("keydown", keyboard); explorer.removeEventListener("click", click, true) }
  window.addCleanup?.(releaseChapterResources)
}
document.addEventListener("nav", setupChapterResources)
document.addEventListener("render", setupChapterResources)
