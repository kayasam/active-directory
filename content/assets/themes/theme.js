;(function () {
  "use strict"
  const key = "theme"
  const root = document.documentElement
  const media = window.matchMedia("(prefers-color-scheme: dark)")
  let preference = null
  try {
    preference = localStorage.getItem(key)
  } catch (_) {}
  function apply(value) {
    const theme = value === "dark" ? "dark" : "light"
    root.dataset.theme = theme
    root.setAttribute("saved-theme", theme)
    document.querySelectorAll(".theme-switch").forEach((button) => {
      button.textContent = theme === "dark" ? "Passer au thème clair" : "Passer au thème sombre"
      button.setAttribute("aria-label", button.textContent)
    })
    document.querySelectorAll(".course-quiz-frame").forEach((frame) => {
      frame.contentWindow?.postMessage(
        { type: "linux-theme", theme },
        window.location.protocol === "file:" ? "*" : window.location.origin,
      )
    })
  }
  apply(
    preference === "dark" || preference === "light" ? preference : media.matches ? "dark" : "light",
  )
  function mount() {
    const toolbar = document.createElement("div")
    toolbar.className = "theme-toolbar"
    const button = document.createElement("button")
    button.type = "button"
    button.className = "theme-switch"
    button.addEventListener("click", () => {
      preference = root.dataset.theme === "dark" ? "light" : "dark"
      try {
        localStorage.setItem(key, preference)
      } catch (_) {}
      apply(preference)
    })
    toolbar.appendChild(button)
    document.body.prepend(toolbar)
    const quiz = document.getElementById("tab-quiz")
    const slug = root.dataset.chapter
    if (quiz && slug) {
      const link = document.createElement("a")
      link.href = root.dataset.quizHref || "quiz/" + slug + ".html"
      link.textContent = "Ouvrir le quiz de 20 questions en pleine page →"
      const frame = document.createElement("iframe")
      frame.className = "course-quiz-frame"
      frame.title = "Quiz de 20 questions du chapitre"
      frame.src = link.href
      frame.addEventListener("load", () => apply(root.dataset.theme))
      quiz.replaceChildren(link, frame)
    }
    document.querySelectorAll(".course-quiz-frame").forEach((frame) => {
      frame.addEventListener("load", () => apply(root.dataset.theme))
    })
    apply(root.dataset.theme)
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", mount)
  else mount()
  window.addEventListener("storage", (event) => {
    if (event.key === key) {
      preference = event.newValue
      apply(preference || (media.matches ? "dark" : "light"))
    }
  })
  window.addEventListener("message", (event) => {
    if (event.source !== window.parent || window.parent === window) return
    if (window.location.protocol !== "file:" && event.origin !== window.location.origin) return
    if (event.data?.type === "linux-theme" && ["light", "dark"].includes(event.data.theme))
      apply(event.data.theme)
  })
  media.addEventListener("change", (event) => {
    if (!preference) apply(event.matches ? "dark" : "light")
  })
})()
