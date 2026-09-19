# caelestia-debian

## Consideraciones y/o advertencias (**FrankenDebian**)

Oa.
Este repo ha sido creado bajo inspiración inicial de Aviralansh, pero no sé como
crear un fork y siento que se separó demasiado al nisiquiera utilizar los parches
que añadió y ver cuales faltaban 1 a 1, pero ha sido adaptado para usarse en
**Debian Testing (Forky)** o también **Sid**, habilitando la rama **experimental**, por
lo que varios paquetes que dependen de Qt6.10 se verán afectados hasta que
los de Debian Unstable se pongan las pilas y añadan Qt6.11, igual son unos
cracks unu.

## **Instalación**

Solo clona el repositorio y luego ejecuta install2.sh, si es que al finalizar
no abre caelestia-shell (ejecutando `caelestia shell -d`), ejecuta el script
ifnotinstall.sh para crear el FrankenDebian (solo si eres insistente).

```bash
git clone https://github.com/diegogc149/caelestia-debian
cd caelestia-debian
chmod +x install2.sh && chmod +x ifnotinstall.sh
bash install2.sh
```

Recuerda reiniciar y si no funciona

```bash
bash ifnotinstall.sh
```
