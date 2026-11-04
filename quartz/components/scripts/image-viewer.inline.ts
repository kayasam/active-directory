let releaseImageViewer: (() => void) | undefined

function setupImageViewer() {
  releaseImageViewer?.()
  const article = document.querySelector(".center article")
  if (!article) return
  const controller = new AbortController()
  const { signal } = controller
  const dialog = document.createElement("dialog")
  dialog.className = "image-viewer"
  dialog.setAttribute("aria-label", "Agrandir la capture")
  const toolbar = document.createElement("div")
  toolbar.className = "image-viewer-toolbar"
  const viewport = document.createElement("div")
  viewport.className = "image-viewer-viewport"
  const picture = document.createElement("img")
  picture.draggable = false
  viewport.append(picture)
  const status = document.createElement("output")
  status.setAttribute("aria-live", "polite")
  let zoom = 1
  let trigger: HTMLElement | null = null
  let previousOverflow = ""

  function renderZoom() {
    if (!dialog.open || !picture.naturalWidth) return
    const fit = Math.min(
      1,
      (viewport.clientWidth - 32) / picture.naturalWidth,
      (viewport.clientHeight - 32) / picture.naturalHeight,
    )
    picture.style.width = `${Math.max(1, picture.naturalWidth * fit * zoom)}px`
    status.textContent = `${Math.round(zoom * 100)} %`
    smaller.disabled = zoom <= 1
    larger.disabled = zoom >= 4
  }

  function button(label: string, text: string, action: () => void) {
    const element = document.createElement("button")
    element.type = "button"
    element.textContent = text
    element.setAttribute("aria-label", label)
    element.title = label
    element.addEventListener("click", action, { signal })
    toolbar.append(element)
    return element
  }
  const smaller = button("Réduire", "−", () => {
    zoom = Math.max(1, zoom - 0.5)
    renderZoom()
  })
  const larger = button("Zoomer", "+", () => {
    zoom = Math.min(4, zoom + 0.5)
    renderZoom()
  })
  toolbar.append(status)
  button("Adapter à l’écran", "Ajuster", () => {
    zoom = 1
    renderZoom()
  })
  const close = button("Fermer la capture", "Fermer ×", () => dialog.close())
  dialog.append(toolbar, viewport)
  document.body.append(dialog)

  function openImage(image: HTMLImageElement, target: HTMLElement) {
    trigger = target
    picture.alt = image.alt || "Capture du cours"
    picture.src = image.currentSrc || image.src
    zoom = 1
    previousOverflow = document.body.style.overflow
    document.body.style.overflow = "hidden"
    dialog.showModal()
    renderZoom()
    viewport.scrollTo(0, 0)
    close.focus()
  }
  picture.addEventListener("load", renderZoom, { signal })
  window.addEventListener("resize", renderZoom, { signal })
  dialog.addEventListener("close", () => {
    document.body.style.overflow = previousOverflow
    trigger?.focus({ preventScroll: true })
  }, { signal })
  dialog.addEventListener("click", (event) => {
    if (event.target === dialog || event.target === viewport) dialog.close()
  }, { signal })

  const restores: (() => void)[] = []
  article.querySelectorAll<HTMLImageElement>("img").forEach((image) => {
    if (image.closest("button, .mermaid, [data-no-zoom]")) return
    const anchor = image.closest("a")
    // Preserve links which lead to a page rather than the image itself.
    if (anchor && anchor.href !== image.src) return
    const target: HTMLElement = anchor ?? image
    const attributes = ["tabindex", "role", "aria-label", "title"] as const
    const original = attributes.map((name) => [name, target.getAttribute(name)] as const)
    target.classList.add("image-zoom-trigger")
    target.tabIndex = 0
    target.setAttribute("role", "button")
    target.setAttribute("aria-label", `Agrandir : ${image.alt || "capture du cours"}`)
    target.title = "Cliquer pour agrandir"
    target.addEventListener("click", (event) => {
      if (event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) return
      event.preventDefault()
      openImage(image, target)
    }, { signal })
    target.addEventListener("keydown", (event) => {
      if (event.key === "Enter" || event.key === " ") {
        event.preventDefault()
        openImage(image, target)
      }
    }, { signal })
    restores.push(() => {
      target.classList.remove("image-zoom-trigger")
      original.forEach(([name, value]) => {
        if (value === null) target.removeAttribute(name)
        else target.setAttribute(name, value)
      })
    })
  })
  releaseImageViewer = () => {
    if (dialog.open) {
      document.body.style.overflow = previousOverflow
      dialog.close()
    }
    controller.abort()
    dialog.remove()
    restores.forEach((restore) => restore())
  }
}

document.addEventListener("nav", setupImageViewer)
