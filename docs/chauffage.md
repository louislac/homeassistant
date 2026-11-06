# Vue Chauffage

La vue `Chauffage` du dashboard YAML `maison-yaml` est définie dans
`dashboards/maison.yaml`. Elle utilise exclusivement les entités réellement
exposées par le thermostat Navilink Connect et la chaudière Atlantic.

## Dérogation et programmation

Le thermostat expose les préréglages `basic`, `prog` et `override`. La carte
thermostat permet de modifier la consigne ; lorsque le thermostat est en
programmation, Cozytouch traite ce changement comme une dérogation temporaire.
La vue affiche la durée restante et propose un bouton confirmé pour revenir au
préréglage `prog`.

Cozytouch installé est en version `1.4.0`. Cette version n'expose ni les
actions `cozytouch.get_schedule` / `cozytouch.set_schedule`, ni les calendriers
de programme, ni la ressource `/cozytouch/cozytouch-schedule-card.js`. Les sept
capteurs de programme Zone 1 sont donc affichés en lecture seule. La carte
officielle ne doit pas être déclarée tant qu'une version de l'intégration qui
expose ces fonctionnalités n'est pas installée et démarrée.

Une version compatible devra fournir :

- les actions `cozytouch.get_schedule` et `cozytouch.set_schedule` ;
- un calendrier de programme chauffage pour l'entité `climate` ;
- la ressource JavaScript `/cozytouch/cozytouch-schedule-card.js`, à enregistrer
  une fois comme module Lovelace.

Après une mise à niveau explicitement approuvée, remplacer la carte de lecture
seule par la carte officielle documentée par Cozytouch. Ne pas modifier les
plages existantes pendant cette opération.
