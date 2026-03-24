Pour mon application web de démonstration "Live", l'objectif est d'offrir une expérience bac à sable (Sandbox). L'utilisateur ne doit pas seulement voir que ça marche, il doit pouvoir "casser" des trucs, inspecter les logs et comprendre la réactivité du framework.

L'app doit être divisée en trois zones interactives sur le même écran :

Zone A : L'Interface UI (Le "Front")

- Un formulaire de login classique (Credentials + Socials).
- Un bouton "Link another account" (pour tester l'Option B).
- Un bouton "Refresh Session" manuel.

Zone B : L'Inspecteur de Données (Le "State")

- Un affichage JSON en temps réel de l'objet AuthSession.
- On doit voir les linkedAccounts s'ajouter dynamiquement.
- Un badge indiquant si le token est expiré ou non.

Zone C : La Console des Plugins (Le "Bus")

- Un flux de logs qui affiche les événements du AuthEventBus.
- Exemple : [14:02] plugin_logger: onBeforeSignIn triggered.
- Exemple : [14:03] core: Session updated (New Access Token).
