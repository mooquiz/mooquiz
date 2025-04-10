import lustre
import lustre/element/html
import lustre/event
import lustre/effect
import lustre/attribute
import tempo
import gleam/option.{type Option, Some, None}
import gleam/string
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/int
import rsvp

const questions_dir_url = "https://raw.githubusercontent.com/mooquiz/Questions/refs/heads/main/"

type Answer {
  Answer(pos: Int, text: String)
}

type Question {
  Question(id: Int, text: String, answers: List(Answer), correct: Int, selected: Option(Int))
}

type QuizResult {
  QuizResult(results: List(Bool), answers: List(Int), score: Int, out_of: Int)
}

type Msg {
	ReadAnswers(String)
  SubmitAnswers
  SelectAnswer(String)
  GotQuestions(Result(String, rsvp.Error))
}

type Model {
  Model(title: String, submitted: Bool, questions: List(Question))
}

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

fn init(_flags) -> #(Model, effect.Effect(Msg)) {
  let model = Model(
    title: "Loading",
    submitted: False,
    questions: []
  )

  let questions_url = questions_dir_url <> date_format() <> ".txt"

  #(model, rsvp.get(questions_url, rsvp.expect_text(GotQuestions)))
} 

fn update(model: Model, msg: Msg){
  case msg {
	  ReadAnswers(answers) -> { 
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
				  let questions = attempt.answers
					|> list.zip(model.questions)
					|> list.map(fn(x) { 
					  Question(..x.1, selected: Some(x.0))
					})
					#(Model(..model, questions: questions, submitted: True), effect.none())
				}
			}
		}
    GotQuestions(Ok(file)) -> {
      let assert [title, ..questions] = file |> string.trim |> string.split("\n\n")
      let questions = list.map(questions, fn (q) {
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
            None)
        })

      #(Model(title, False, questions), get_today())
    }
    GotQuestions(Error(_)) -> #(model, effect.none())
    SubmitAnswers -> { 
      case unanswered_questions(model) {
        True -> #(model, effect.none())
        False -> #(Model(..model, submitted: True), save_results(calculate_results(model.questions)))
      }
    }
    SelectAnswer(value) -> {
      case string.split(value, "-") {
        [question_id, answer] -> {
          case int.parse(question_id) { 
            Ok(qpos) -> {
              let questions = list.map(model.questions, fn(question) {
                case qpos == question.id {
                  False -> question
                  True -> case int.parse(answer) {
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
  }
}

fn save_results(result: QuizResult) {
	effect.from(fn(_dispatch) {
		set_localstorage(date_format(), result |> encode_result |> json.to_string)
	})
}

fn get_today() {
  effect.from(fn(dispatch) {
	  case get_localstorage(date_format()) {
		  Ok(result) -> { 
			  echo result
				dispatch(ReadAnswers(result))
				Nil
			}
			Error(_) -> Nil
		}
	})
}

fn encode_result(result: QuizResult) -> json.Json {
  json.object([
    #("results", json.array(result.results, of: json.bool)),
    #("answers", json.array(result.answers, of: json.int)),
    #("score", json.int(result.score)),
    #("outOf", json.int(result.out_of)),
  ])
}

@external(javascript, "./app.ffi.mjs", "set_localstorage")
fn set_localstorage(_key: String, _value: String) -> Nil {
  Nil
}

@external(javascript, "./app.ffi.mjs", "get_localstorage")
fn get_localstorage(_key: String) -> Result(String, Nil) {
  Error(Nil)
}

fn date_format() {
  tempo.format_local(tempo.Custom("YYYYMMDD"))
}


fn unanswered_questions(model: Model) {
  list.any(model.questions, fn(q) { q.selected == None })
}

fn button(model: Model) { 
  case model.submitted {
    False -> {
      let classes = case unanswered_questions(model) {
        True -> "bg-zinc-600 cursor-not-allowed"
        False -> "active:translate-y-0.5 active:scale-95 border-zinc-600 bg-zinc-200"
      }
      html.button([
        event.on_click(SubmitAnswers),
        attribute.class("duration-200 border border-zinc-600 p-2 rounded-md " <> classes)
      ], [html.text("Submit")])
    }
    True -> result_panel(model)
  }
}

fn result_panel(model: Model) {
  let result = calculate_results(model.questions)

  html.div([
    attribute.class("border-2 border-zinc-600 rounded-lg p-4")
    ], [
      html.div([], [html.text("You scored " <> int.to_string(result.score) <> " out of " <> int.to_string(result.out_of))]),
      html.div([], [html.text(share_string(result.results))])
    ]
  )
}

fn calculate_results(questions: List(Question)) {
  let out_of = list.length(questions)
	let answers = list.map(questions, fn(q) { 
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
      True -> "✔️"
		}
	}) |> string.join("")
} 

fn answer_radio(question: Question, answer: Answer, submitted: Bool) {
  case submitted, question.selected == Some(answer.pos), question.correct == answer.pos { 
    True, _, True, -> html.text("✔️")
    True, True, False -> html.text("❌")
    True, _, _ -> html.text("")
    _, _, _ -> {
      html.input(
        [
          attribute.type_("radio"), 
          attribute.name("question-" <> int.to_string(question.id)),
          attribute.value(int.to_string(question.id) <> "-" <> int.to_string(answer.pos)),
          event.on_input(SelectAnswer)
        ]
      )
    }
  }
}

fn answer_div(answer: Answer, question: Question, submitted: Bool) {
  let bg = case submitted, question.selected == Some(answer.pos), question.correct == answer.pos { 
    False, True, _ -> "bg-blue-200"
    True, True, True, -> "bg-green-200 font-bold"
    True, True, False -> "bg-red-200 font-bold"
    True, False, True -> "bg-green-200"
    _, _, _ -> "bg-zinc-100"
  }

  html.label(
    [attribute.class("block w-full flex duration-200 p-2 " <> bg)], 
    [
      html.span([attribute.class("grow")], [html.text(answer.text)]),
      answer_radio(question, answer, submitted)
    ]
  )
}

fn view(model: Model) {
  html.div([], [
    html.main([attribute.class("max-w-2xl mx-auto p-8")], [
      html.h1([attribute.class("text-xl font-bold mb-8")], [html.text(model.title)]),
      html.div([], list.map(model.questions, fn(q) { 
        html.div([attribute.class("mb-4")], [
          html.h2([attribute.class("text-lg font-semibold")], [html.text(q.text)]),
          html.div([attribute.class("flex flex-col gap-2")], list.map(q.answers, fn(answer) {
            answer_div(answer, q, model.submitted)
          }))
        ])
      })),
      button(model)
    ])
  ])
}
