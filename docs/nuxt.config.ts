export default defineNuxtConfig({
  extends: ['docus'],
   site: {
    name: 'Authyra',
  },
  content: {
    build: {
      markdown: {
        highlight: {
          langs: [
            'dart',
            'mermaid',
          ]
        }
      }
    }
  }
})