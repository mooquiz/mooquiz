module.exports = {
  content: ["./index.html", "./src/**/*.{gleam,mjs}"],
  theme: {
    extend: {
			fontFamily: {
				sans: ['Inter', 'Segoe UI', 'Roboto', 'Helvetica Neue', 'Arial', 'sans-serif'],
				logo: ['Anybody', 'Fredoka', 'Poppins', 'Arial Rounded MT Bold', 'Arial', 'sans-serif'],
			},
      colors: {
        "correct": "#BBF7D0",
        "incorrect": "#FECACA",
        "selected": "#DDD6FE",
        "card-bg": "#EEF2FF",
        "head": "#7E22CE",
        "subhead": "#0369A1",
        "question": "#0F766E",
        "text-primary": "#111827",
        "text-muted": "#6B7280",
      }
		},
  },
  plugins: [],
};
