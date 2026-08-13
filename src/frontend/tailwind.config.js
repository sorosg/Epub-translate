/** @type {import('tailwindcss').Config} */
// Tailwind konfiguráció az EPUB Fordító frontendjéhez.
// Egyetlen, modern sötét palettát használunk (nincs témaváltó).
// A színek igazodnak a korábbi design accent színeihez (kék, zöld, lila).
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        // Háttér és felszín árnyalatok (sötét téma)
        'bg-primary': '#0d1117',
        'bg-secondary': '#161b22',
        'bg-card': '#1c2333',
        'border-color': '#30363d',
        // Szöveg színek
        'text-primary': '#e6edf3',
        'text-secondary': '#8b949e',
        // Accent színek (a korábbi design-ból)
        accent: {
          blue: '#58a6ff',
          green: '#3fb950',
          red: '#f85149',
          yellow: '#d2991d',
          purple: '#a371f7',
        },
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', '-apple-system', 'sans-serif'],
      },
      maxWidth: {
        content: '1200px',
      },
    },
  },
  plugins: [],
};