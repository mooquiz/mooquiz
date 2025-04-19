// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025 ⟁K <k@u27c.one>

import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre
import lustre/attribute
import lustre/effect
import lustre/element/html
import lustre/event
import rsvp
import tempo
import tempo/date

const questions_dir_url = "https://raw.githubusercontent.com/mooquiz/Questions/refs/heads/main/"

const launch_date = "2025-04-19"

type Answer {
  Answer(pos: Int, text: String)
}

type Question {
  Question(
    id: Int,
    text: String,
    answers: List(Answer),
    correct: Int,
    selected: Option(Int),
  )
}

type QuizResult {
  QuizResult(results: List(Bool), answers: List(Int), score: Int, out_of: Int)
}

type Stats {
  Stats(streak: Int, count: Int)
}

type Msg {
  ShareResults
  ReadAnswers(String, Int, Int)
  SubmitAnswers
  ToggleResultPanel
  SelectAnswer(String)
  GotQuestions(Result(String, rsvp.Error))
}

type Model {
  Model(
    title: String,
    url: String,
    submitted: Bool,
    questions: List(Question),
    show_results: Bool,
    date: tempo.Date,
    launch_date: tempo.Date,
    stats: Stats,
  )
}

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)
  Nil
}

fn init(_flags) -> #(Model, effect.Effect(Msg)) {
  let model =
    Model(
      title: "Loading",
      url: "popquizza.com",
      submitted: False,
      questions: [],
      show_results: True,
      date: date.current_local(),
      launch_date: date.literal(launch_date),
      stats: Stats(streak: 0, count: 0),
    )

  #(
    model,
    rsvp.get(
      questions_dir_url <> date_format(model.date) <> ".txt",
      rsvp.expect_text(GotQuestions),
    ),
  )
}

fn update(model: Model, msg: Msg) {
  case msg {
    ShareResults -> up_share_results(model)
    ToggleResultPanel -> toggle_result_panel(model)
    ReadAnswers(answers, streak, count) ->
      read_answers(model, answers, streak, count)
    GotQuestions(Ok(file)) -> got_questions(model, file)
    GotQuestions(Error(_)) -> #(model, effect.none())
    SubmitAnswers -> submit_answers(model)
    SelectAnswer(value) -> select_answer(model, value)
  }
}

fn up_share_results(model: Model) {
  #(
    model,
    share_results(model.title, model.url, calculate_results(model.questions)),
  )
}

fn toggle_result_panel(model: Model) {
  #(Model(..model, show_results: !model.show_results), effect.none())
}

fn read_answers(model: Model, answers: String, streak: Int, count: Int) {
  let result_decoder = {
    use answers <- decode.field("answers", decode.list(decode.int))
    use results <- decode.field("results", decode.list(decode.bool))
    use score <- decode.field("score", decode.int)
    use out_of <- decode.field("outOf", decode.int)
    decode.success(QuizResult(results:, answers:, score:, out_of:))
  }
  case json.parse(answers, result_decoder) {
    Error(_) -> #(model, effect.none())
    Ok(attempt) -> {
      let questions =
        attempt.answers
        |> list.zip(model.questions)
        |> list.map(fn(x) { Question(..x.1, selected: Some(x.0)) })
      #(
        Model(
          ..model,
          questions: questions,
          submitted: True,
          stats: Stats(streak: streak, count: count),
        ),
        effect.none(),
      )
    }
  }
}

fn got_questions(model, file) {
  let assert [title, ..questions] = file |> string.trim |> string.split("\n\n")
  let questions =
    list.map(questions, fn(q) {
      let assert [question_text, correct, ..answers] = string.split(q, "\n")

      let answers =
        answers
        |> list.length
        |> list.range(1)
        |> list.reverse
        |> list.zip(answers)
        |> list.map(fn(a) {
          let #(id, text) = a
          Answer(id, text)
        })

      #(question_text, correct, answers)
    })

  let questions =
    questions
    |> list.length
    |> list.range(1)
    |> list.reverse
    |> list.zip(questions)
    |> list.map(fn(q) {
      let #(id, #(question_text, correct, answers)) = q
      Question(
        id,
        question_text,
        answers,
        case int.parse(correct) {
          Ok(correct) -> correct
          Error(Nil) -> 0
        },
        None,
      )
    })

  #(Model(..model, title: title, questions: questions), get_today(model))
}

fn submit_answers(model: Model) {
  case unanswered_questions(model) {
    True -> #(model, effect.none())
    False -> #(Model(..model, submitted: True), save_results(model))
  }
}

fn select_answer(model: Model, value) {
  case string.split(value, "-") {
    [question_id, answer] -> {
      case int.parse(question_id) {
        Ok(qpos) -> {
          let questions =
            list.map(model.questions, fn(question) {
              case qpos == question.id {
                False -> question
                True ->
                  case int.parse(answer) {
                    Ok(apos) -> Question(..question, selected: Some(apos))
                    Error(Nil) -> question
                  }
              }
            })
          #(Model(..model, questions: questions), effect.none())
        }
        Error(Nil) -> #(model, effect.none())
      }
    }
    _ -> #(model, effect.none())
  }
}

fn save_results(model: Model) {
  effect.from(fn(_dispatch) {
    set_localstorage(
      date_format(model.date),
      model.questions
        |> calculate_results()
        |> encode_result()
        |> json.to_string,
    )
  })
}

fn share_results(title: String, url: String, result: QuizResult) {
  let share_data =
    json.object([
      #(
        "text",
        json.string(
          "I scored "
          <> int.to_string(result.score)
          <> "/"
          <> int.to_string(result.out_of)
          <> "  on "
          <> title
          <> "\n"
          <> share_string(result.results),
        ),
      ),
      #("url", json.string(url)),
    ])
  effect.from(fn(_dispatch) { share_results_js(share_data) })
}

fn get_today(model: Model) {
  effect.from(fn(dispatch) {
    case get_localstorage(date_format(model.date)) {
      Ok(result) -> {
        dispatch(ReadAnswers(
          result,
          calc_streak(model.date),
          count_localstorage(),
        ))
        Nil
      }
      Error(_) -> Nil
    }
  })
}

fn calc_streak(date: tempo.Date) {
  case get_localstorage(date_format(date)) {
    Error(_) -> 0
    Ok(result) -> {
      1 + calc_streak(date.subtract(date, 1))
    }
  }
}

fn encode_result(result: QuizResult) -> json.Json {
  json.object([
    #("results", json.array(result.results, of: json.bool)),
    #("answers", json.array(result.answers, of: json.int)),
    #("score", json.int(result.score)),
    #("outOf", json.int(result.out_of)),
  ])
}

@external(javascript, "./app.ffi.mjs", "share_results")
fn share_results_js(_share_data: json.Json) -> Nil {
  Nil
}

@external(javascript, "./app.ffi.mjs", "set_localstorage")
fn set_localstorage(_key: String, _value: String) -> Nil {
  Nil
}

@external(javascript, "./app.ffi.mjs", "get_localstorage")
fn get_localstorage(_key: String) -> Result(String, Nil) {
  Error(Nil)
}

@external(javascript, "./app.ffi.mjs", "count_localstorage")
fn count_localstorage() -> Int {
  0
}

fn date_format(date: tempo.Date) {
  date |> date.to_string |> string.replace("-", "")
}

fn unanswered_questions(model: Model) {
  list.any(model.questions, fn(q) { q.selected == None })
}

fn button_css(active: Bool) {
  "px-4 py-2 rounded-lg font-semibold transition "
  <> case active {
    True ->
      "bg-gray-300 text-gray-500 cursor-not-allowed opacity-60 dark:bg-slate-700 dark:text-slate-400"
    False ->
      "bg-head text-white hover:bg-purple-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-head dark:hover:bg-purple-500"
  }
}

fn button(model: Model) {
  html.button(
    [
      event.on_click(SubmitAnswers),
      attribute.class(button_css(unanswered_questions(model))),
    ],
    [html.text("Submit")],
  )
}

fn results_title(score: Int) {
  let welldone =
    case score {
      0 | 1 | 2 -> [
        "Bit of a flop!", "The industry is brutal!", "Bottom of the pops!",
        "Tomorrow's another day!", "Don't give up the day job!",
      ]
      3 | 4 | 5 -> [
        "Bubbling under!", "Must try harder!", "Keep trying!",
        "Keep on keeping on!", "Slow start, but there's something there!",
      ]
      6 | 7 | 8 -> [
        "Highest new entry!", "Bright new talent!", "Rising star!",
        "Bring it on!", "Climbing the chart!",
      ]
      9 -> [
        "Threatening the top spot!", "Almost there!", "Look out for this one!",
        "Flying high!", "Enjoying the high life!",
      ]
      10 -> [
        "Top of the chart!", "Chartbuster!", "No 1 Smash Hit!",
        "Now that's what I call a hit!", "You've made it big!",
      ]
      _ -> ["WELL DONE"]
    }
    |> list.sample(1)

  let assert [welldone] = welldone
  welldone
}

fn score_div(title: String, number: Int) {
  html.div([attribute.class("grow")], [
    html.div([attribute.class("text-3xl text-center")], [
      html.text(int.to_string(number)),
    ]),
    html.div([attribute.class("text-center")], [html.text(title)]),
  ])
}

fn result_panel(model: Model) {
  case model.show_results {
    True -> {
      let result = calculate_results(model.questions)
      html.div(
        [
          attribute.class(
            "fixed inset-0 bg-black/30 backdrop-blur-sm flex items-center justify-center z-50 text-zinc-800",
          ),
        ],
        [
          html.div(
            [
              attribute.class(
                "border-2 border-zinc-600 rounded-lg p-4 absolute bg-white",
              ),
            ],
            [
              html.header([attribute.class("flex gap-4")], [
                html.h1(
                  [
                    attribute.class(
                      "text-xl font-logo text-head font-extrabold mb-6 grow",
                    ),
                  ],
                  [html.text(results_title(result.score))],
                ),
                html.a(
                  [
                    event.on_click(ToggleResultPanel),
                    attribute.class(
                      "duration-200 active:translate-y-0.5 active:scale-95 text-lg font-bold cursor-pointer",
                    ),
                  ],
                  [html.text("✕")],
                ),
              ]),
              html.p([], [
                html.text(
                  "You scored "
                  <> int.to_string(result.score)
                  <> " out of "
                  <> int.to_string(result.out_of),
                ),
              ]),
              html.p([attribute.class("mb-6")], [
                html.text(share_string(result.results)),
              ]),
              html.div(
                [attribute.class("flex flex-row border-t border-b my-6 py-2")],
                [
                  score_div("Count", model.stats.count),
                  score_div("Streak", model.stats.streak),
                ],
              ),
              html.p([attribute.class("mb-6")], [
                html.text("A new set of questions will appear at midnight"),
              ]),
              html.div([], [
                html.button(
                  [
                    event.on_click(ShareResults),
                    attribute.class(button_css(False)),
                  ],
                  [html.text("Share")],
                ),
              ]),
            ],
          ),
        ],
      )
    }
    False -> {
      html.button(
        [event.on_click(ToggleResultPanel), attribute.class(button_css(False))],
        [html.text("Show Results")],
      )
    }
  }
}

fn calculate_results(questions: List(Question)) {
  let out_of = list.length(questions)
  let answers =
    list.map(questions, fn(q) {
      case q.selected {
        Some(answer) -> answer
        None -> panic as "Unfilled scored should never have been saved"
      }
    })
  let results = list.map(questions, fn(q) { q.selected == Some(q.correct) })
  let score = list.count(questions, fn(q) { q.selected == Some(q.correct) })
  QuizResult(results: results, answers: answers, score: score, out_of: out_of)
}

fn share_string(results: List(Bool)) {
  list.map(results, fn(x) {
    case x {
      False -> "❌"
      True -> "✅"
    }
  })
  |> string.join("")
}

fn answer_radio(question: Question, answer: Answer, submitted: Bool) {
  case
    submitted,
    question.selected == Some(answer.pos),
    question.correct == answer.pos
  {
    True, _, True -> html.text("✔️")
    True, True, False -> html.text("❌")
    True, _, _ -> html.text("")
    _, _, _ -> {
      html.input([
        attribute.type_("radio"),
        attribute.name("question-" <> int.to_string(question.id)),
        attribute.value(
          int.to_string(question.id) <> "-" <> int.to_string(answer.pos),
        ),
        event.on_input(SelectAnswer),
      ])
    }
  }
}

fn answer_div(answer: Answer, question: Question, submitted: Bool) {
  let bg = case
    submitted,
    question.selected == Some(answer.pos),
    question.correct == answer.pos
  {
    False, True, _ -> "bg-selected dark:bg-d-selected"
    True, True, True -> "bg-correct dark:bg-d-correct font-bold"
    True, True, False -> "bg-incorrect dark:bg-d-incorrect font-bold"
    _, _, _ ->
      "bg-question dark:bg-d-question hover:bg-question-hover dark:hover:bg-d-question-hover cursor-pointer"
  }

  html.label([attribute.class("block w-full flex duration-200 p-2 " <> bg)], [
    html.span([attribute.class("grow")], [html.text(answer.text)]),
    answer_radio(question, answer, submitted),
  ])
}

fn view(model: Model) {
  html.div([attribute.class("py-8")], [
    html.header([], [
      html.h1(
        [
          attribute.class(
            "font-logo font-[800] text-shadow-lg shadow-zinc-200 text-5xl text-head dark:d-head",
          ),
        ],
        [html.text("POPQUIZZA")],
      ),
    ]),
    html.div(
      [
        attribute.class(
          "border rounded border-gray-300 dark:border-gray-700 bg-white dark:bg-d-b p-4 font-semibold my-4",
        ),
      ],
      [
        html.text(
          "Official launch on Wednesday 23 April 2025! Pop back then for real questions! ",
        ),
      ],
    ),
    html.main([], [
      html.h2(
        [attribute.class("text-xl font-bold text-subhead dark:text-d-subhead")],
        [html.text(model.title)],
      ),
      html.h2(
        [
          attribute.class(
            "text-sm font-bold mb-8 text-subhead dark:text-d-subhead",
          ),
        ],
        [html.text(date.format(model.date, tempo.CustomDate("DD-MM-YY")))],
      ),
      html.div(
        [attribute.class("flex flex-col gap-6 mb-4")],
        list.map(model.questions, fn(q) {
          html.div([], [
            html.h3([attribute.class("text-lg font-semibold text-head")], [
              html.text(q.text),
            ]),
            html.div(
              [attribute.class("flex flex-col gap-2")],
              list.map(q.answers, fn(answer) {
                answer_div(answer, q, model.submitted)
              }),
            ),
          ])
        }),
      ),
      case model.submitted {
        True -> result_panel(model)
        False -> button(model)
      },
    ]),
  ])
}
