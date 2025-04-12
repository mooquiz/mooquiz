module.exports = {
  content: ["./index.html", "./src/**/*.{gleam,mjs}"],
  theme: {
    extend: {
			fontFamily: {
				sans: ['Inter', 'ui-sans-serif', 'system-ui'],
				logo: ['Anybody', 'ui-sans-serif',' system-ui'],
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
