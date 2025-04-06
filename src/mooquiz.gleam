import lustre
import lustre/element/html
import gleam/list

type Answer {
  Answer(text: String, correct: Bool)
}

type Question {
  Question(id: Int, text: String, answers: List(Answer))
}

type Model {
  Model(title: String, questions: List(Question))
}

pub fn main() {
  let app = lustre.simple(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

fn init(_flags) -> Model {
  let model = Model("Test Quiz", [
	  Question(1, 
			"Test Question One", [
				Answer("Correct Answer", True),
				Answer("Answer Two", False),
				Answer("Answer Three", False),
				Answer("Answer Four", False)
		  ]
		),
	  Question(2, 
			"Test Question Two", [
				Answer("Answer One", False),
				Answer("Correct Answer", True),
				Answer("Answer Three", False),
				Answer("Answer Four", False)
		  ]
		)
	])

	//list.map(model, mix_answers
	model
}

fn update(model, _msg){
	model
}

fn view(model: Model) {
  html.div([], [
		html.h1([], [html.text(model.title)]),
		html.div([], list.map(model.questions, fn(q) { 
		  html.div([], [
			  html.h2([], [html.text(q.text)]),
				html.ul([], list.map(q.answers, fn(answer) {
				  html.li([], [html.text(answer.text)])
				}))
			])
		})) 
	])
}
