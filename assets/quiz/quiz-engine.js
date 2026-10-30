;(function () {
  "use strict"

  const letters = ["A", "B", "C", "D"]
  const root = document.querySelector("[data-quiz]")
  if (!root) return

  const quizId = root.dataset.quiz
  const data = window.linuxQuizBanks && window.linuxQuizBanks[quizId]
  if (!data || !Array.isArray(data.questions) || data.questions.length !== 20) {
    root.innerHTML = '<p class="quiz-error">Le quiz demandé ne peut pas être chargé.</p>'
    return
  }

  const total = data.questions.length
  const objective = Math.ceil(total * 0.8)
  document.title = data.title + " — Quiz " + (data.track || "Linux")
  document.getElementById("quiz-kicker").textContent = data.chapter
  document.getElementById("quiz-title").textContent = data.title
  document.getElementById("quiz-intro").textContent = data.intro
  document.getElementById("chapter-link").href = data.chapterLink
  document.getElementById("result-course-link").href = data.chapterLink
  document.querySelector(".quiz-meta span:first-child").textContent = total + " questions"
  document.querySelector(".quiz-status > span:last-child").textContent =
    "Objectif : " + objective + "/" + total
  document.getElementById("best-score").nextElementSibling.textContent = "meilleur score /" + total

  const panel = document.getElementById("question-panel")
  const result = document.getElementById("result-panel")
  const currentEl = document.getElementById("current-question")
  const progress = document.getElementById("progress-bar")
  const theme = document.getElementById("question-theme")
  const title = document.getElementById("question-title")
  const answers = document.getElementById("answers")
  const feedback = document.getElementById("feedback")
  const next = document.getElementById("next-question")
  let order = []
  let index = 0
  let score = 0
  let answered = false
  let correctPositions = []

  function shuffle(values) {
    const copy = values.slice()
    for (let i = copy.length - 1; i > 0; i -= 1) {
      const j = Math.floor(Math.random() * (i + 1))
      ;[copy[i], copy[j]] = [copy[j], copy[i]]
    }
    return copy
  }

  function distributeChoices(question, correctPosition) {
    const distractors = shuffle(
      question.choices
        .map((_, choiceIndex) => choiceIndex)
        .filter((choiceIndex) => choiceIndex !== question.answer),
    )
    distractors.splice(correctPosition, 0, question.answer)
    return distractors
  }

  function renderQuestion() {
    answered = false
    next.disabled = true
    feedback.className = "feedback"
    feedback.replaceChildren()
    const question = data.questions[order[index]]
    currentEl.textContent = "Question " + (index + 1) + " sur " + total
    progress.style.width = ((index + 1) / total) * 100 + "%"
    theme.textContent = question.theme
    title.textContent = question.question
    answers.replaceChildren()
    const correctPosition = correctPositions[index]
    distributeChoices(question, correctPosition).forEach(function (choiceIndex, displayedIndex) {
      const button = document.createElement("button")
      button.type = "button"
      button.className = "answer"
      button.dataset.index = String(choiceIndex)
      button.innerHTML =
        '<span class="answer-key">' + letters[displayedIndex] + "</span><span></span>"
      button.lastElementChild.textContent = question.choices[choiceIndex]
      button.addEventListener("click", () => selectAnswer(choiceIndex))
      answers.appendChild(button)
    })
  }

  function selectAnswer(choiceIndex) {
    if (answered) return
    answered = true
    const question = data.questions[order[index]]
    const isCorrect = choiceIndex === question.answer
    if (isCorrect) score += 1
    answers.querySelectorAll(".answer").forEach(function (button) {
      const buttonIndex = Number(button.dataset.index)
      button.disabled = true
      if (buttonIndex === question.answer) button.classList.add("correct")
      if (buttonIndex === choiceIndex && !isCorrect) button.classList.add("wrong")
    })
    const status = document.createElement("strong")
    status.textContent = isCorrect ? "Bonne réponse" : "Réponse à revoir"
    const answerReview = document.createElement("p")
    answerReview.className = "feedback-answer"
    answerReview.textContent = isCorrect
      ? "Votre choix est juste : « " + question.choices[question.answer] + " »."
      : "Vous avez choisi « " +
        question.choices[choiceIndex] +
        " ». La réponse attendue était « " +
        question.choices[question.answer] +
        " »."
    const explanation = document.createElement("p")
    explanation.className = "feedback-explanation"
    explanation.textContent = question.explanation
    const advice = document.createElement("p")
    advice.className = "feedback-advice"
    advice.textContent = isCorrect
      ? "Repère acquis : relisez l’explication pour fixer la distinction dans la durée."
      : "Conseil : comparez les deux notions citées, puis reformulez la bonne définition avec vos propres mots."
    feedback.append(status, answerReview, explanation, advice)
    feedback.className = "feedback visible " + (isCorrect ? "correct" : "wrong")
    next.disabled = false
    next.focus()
  }

  function saveBest(value) {
    const key = "linux-initiation-quiz-" + data.id
    try {
      const previous = Number(localStorage.getItem(key) || 0)
      const best = Math.max(previous, value)
      localStorage.setItem(key, String(best))
      return best
    } catch (_) {
      return value
    }
  }

  function showResult() {
    panel.classList.add("hidden")
    result.classList.add("visible")
    const percent = Math.round((score / total) * 100)
    const messages =
      percent >= 85
        ? [
            "Compétences maîtrisées",
            "Très bon résultat : les notions et la méthode sont solides. Passez à la mise en pratique.",
          ]
        : percent >= 65
          ? [
              "Acquis à consolider",
              "Le socle est présent. Relisez les explications manquées, puis refaites le quiz.",
            ]
          : [
              "Révision recommandée",
              "Reprenez le chapitre et cherchez à comprendre la logique avant de recommencer.",
            ]
    document.getElementById("result-score").textContent = score + "/" + total
    document.getElementById("result-percent").textContent = percent + " %"
    document.getElementById("result-title").textContent = messages[0]
    document.getElementById("result-message").textContent = messages[1]
    document.getElementById("correct-count").textContent = String(score)
    document.getElementById("wrong-count").textContent = String(total - score)
    document.getElementById("best-score").textContent = String(saveBest(score))
    result.scrollIntoView({ behavior: "smooth", block: "start" })
  }

  function start(scroll = false) {
    order = shuffle(data.questions.map((_, questionIndex) => questionIndex))
    index = 0
    score = 0
    // Mélanger une répartition équilibrée : cinq bonnes réponses par lettre.
    correctPositions = shuffle(
      Array.from({ length: total }, (_, questionIndex) => questionIndex % letters.length),
    )
    panel.classList.remove("hidden")
    result.classList.remove("visible")
    renderQuestion()
    if (scroll) panel.scrollIntoView({ behavior: "smooth", block: "start" })
  }

  next.addEventListener("click", function () {
    if (!answered) return
    if (index === total - 1) showResult()
    else {
      index += 1
      renderQuestion()
    }
  })
  document.getElementById("restart-quiz").addEventListener("click", () => start(true))
  start()
})()
