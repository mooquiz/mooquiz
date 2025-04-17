module.exports = {
  content: ["./index.html", "./src/**/*.{gleam,mjs}"],
  darkMode: 'media',
  theme: {
    extend: {
			fontFamily: {
				sans: ['Inter', 'Segoe UI', 'Roboto', 'Helvetica Neue', 'Arial', 'sans-serif'],
				logo: ['Anybody', 'Fredoka', 'Poppins', 'Arial Rounded MT Bold', 'Arial', 'sans-serif'],
			},
      colors: {
        "background": "#F8FAFC",
        "d-background": "#0F172A",
        "question": "#E0E7FF",
        "d-question": "#1E293B",
        "question-hover": "#C7D2FE",
        "d-question-hover": "#334155",
        "correct": "#BBF7D0",
        "d-correct": "#14532D",
        "incorrect": "#FECACA",
        "d-incorrect": "#7F1D1D",
        "selected": "#DDD6FE",
        "d-selected": "#5B21B6",
        "head": "#7E22CE",
        "d-head": "#C084FC",
        "subhead": "#0369A1",
        "d-subhead": "#7DD3FC"
      }
		},
  },
};
