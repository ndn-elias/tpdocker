// Règles d'eslint (le lint du code Node.js) pour le front et l'API du garage moto.
// J'ai écrit la config à la main au lieu d'installer un paquet de règles (@eslint/js) : pas de dépendance en plus.
module.exports = [
  {
    files: ["**/*.js"],
    languageOptions: {
      // Le code est en CommonJS (require / module), pas en modules ES (import / export)
      sourceType: "commonjs",
      ecmaVersion: 2022,
      // Les variables que Node fournit tout seul, sinon la règle no-undef les prendrait pour des erreurs
      globals: {
        require: "readonly",
        process: "readonly",
        console: "readonly",
        __dirname: "readonly",
        module: "writable",
      },
    },
    rules: {
      "no-undef": "error",        // variable utilisée sans être déclarée (faute de frappe)
      "no-unused-vars": "error",  // variable déclarée mais jamais utilisée
      "no-var": "error",          // const / let au lieu de var
      "prefer-const": "error",    // const quand la variable ne change jamais
      eqeqeq: "error",            // === au lieu de ==
      "no-unreachable": "error",  // code après un return
    },
  },
];
