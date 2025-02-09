# Scavogl Rework v2.3.4

[EN] [translation](https://translate.google.com/translate?sl=es&tl=en&u=https://github.com/lechuga16/scavogl_rework)

Scavogl Rework es una configuración competitiva para Left 4 Dead 2, diseñada para mejorar y estructurar el modo Scavenge en un entorno más equilibrado y competitivo.

## Características

### General
- Basado en ZoneMod y otras configuraciones competitivas.

### Scavogl 2v2 y 1v1
- Incrementa el tiempo de bonificación por puntuación en Scavenge de 20 a 25 segundos.

### ScavHunter (4v4, 3v3, 2v2, 1v1)
- Mantienen las mismas características que la configuración base, pero se limitan a solo Hunters.
- Solo permite el uso de Hunters como Infectados Especiales.

## Instalación
1. T1 ZM requiere el proyecto base [L4D2-Competitive-Rework](https://github.com/SirPlease/L4D2-Competitive-Rework). Descárgalo e instálalo primero.
2. Descarga los archivos desde el [repositorio de GitHub](https://github.com/AoC-Gamers/scavogl_rework).
3. Extrae los archivos en la carpeta principal de tu servidor.
4. Configura los archivos según tus necesidades (ver [Configuración](wiki/Configuración.md)).
5. Reinicia el servidor para aplicar los cambios.

## Configuración

### Agregar modo de juego
Para habilitar *Scavogl Rework* en las votaciones del servidor, edita el archivo `addons/sourcemod/configs/matchmodes.txt` y agrega:

```plaintext
"MatchModes"
{
    "ScavOgl Rework Configs"
    {
        "scavogl"
        {
            "name" "ScavOgl Rework"
        }
        "scav3v3"
        {
            "name" "3v3 ScavOgl"
        }
        "scav2v2"
        {
            "name" "2v2 ScavOgl"
        }
        "scav1v1"
        {
            "name" "1v1 ScavOgl"
        }
    }
}
```
Luego, reinicia el servidor para aplicar los cambios.

## Contribuciones
Gracias por tu interés en contribuir a *Scavogl Rework*, Puedes reportar problemas o sugerir mejoras a través de la [página de issues](https://github.com/AoC-Gamers/scavogl_rework/issues) o enviando un *pull request* en el [repositorio de GitHub](https://github.com/AoC-Gamers/scavogl_rework/pulls).

## Licencia
*Scavogl Rework* está licenciado bajo la licencia **CC-BY-SA 3.0**. Para más información, consulta el [texto completo de la licencia](http://creativecommons.org/licenses/by-sa/3.0/legalcode).

# Copyright
*Scavogl Rework* es es una adaptación de "ScavOgl".
Todos los complementos y códigos acondicionados son de sus respectivos autores.
```
- https://github.com/SirPlease/L4D2-Competitive-Rework
- https://github.com/HouseHse/Scavogl
- https://code.google.com/archive/p/scavogl/
- https://github.com/Target5150/MoYu_Server_Stupid_Plugins/
- https://github.com/blueblur0730/modified-plugins
```

