# RoninDojo_x86-64
### Articulo completo en estudiobitcoin.com
- Español https://estudiobitcoin.com/como-instalar-el-nodo-ronindojo-en-un-pc-intel-o-amd-x86_64/
- Inglés https://estudiobitcoin.com/how-to-install-ronindojo-pc-intel-amd-x86_64/

## Descripción
Pasos para instalar RoninDojo en sistema con CPU Intel/AMD (x86_64)
RoninDojo es un nodo Bitcoin on-chain con las herramientas incluidas del equipo de Samourai wallet y un entorno web muy amigable y sencillo de usar que hace que la experiencia de usuario sea toda una delicia.
RoninDojo tiene dos modos para interactuar con él:
- Modo web (RoninUI) - A través de tu navegador web (siempre desde otro PC), accedes a todo un panel de gestión/administración
- Modo terminal - a través de loggearte con el usuario "ronindojo" accedes a un menú para la gestion/administración completa desde la consola del sistema linux ya sea en local (con tu pantalla, teclado y ratón) como accediendo desde otro pc a través de SSH.

Indicar que previamente antes de poder hacer uso por terminal, hay que acceder via web pues la primera vez es cuando se crea ese password al usuario "ronindojo" que será luego necesario para poder acceder desde el modo terminal, esto se vé en el paso 5 de la instalación.


### Aviso
indicar que RoninDojo en un PC no es perfecto al 100%. Se ha descubierto, gracias a pruebas de otros usuarios, cómo la opción de BackUp romperia el sistema. No hay mayor problema sino se usa, y si quieres hacer un backup del sistema, recomendaria usar herramientas como Rescuezilla: https://github.com/rescuezilla/rescuezilla


## Configuración Previa del Hardware
Un PC con procesador intel core i5 6500 o similar con un minimo de 8GB de RAM es suficientemente potente y equilibrado para mover con soltura el nodo, el salto a procesadores más actuales siempre viene bien pero no es algo que realmente se tenga una apreciación notable, sin embargo, en las unidades de disco si que es notable su rendimiento.
Máquinas o equipos a tener como referencia por su estabilidad y rendimiento y que se pueden conseguir a buen precio en el mercado como reacondicionados son:

- HP EliteDesk 800 G2/G3 
- Lenovo ThinkCentre M900
- Dell OptiPlex 7040 Mini

Video sobre cómo es el HP EliteDesk 800 G2: https://youtu.be/lp53-_6WI1A

## Configuración Previa del Hardware
La máquina tiene que disponer de dos discos, pero exactamente este tipo de discos y configurados de esa forma, la capacidad la que querais, con unos minimos, claro:
- Disco SATA (para sistema operativo, capacidad minima de 100GB)
- Disco NVMe M.2 (para datos, capacidad minima 1TB, muy recomendado 2TB)

A modo de ejemplo, pongo dos modelos de configuración, uno válido y el otro no, observar como el "no válido" son dos discos SATA, reconocidos por linux como sda y sdb. Esta última configuración se suele disponer en muchos equipos y lamentablemente, hasta el momento, no es posible hacer la instalación de RoninDojo de forma corr

### VÁLIDO
![image](https://github.com/albercoin/RoninDojo_x86-64/assets/68326029/740ccfb8-c290-40d0-b483-e656ac72811e)

### NO VÁLIDO
![image](https://github.com/albercoin/RoninDojo_x86-64/assets/68326029/b3ad6cd9-5919-46d1-95b1-284ecccfff1a)



## Paso 1 - Flashear USB con Debian 11.x (o Debian 12.x)
Descarga solo una de las dos versiones, decide entre la version 11 o la version 12 (la actual)
- Descargar la imagen de Linux Debian 11.x (actualmente 11.9)
```
https://cdimage.debian.org/mirror/cdimage/archive/11.9.0/amd64/iso-cd/debian-11.9.0-amd64-netinst.iso
```
- Descargar la imagen de Linux Debian 12.x (actualmente 12.5)
```
https://cdimage.debian.org/mirror/cdimage/release/current/amd64/iso-cd/debian-12.5.0-amd64-netinst.iso
```
- Descargar rufus USB o balena etcher para flashear la imagen de debian en el USB
```
https://rufus.ie/es/
https://github.com/pbatard/rufus/releases/latest/download/rufus-4.5p.exe

https://etcher.balena.io/#download-etcher
https://github.com/balena-io/etcher/releases/download/v1.18.11/balenaEtcher-Portable-1.18.11.exe
```
Flashear el USB, usando Rufus o Balena Etcher, la imagen de linux Debian previamente descargada.
Aqui el video con todo detalle:
https://youtu.be/xr9V_mNZw_I


## Paso 2 - Instalar Debian 11.x (o Debian 12.x)
Iniciar la máquina con el dispositivo USB y elegir instalación grafica, los puntos importantes en la instalación son:
- Nombre de equipo: RoninDojo
- Crear usuario "nodo" con password "nodo" (luego podrás cambiar el password por uno personalizado)
- Particionado de discos (Guiado - Utilizar todo el disco)
- Elegir el disco de instalación:
- -- sda si tienes una config de SATA + NVMe (el NVMe tiene que ser el disco grande para datos)
- -- sdb si tienes una config de SATA + SATA (el sda tiene que ser el disco grande para datos)
- Selección de programas (solo dejar marcadas las siguientes casillas):
- -- SSH Server
- -- Utilidades estandar del sistema

Una vez finalizada la instalación, se reinicia, y nos loggeamos con el usuario "root" y el password creado en la isntalación
instalar los siguientes paquetes
```
apt install avahi-daemon sudo curl
```
a continuación, agregamos el usuario nodo al grupo sudo
```
adduser nodo sudo
```
nos desloggeamos, cerramos sesion
```
exit
```
Puedes ver todo el proceso de instalación detallado en este video:
https://youtu.be/4SszxjOJg9M

## Paso 3 - Ejecutar script RoninOS para x86-64
Para iniciar la instalación de adaptación del sistema a RoninDojo, debemos ejecutar una preinstalación, lo haremos ejecutando la siguiente línea y desde el usuario "nodo":
```
sudo -v && curl -L https://raw.githubusercontent.com/albercoin/RoninDojo_x86-64/main/roninos_debian_x86-64.sh | sudo bash | tee roninos-debug.log
```

Esto ejecuta el script y se genera el fichero roninos-debug.log con los detalles de la ejecución del script para su revisión en caso de haber algún problema.
se puede leer el fichero con el siguiente comando (es opcional):
```
more roninos-debug.log
```

## Paso 4 - Monitorizar el servicio de Instalación RoninDojo
Una vez finalizado el script de preinstalación, automaticamente ya se activa el servicio para iniciar la instalación, que se lleva a cabo en un segundo plano y no se ve por pantalla. 
Todo el proceso, se va escribiendo en el fichero "setup.logs" ubicado en "/home/ronindojo/.logs" por eso para poder verlo hay que ejecutar:
```
tail -f /home/ronindojo/.logs/setup.logs
```
Tendrás que esperar unos 75 segundos hasta que empieces a ver por pantalla el proceso de instalación, está programado así, no te preocupes y ponte cómodo mientras...

La instalación le llevará entre unos 10 a 30 minutos, depende en gran medida de la conexión a internet y de la potencia de la máquina
Podrás saber que ha finalizado cuando veas en pantalla lo siguiente:
![image](https://github.com/albercoin/RoninDojo_x86-64/assets/68326029/76811ca2-a767-4955-a4e1-725411f0cca3)


Entonces, para volver al prompt del sistema deberás presionar las teclas CTRL + C.
Luego podrás cerrar la sesión con el comando "exit"
```
exit
```
Video de la instalación del paso 4
https://youtu.be/xr9V_mNZw_I

## Paso 5 - Primer acceso a ronindojo.local via web
Ahora, ya tienes instalado RoninDojo, es un servidor, para poder usarlo necesitas conectarte desde otro pc y finalizar el proceso de setup, esto es importante hacerlo antes de apagar RoninDojo (lo comento por si acaso) porque sino, luego podrias tener problemas
Abrir desde nuestro pc de escritorio un navegador web e introducir "ronindojo.local" para ejecutar los primeros pasos:
- Realiza el backup del password de root
- Crea la contraseña de ronindojo

![image](https://github.com/albercoin/RoninDojo_x86-64/assets/68326029/a5bbfdf7-ef09-4d8e-8036-a8f891af3c99)
Realiza el backup del password del usuario root...
![image](https://github.com/albercoin/RoninDojo_x86-64/assets/68326029/518dac50-9767-4e15-abad-faf6255ea1cc)
Crea la contraseña de ronindojo...
![image](https://github.com/albercoin/RoninDojo_x86-64/assets/68326029/487fe81a-4d1e-413c-8639-852174460c07)
Bien! una vez completado todo...
![image](https://github.com/albercoin/RoninDojo_x86-64/assets/68326029/47491363-917a-43ba-b30a-d19e066842bf)
y ya por fin... 🥳
![image](https://github.com/albercoin/RoninDojo_x86-64/assets/68326029/8a06e792-b3c5-4ac5-8d83-c4b8c4181c83)




## Paso 6 - Fin
Ahora ya está RoninDojo listo, espera a que termine de descargar la blockchain y de que el indexador electrum tambien este al dia para poder funcionar de forma óptima.

### DISFRUTALO!!!

By Albercoin con la ayuda de mi gran estimado Arkad

### #FREESAMOURAI
"La libertad del código abierto es indomable; cada intento de limitarla sólo alimenta la creatividad de miles de desarrolladores que creen en el poder del conocimiento compartido"
