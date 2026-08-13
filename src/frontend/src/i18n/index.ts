// ============================================================
// EPUB Fordító – i18n inicializálás (magyar + angol)
// ============================================================
import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';

// A nyelvekhez tartozó fordítási szótárakat külön fájlokba szervezzük,
// így könnyű karbantartani és bővíteni az új nyelveket.
import hu from '../locales/hu.json';
import en from '../locales/en.json';

void i18n.use(initReactI18next).init({
  resources: {
    hu: { translation: hu },
    en: { translation: en },
  },
  lng: 'hu', // alapértelmezett nyelv: magyar
  fallbackLng: 'hu',
  interpolation: {
    escapeValue: false, // a React amúgy is escape-eli a szövegeket
  },
});

export default i18n;