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

La préversion Cozytouch expose la programmation native pour
`climate.naia_2_micro_30_chauffage` : les actions `cozytouch.get_schedule` et
`cozytouch.set_schedule`, le calendrier
`calendar.naia_2_micro_30_programme_chauffage`, et la carte interactive
`custom:cozytouch-schedule-card`.

La ressource `/cozytouch/cozytouch-schedule-card.js` est enregistrée dans les
ressources Lovelace en mode Storage. Elle est déployée avec l'API Home Assistant,
pas par copie SMB. La carte modifie seulement la programmation native quand son
bouton Save est utilisé ; son installation ne modifie aucune plage existante.
