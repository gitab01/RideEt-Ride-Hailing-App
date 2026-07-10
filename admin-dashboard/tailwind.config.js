/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        primary: { DEFAULT: '#1A1A2E', 50: '#f0f0f8', 100: '#d1d1eb', 500: '#1A1A2E', 600: '#151528', 700: '#101023' },
        accent:  { DEFAULT: '#FFD700' },
        success: { DEFAULT: '#2E7D32' },
        danger:  { DEFAULT: '#D32F2F' },
      },
    },
  },
  plugins: [],
}
