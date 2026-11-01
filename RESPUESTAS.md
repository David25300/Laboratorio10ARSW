# Laboratorio 10 — Escalabilidad serverless con Azure Functions

Escuela Colombiana de Ingeniería · Arquitecturas de Software (ARSW)

**Integrantes:**
- Santiago Cajamarca
- Sebastián González

Aquí están las evidencias, el informe y las respuestas del laboratorio. El enunciado está en el [README.md](README.md), sin cambios.

Las pruebas se hicieron el 31/10/2026 entre las 22:40 y las 23:30 (hora de Colombia, UTC‑5). Los pantallazos están en [images/respuestas/](images/respuestas/) y las salidas completas en [evidencias/](evidencias/).

---

## Resumen

- Se creó la Function App **FunctionProjectFibonacciSC** en el plan **Consumo (Windows)**, región East US 2, con Node.js 22 LTS.
- Se desplegaron dos funciones HTTP: **Fibonacci** (la iterativa del enunciado, sin cambios) y **FibonacciMemo** (nueva, recursiva con memoization).
- F(1.000.000) tarda unos 14 s en una instancia y devuelve un número de 208.988 dígitos.
- Con **10 peticiones concurrentes** desde newman respondieron las 10 (100 %, todas HTTP 200). Azure repartió la carga en **4 instancias** de forma automática. Tiempo medio 49,5 s, mínimo 14,7 s y máximo 72,6 s.
- La memoization **no sirve** en este escenario: desborda la pila para n grandes, cada instancia tiene su propia memoria y esa memoria se pierde cuando Azure apaga la instancia.

---

## Cambios respecto al enunciado (y por qué)

1. **Node.js 22 LTS y runtime 4 de Functions.** El enunciado usa Node 12 y el runtime 2, que ya no existen en Azure. El portal solo ofrece Node 22 LTS y 24 LTS. Se escogió 22 LTS. Para que el proyecto corra en el runtime 4 se hicieron tres ajustes mínimos:
   - En FunctionProject/host.json el extension bundle pasó de [1.*, 2.0.0) a [4.*, 5.0.0).
   - En .vscode/settings.json el runtime del proyecto pasó de ~2 a ~4.
   - Se eliminó FunctionProject/proxies.json, porque los proxies no existen en el runtime 4.

   El código de la función Fibonacci **no se modificó**.
2. **Plan Consumo (Windows).** El portal ahora muestra primero "Consumo flexible" y pide confirmar si uno quiere el plan de consumo clásico. Se confirmó Consumo (Windows), que es el del enunciado.
3. **Nombre de la app.** Los nombres de las Function Apps son globales en Azure, por eso se usó FunctionProjectFibonacciSC. El grupo de recursos es SCALABILITY_LAB_II, igual que en el enunciado.
4. **Despliegue.** La extensión de Azure Functions quedó instalada en VS Code (paso 2). El paquete se subió con **ZIP deploy** al sitio Kudu de la app, que es el mismo mecanismo que usa la extensión por debajo: empaqueta la carpeta FunctionProject en un zip y lo envía a /api/zipdeploy. La subida se hizo con la sesión de Azure AD del portal, porque la autenticación básica viene deshabilitada por defecto.
5. **Application Insights** quedó habilitado (viene así por defecto). Se usó para ver qué instancia atendió cada petición.

---

## Parte 0 — Escenario de calidad

- **Fuente:** un grupo de usuarios concurrentes (simulados con 10 ejecuciones de newman en paralelo).
- **Estímulo:** cada uno pide el número 1.000.000 de Fibonacci.
- **Artefacto:** la Function App de Fibonacci.
- **Ambiente:** operación normal.
- **Respuesta:** todas las peticiones se responden.
- **Medida:** 100 % de respuestas exitosas y CPU por debajo del 70 %.

Con serverless no hay una VM a la que mirarle la CPU. El que garantiza la medida es Azure: cuando las peticiones se acumulan, el controlador de escalado agrega instancias. En la prueba de la sección 5 las 10 peticiones se respondieron (100 %).

---

## 1. Creación de la Function App

Opciones de hospedaje del portal. Se escogió **Consumo (Windows)** y se confirmó el aviso:

![](images/respuestas/01-plan-consumo-windows.jpg)

Datos básicos: suscripción Azure for Students, grupo SCALABILITY_LAB_II, nombre FunctionProjectFibonacciSC, Node.js 22 LTS, East US 2.

![](images/respuestas/02-function-app-datos-basicos.jpg)

Storage: el portal crea una cuenta de almacenamiento nueva para la app (scalabilitylabiia4aa).

![](images/respuestas/03-function-app-storage.jpg)

Revisar y crear: plan ASP-SCALABILITYLABII-8029, sistema operativo Windows, SKU **Dynamic** (consumo).

![](images/respuestas/04-function-app-revisar-crear.jpg)

Implementación terminada y Function App en ejecución:

![](images/respuestas/05-implementacion-completada.jpg)

![](images/respuestas/06-function-app-creada.jpg)

---

## 2. Extensión de Azure Functions para VS Code

![](images/respuestas/07-extension-azure-functions.png)

---

## 3. Despliegue de la función

Se instalaron las dependencias (big-integer) y se empaquetó la carpeta FunctionProject en un zip. Al subirlo, Kudu muestra el despliegue como exitoso y el contenido de wwwroot:

![](images/respuestas/08-despliegue-zipdeploy-kudu.jpg)

Las dos funciones aparecen en el portal con desencadenador HTTP:

![](images/respuestas/09-funciones-desplegadas.jpg)

---

## 4. Prueba de la función en el portal

Código y prueba, método POST con cuerpo {"nth": 1000000}:

![](images/respuestas/10-prueba-portal-entrada.jpg)

Respuesta **200** con el número completo. En el log se ve que la ejecución empezó a las 03:51:23 y terminó a las 03:51:37 (UTC), unos 14 s:

![](images/respuestas/11-prueba-portal-salida.jpg)

---

## 5. Newman con 10 peticiones concurrentes (informe)

### Cómo se hizo

La colección original del laboratorio anterior hacía un GET a una VM. Se adaptó en [postman/](postman/):

- **Colección** ARSW_FUNCTIONS_FIBONACCI: un POST a https://{{host}}/api/Fibonacci con cuerpo {"nth": {{nth}}} y dos pruebas (status 200 y respuesta no vacía).
- **Entorno** [ARSW_FUNCTIONS_FIBONACCI]: host de la Function App y nth = 1000000.
- **concurrente.sh**: lanza 10 newman en paralelo, uno por petición, y espera a que terminen:

```
for i in $(seq 1 10); do
    newman run ARSW_FUNCTIONS_FIBONACCI.postman_collection.json \
        -e "[ARSW_FUNCTIONS_FIBONACCI].postman_environment.json" \
        --reporters cli,json --reporter-json-export ../evidencias/newman/peticion-$i.json \
        > ../evidencias/newman/peticion-$i.txt 2>&1 &
done
wait
```

### Resultados

![](images/respuestas/12-newman-10-concurrentes.png)

- 10 de 10 peticiones exitosas (HTTP 200, 20 de 20 pruebas OK). Ninguna falló.
- Tiempos: 1 petición en 14,7 s, 2 en 27,7 s, 2 en 30,8 s y 5 en 72,5 s.
- Media 49,5 s. Toda la prueba duró 1 min 17 s.

Para entender esos cuatro grupos de tiempos se consultó la tabla requests de Application Insights, que guarda la instancia (cloud_RoleInstance) que atendió cada petición:

![](images/respuestas/13-instancias-app-insights.jpg)

| Instancia | Peticiones | Duración |
|---|---|---|
| d386… | 1 | 13,9 s |
| 6089… | 2 | 27,2 s |
| 9189… | 2 | 30,0 s |
| 64bb… | 5 | 71,7 s |

### Interpretación

- **Azure escaló solo.** Antes de la prueba había una sola instancia caliente. Al llegar las 10 peticiones, el controlador de escalado del plan de consumo agregó instancias hasta tener 4, sin configurar nada.
- **Cada instancia atiende las peticiones de una en una.** Node.js ejecuta el cálculo en un solo hilo y el ciclo for bloquea el event loop. Por eso los tiempos son múltiplos de unos 14 s: la instancia con 1 petición tardó 14 s, las de 2 peticiones unos 28‑30 s y la de 5 peticiones unos 72 s (5 × 14 s).
- **Las 5 peticiones de la instancia 64bb… terminaron juntas.** Mientras el worker calcula una petición, el event loop está bloqueado y no alcanza a enviar la respuesta de la anterior. Todas salen cuando termina la última.
- **El reparto no fue parejo.** Las instancias nuevas tardan unos segundos en arrancar (arranque en frío), y mientras tanto el balanceador sigue mandando peticiones a las que ya existen. Por eso una instancia recibió 5 peticiones y otra solo 1.
- **Se cumple el escenario de calidad**, porque todas las peticiones se respondieron. La latencia sí empeora: la última respuesta tardó 5 veces lo que tarda una sola.
- **Comparado con el laboratorio 9:** con una VM, 4 clientes concurrentes ya producían errores ECONNRESET. Aquí 10 peticiones simultáneas se respondieron todas sin crear ni administrar VMs ni balanceador.

---

## 6. Fibonacci recursivo con memoization

### La función

La función nueva está en [FunctionProject/FibonacciMemo/index.js](FunctionProject/FibonacciMemo/index.js). La memoria (un Map) se declara **fuera** del handler para que sobreviva entre peticiones mientras la instancia siga viva:

```
var memo = new Map();

function fibonacci(n) {
    if (n <= 1)
        return bigInt(n);
    if (memo.has(n))
        return memo.get(n);

    let value = fibonacci(n - 1).add(fibonacci(n - 2));
    memo.set(n, value);
    return value;
}
```

Además del número, la respuesta trae algunos datos para el análisis: la instancia que atendió (primeros 8 caracteres de WEBSITE_INSTANCE_ID), cuántos segundos lleva vivo el proceso (uptimeSeconds), el tamaño de la memoria antes y después de la petición (memoBefore y memoAfter) y el tiempo de cálculo (timeMs). Si el cálculo falla, responde 500 con el error.

Prueba desde el portal: n = 20.000 con la memoria ya llena (memoBefore = 19.999), así que el cálculo tarda 0 ms:

![](images/respuestas/14-memo-prueba-portal.jpg)

### Pruebas

Las llamadas se hicieron con el script [evidencias/memo/probar.sh](evidencias/memo/probar.sh), que llama la función una vez por cada valor, en orden, y guarda la respuesta resumida. Las salidas completas están en [evidencias/memo/](evidencias/memo/).

![](images/respuestas/15-memo-rondas.png)

**Ronda 1 (22:56).** Todas las peticiones cayeron en la instancia 64bb3494:

- 5.000 → OK. La memoria pasó de 0 a 4.999 valores (6 ms).
- 10.000 → OK. Usa los valores guardados y llega a 9.999 (10 ms).
- 10.000 otra vez → OK en 1 ms. Todo sale de la memoria.
- 20.000 → OK, llega a 19.999 valores (37 ms).
- 1.000.000 → **error 500**: RangeError: Maximum call stack size exceeded.
- 20.000 otra vez → OK en 0 ms.

A las 22:59:55 se repitió 20.000 desde el portal (pantallazo de arriba). Respondió la misma instancia, con 19.999 valores en memoria y 0 ms.

**Ronda 2 (23:06), después de 6 minutos sin ninguna petición.** Se repitieron los mismos valores, empezando por el más grande:

- 20.000 → **error 500**: Maximum call stack size exceeded. Respondió **otra instancia** (91899f69), que tenía la memoria vacía (memoBefore = 0). La misma petición que antes tardaba 0 ms ahora falla.
- 10.000 → OK. La memoria se volvió a llenar desde 0 hasta 9.999 (14 ms).
- 5.000 y 10.000 → OK en 0 ms. Ya están en la memoria de esta instancia.
- 20.000 → OK (24 ms), ahora que la memoria tiene los valores hasta 10.000.
- 1.000.000 → error 500 otra vez.

La instancia 91899f69 llevaba 846 s viva, así que era una de las 4 que se crearon durante la prueba de newman. Nunca había recibido una petición de FibonacciMemo, por eso su memoria estaba vacía.

**Ronda 3 (23:27), después de 21 minutos sin ninguna petición.** Se repitió la ronda 2 para ver qué pasa si se espera más:

- Respondió una instancia **nueva** (79c9760f) con uptimeSeconds = 1. El proceso acababa de arrancar: fue un arranque en frío, y la primera petición tardó 1,7 s en total frente a unos 0,25 s de las demás.
- La memoria estaba vacía otra vez, y F(20.000) falló de nuevo con desbordamiento de pila.
- El resto se comportó igual que en la ronda 2: la memoria se reconstruye desde 0 y 1.000.000 sigue fallando.

Ninguna de las 4 instancias de la prueba de newman seguía viva. Azure las apagó todas por inactividad (escalado a cero).

### ¿Cuál es el comportamiento?

- **Mientras la instancia está viva y las peticiones caen en ella**, la memoization funciona: repetir un valor tarda 0‑1 ms, y los valores grandes se pueden calcular de a poco aprovechando lo guardado.
- **Después de 5 minutos sin usar la función, la memoria ya no está disponible.** A los 6 minutos la petición cayó en otra instancia que nunca había llenado su memoria. A los 21 minutos todas las instancias se habían apagado y la petición arrancó una nueva en frío. En los dos casos, una petición que antes respondía en 0 ms terminó en error 500.
- **El valor del enunciado (n = 1.000.000) nunca funciona** con el enfoque recursivo, porque desborda la pila sin importar lo que haya en la memoria.

---

## Preguntas

### ¿Qué es un Azure Function?

Es el servicio serverless de Azure para ejecutar pequeños fragmentos de código (funciones) cuando ocurre un evento. El evento es el desencadenador (trigger): una petición HTTP, un temporizador, un mensaje en una cola, un archivo nuevo en un blob, etc. Uno solo escribe la función y Azure se encarga del servidor, del sistema operativo, del escalado y de la disponibilidad. Las funciones se agrupan en una Function App, que es la unidad de despliegue, configuración y escalado. En este laboratorio la Function App FunctionProjectFibonacciSC tiene dos funciones con trigger HTTP.

### ¿Qué es serverless?

Es un modelo de computación en la nube donde el desarrollador no administra servidores. Sí hay servidores, pero el proveedor los aprovisiona, los escala y los mantiene. Sus características principales son:

- El código se ejecuta por eventos.
- El escalado es automático, incluso hasta cero instancias cuando no hay tráfico.
- Se paga por uso (ejecuciones y tiempo de cómputo) y no por máquinas encendidas.
- Las instancias son efímeras y no guardan estado entre ejecuciones de forma confiable.

Lo vimos en la prueba de newman: Azure pasó de 1 a 4 instancias sin que nosotros hiciéramos nada.

### ¿Qué es el runtime y qué implica seleccionarlo al momento de crear el Function App?

El runtime (pila del entorno en tiempo de ejecución) es el lenguaje y la versión con que se ejecutan las funciones: .NET, Node.js, Java, PowerShell, Python o un handler personalizado. Aquí se usó Node.js 22 LTS. Por debajo está además la versión del host de Functions (aquí la 4.x).

Seleccionarlo implica:

- **El worker de lenguaje** que carga el host. Cambiar de lenguaje después no es soportado, toca crear otra Function App.
- **El modelo de programación y las librerías.** Por ejemplo, el proyecto del laboratorio era del runtime 2 y para el runtime 4 hubo que actualizar el extension bundle y quitar proxies.json.
- **Qué sistemas operativos y planes hay disponibles.** Algunos lenguajes solo existen en Linux, como Python.
- **Fecha de fin de soporte.** El portal avisa que Node.js 22 llega a EOL el 30/4/2027, y después habrá que migrar. Node 12, el del enunciado, ya ni aparece.
- **Rendimiento y arranque en frío**, que cambian según el lenguaje.

### ¿Por qué es necesario crear un Storage Account de la mano de un Function App?

Porque el host de Functions necesita un almacenamiento externo y duradero, y las instancias serverless son efímeras y no tienen disco propio que persista. La cuenta de almacenamiento (setting AzureWebJobsStorage) se usa para:

- **Guardar el código de la app.** En el plan de consumo de Windows, el contenido de wwwroot vive en un recurso compartido de Azure Files (la opción "Agregar una conexión de Azure Files" del pantallazo 03). Así todas las instancias que se crean al escalar ven los mismos archivos.
- **Guardar las claves de las funciones** (function keys y host keys) en blobs.
- **Coordinar instancias:** locks y leases, por ejemplo para que un timer trigger corra en una sola instancia.
- **Manejar los triggers y bindings** de colas, blobs y Event Hubs (checkpoints).
- **Guardar el estado de Durable Functions**, si se usan.

Por eso tiene que ser una cuenta de uso general que soporte Blob, Queue, Table y Files.

### ¿Cuáles son los tipos de planes para un Function App? ¿En qué se diferencian? Ventajas y desventajas

Son las opciones que mostró el portal (pantallazo 01):

**Consumo (el que se usó).** Las instancias se crean y se destruyen según la demanda, y se paga solo por ejecuciones y GB‑s consumidos.
- Ventajas: escala a cero, así que sin tráfico no cuesta nada. Escalado automático (hasta 200 instancias en Windows). Concesión gratuita mensual. Cero administración.
- Desventajas: arranques en frío. Tiempo máximo de ejecución de 10 min (5 por defecto). Máximo 1,5 GB de memoria y una vCPU por instancia. Sin integración con redes virtuales. Microsoft ya lo considera "legado" y recomienda Consumo flexible (la versión Linux se retira en 2028).

**Consumo flexible (Flex Consumption).** Es el nuevo plan serverless recomendado.
- Ventajas: escala a cero y se paga por uso, pero escala más rápido (hasta 1000 instancias). Soporta redes virtuales, permite escoger el tamaño de memoria por instancia y tener instancias "siempre listas" para evitar el arranque en frío.
- Desventajas: solo Linux, no todos los lenguajes y regiones, y las instancias siempre listas se cobran aunque no se usen.

**Premium (Elastic Premium EP1‑EP3).** Instancias precalentadas con escalado por eventos.
- Ventajas: sin arranques en frío, instancias más potentes, ejecuciones sin límite de tiempo práctico, redes virtuales.
- Desventajas: siempre hay al menos una instancia encendida, así que se paga aunque no haya tráfico. Es bastante más caro.

**Dedicado (plan de App Service).** Las funciones corren en las mismas VMs de un plan de App Service.
- Ventajas: costo fijo y predecible. Se pueden aprovechar VMs que ya se pagan, por ejemplo junto a una web app. Sin límite de tiempo (con Always On).
- Desventajas: no escala a cero. El escalado es por métricas o manual y más lento (máximo 10‑30 instancias). Se paga aunque no haya tráfico.

**Container Apps.** Las funciones se empaquetan como contenedor y corren en Azure Container Apps.
- Ventajas: escala a cero con KEDA y se puede combinar con otros microservicios en contenedores.
- Desventajas: hay que construir y administrar la imagen del contenedor, y es más complejo.

### ¿Por qué la memoization falla o no funciona de forma correcta?

Como se vio en la sección 6, por cuatro motivos:

1. **La memoria vive en la RAM de una instancia efímera.** La variable memo existe mientras exista el proceso. En el plan de consumo, cuando la app deja de recibir peticiones un rato, Azure recicla la instancia. La siguiente petición arranca en frío con la memoria vacía. Además, al redesplegar o al reiniciar la app también se pierde.
2. **No se comparte entre instancias.** Al escalar, cada instancia tiene su propio Map. Si una petición cae en otra instancia, no encuentra nada guardado. En la prueba de newman hubo 4 instancias, o sea 4 memorias distintas.
3. **La recursión desborda la pila.** Calcular F(n) con la memoria vacía necesita unas n llamadas anidadas, y la pila de Node.js aguanta del orden de 10.000. F(1.000.000) siempre falla con RangeError: Maximum call stack size exceeded. En Azure, F(10.000) en frío sí funcionó, pero F(20.000) solo funciona si la memoria ya tiene valores cercanos, y vuelve a fallar en cuanto la memoria se pierde.
4. **Guardar todo no cabe.** F(k) tiene unos 0,694·k bits. Guardar F(1) … F(1.000.000) ocuparía unos 43 GB, y una instancia de consumo tiene como máximo 1,5 GB.

En resumen, serverless supone funciones sin estado. Si se necesita una caché, tiene que ser externa y compartida, como Azure Cache for Redis, Cosmos DB o Table Storage. Y para Fibonacci es mejor un algoritmo iterativo o de duplicación rápida, que no necesita guardar nada.

### ¿Cómo funciona el sistema de facturación de las Function App?

Depende del plan:

- **Consumo:** se cobra por número de ejecuciones (US$ 0,20 por millón) y por consumo de recursos en GB‑s (US$ 0,000016 por GB‑s). El GB‑s es la memoria usada, redondeada hacia arriba a múltiplos de 128 MB, multiplicada por la duración, con un mínimo de 100 ms por ejecución. Cada mes hay una concesión gratuita de 1 millón de ejecuciones y 400.000 GB‑s por suscripción. Sin tráfico el costo de cómputo es cero.
- **Consumo flexible:** igual, por ejecuciones y GB‑s según el tamaño de instancia escogido, con su propia concesión gratuita. Las instancias "siempre listas" se cobran por tiempo encendidas.
- **Premium:** por vCPU‑s y GB‑s de las instancias asignadas, con al menos una siempre encendida.
- **Dedicado:** el precio fijo del plan de App Service (por instancia y hora), sin importar cuántas ejecuciones haya.

En todos los casos se suman aparte la cuenta de almacenamiento (transacciones y GB guardados), Application Insights (por GB de telemetría ingerida, con 5 GB gratis al mes) y el tráfico de salida.

En este laboratorio, unas 40 ejecuciones de unos 15 s con menos de 1,5 GB son menos de 1.000 GB‑s. Eso queda dentro de la concesión gratuita, así que el cómputo costó US$ 0. Solo hay unos centavos de almacenamiento.

---

## Informe (conclusiones)

1. **Serverless cumple el escenario de calidad sin administrar infraestructura.** Las 10 peticiones concurrentes se respondieron todas. En el laboratorio 9 hizo falta crear 3 VMs, una red y un balanceador para lograr algo parecido. Aquí Azure decidió solo cuántas instancias usar (4).
2. **El escalado no es instantáneo.** Las instancias nuevas tardan en arrancar, así que las primeras peticiones se amontonan en las instancias existentes. La peor petición tardó 72 s frente a 14 s de una petición sola. Para bajar esa latencia se podría usar Premium o Flex con instancias siempre listas, o permitir más procesos de Node por instancia.
3. **El código debe ser sin estado.** La memoization en memoria funciona solo mientras una instancia sigue viva y no se comparte. En serverless el estado va en servicios externos.
4. **El costo depende del uso.** Con el plan de consumo, toda la prueba cupo en la concesión gratuita. Una VM, en cambio, se cobra todo el tiempo que esté encendida.

---

## Recursos creados

El grupo SCALABILITY_LAB_II quedó con la Function App, su plan de consumo (ASP-SCALABILITYLABII-8029), la cuenta de almacenamiento y Application Insights:

![](images/respuestas/16-grupo-recursos.jpg)

La implementación marcada como errónea es la regla de alertas "Failure Anomalies" que Application Insights intenta crear automáticamente. No afecta al laboratorio.

Al terminar las pruebas, el grupo de recursos se eliminó completo (31/10/2026) para no gastar crédito de la suscripción. Por eso la URL de la Function App que aparece en el entorno de Postman ya no responde.
