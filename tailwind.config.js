module.exports = {
  content: ["./index.html", "./src/**/*.{gleam,mjs}"],
  theme: {
    extend: {
			fontFamily: {
				sans: ['Inter', 'ui-sans-serif', 'system-ui'],
				logo: ['Anybody', 'ui-sans-serif',' system-ui'],
			},
		},
  },
  plugins: [],
};
