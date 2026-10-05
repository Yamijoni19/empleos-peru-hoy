$ErrorActionPreference = "Stop"
$ruta = "C:\Users\Dell G3 Gaming\Documents\Default Project\Bloque-Tema-Blogger.txt"
$contenido = Get-Content -LiteralPath $ruta -Raw -Encoding UTF8
$ancla = "      function esEmpleo(ficha){"
$idx = $contenido.IndexOf($ancla)
if($idx -lt 0){ throw "No se encontro el ancla esEmpleo" }
$prefijo = $contenido.Substring(0, $idx)

$cola = @'
      function esEmpleo(ficha){
        return ficha.querySelector("a[data-postular], a[data-aplicar]") !== null ||
               (ficha.getAttribute("data-tipo") || "").indexOf("empleo") !== -1;
      }

      function ocultarCaducadas(ficha){
        return ficha.getAttribute("data-ocultar-caducadas") === "true" ||
               ficha.getAttribute("data-ocultar-caducadas") === "1";
      }

      function actualizarEstadosConvocatoria(){
        var hoy = new Date();
        hoy.setHours(0,0,0,0);
        var fichas = document.querySelectorAll("[data-cierre]");
        for(var i=0;i<fichas.length;i++){
          var ficha = fichas[i];
          var fin = new Date(ficha.getAttribute("data-cierre"));
          if(isNaN(fin.getTime())){ continue; }
          fin.setHours(23,59,59,999);
          var dias = Math.ceil((fin.getTime() - hoy.getTime()) / 86400000);
          var esEmpleado = esEmpleo(ficha);
          var etiqueta = ficha.querySelector("[data-estado]") || ficha;
          var boton = ficha.querySelector("a[data-postular], a[data-aplicar]");

          var textos = {
            abierta: ficha.getAttribute("data-texto-abierta") || (esEmpleado ? "Vacante vigente" : "Convocatoria abierta"),
            pronto:  ficha.getAttribute("data-texto-pronto")  || (esEmpleado ? "¡Cierra pronto!" : "¡Cierra pronto!"),
            cerrada: ficha.getAttribute("data-texto-cerrada") || (esEmpleado ? "Vacante cubierta" : "Convocatoria finalizada")
          };

          var claseVieja = "portal-abierta portal-pronto portal-cerrada";
          etiqueta.className = etiqueta.className.replace(/\bportal-(abierta|pronto|cerrada)\b/g, "").replace(/\s{2,}/g, " ").trim();

          if(dias < 0){
            etiqueta.textContent = textos.cerrada;
            etiqueta.classList.add("portal-cerrada");
            if(ocultarCaducadas(ficha)){ ficha.style.display = "none"; }
            if(boton){
              boton.classList.add("portal-boton-deshabilitado");
              boton.setAttribute("aria-disabled", "true");
              boton.removeAttribute("href");
            }
          }else if(dias <= 5){
            etiqueta.textContent = textos.pronto + " (" + dias + " día" + (dias === 1 ? "" : "s") + ")";
            etiqueta.classList.add("portal-pronto");
          }else{
            etiqueta.textContent = textos.abierta;
            etiqueta.classList.add("portal-abierta");
          }
        }
      }

      function coleccionarFiltro(selector){
        var resultados = [];
        var activos = document.querySelectorAll(selector + ".activo");
        for(var i=0;i<activos.length;i++){
          var valor = activos[i].getAttribute("data-valor");
          if(valor && resultados.indexOf(valor) === -1){ resultados.push(valor); }
        }
        return resultados;
      }

      function trimTexto(v){
        return (v && v.value !== undefined ? v.value : v || "").toString().toLowerCase().replace(/\s+/g, " ").trim();
      }

      function coincideBusqueda(ficha, termino){
        var texto = (
          ficha.getAttribute("data-beca") + " " +
          ficha.getAttribute("data-convocante") + " " +
          ficha.getAttribute("data-rama") + " " +
          ficha.getAttribute("data-cobertura") + " " +
          ficha.textContent
        ).toLowerCase();
        var partes = termino.split(" ");
        for(var i=0;i<partes.length;i++){
          if(partes[i] && texto.indexOf(partes[i]) === -1){ return false; }
        }
        return true;
      }

      function estadoTarjeta(fechaCierre){
        var fin = new Date(fechaCierre);
        if(isNaN(fin.getTime())){ return "abierta"; }
        fin.setHours(23,59,59,999);
        var hoy = new Date(); hoy.setHours(0,0,0,0);
        var dias = Math.ceil((fin.getTime() - hoy.getTime()) / 86400000);
        if(dias < 0){ return "cerrada"; }
        if(dias <= 5){ return "pronto"; }
        return "abierta";
      }

      function filtrarBecas(){
        return function(){
          var busqueda = trimTexto(document.querySelectorAll("input[data-buscador-becas]")[0]);
          var fichas = document.querySelectorAll(".portal-tarjeta[data-cierre]");
          var grupos = {
            tipo:     coleccionarFiltro("[data-familia='tipo']"),
            nivel:    coleccionarFiltro("[data-familia='nivel']"),
            rama:     coleccionarFiltro("[data-familia='rama']"),
            convocante: coleccionarFiltro("[data-familia='convocante']"),
            cobertura: coleccionarFiltro("[data-familia='cobertura']"),
            modalidad: coleccionarFiltro("[data-familia='modalidad']"),
            estado:   coleccionarFiltro("[data-familia='estado']")
          };
          var visibles = 0;

          for(var i=0;i<fichas.length;i++){
            var ficha = fichas[i];
            var ok = true;

            if(busqueda && !coincideBusqueda(ficha, busqueda)){ ok = false; }

            var estado = estadoTarjeta(ficha.getAttribute("data-cierre"));
            if(ok && grupos.estado.length && grupos.estado.indexOf(estado) === -1){ ok = false; }

            var comp = {
              tipo: ficha.getAttribute("data-tipo") || "",
              nivel: ficha.getAttribute("data-nivel") || "",
              rama: ficha.getAttribute("data-rama") || "",
              convocante: ficha.getAttribute("data-convocante") || "",
              cobertura: ficha.getAttribute("data-cobertura") || "",
              modalidad: ficha.getAttribute("data-modalidad") || ""
            };

            var familias = ["tipo","nivel","rama","convocante","cobertura","modalidad"];
            for(var k=0;k<familias.length && ok;k++){
              var fam = familias[k];
              if(grupos[fam].length && grupos[fam].indexOf(comp[fam]) === -1){ ok = false; }
            }

            ficha.style.display = ok ? "" : "none";
            if(ok){ visibles++; }
          }

          contarFiltradas(document.querySelectorAll("[data-total-becas]"), visibles);
          avisarSinResultados(visibles);
        };
      }

      function contarFiltradas(nodos, total){
        for(var i=0;i<nodos.length;i++){
          nodos[i].textContent = total;
        }
      }

      function avisarSinResultados(visibles){
        var avisos = document.querySelectorAll("[data-sin-resultados]");
        for(var i=0;i<avisos.length;i++){
          avisos[i].style.display = visibles === 0 ? "" : "none";
        }
      }

      function enlazarFiltros(){
        var grupos = document.querySelectorAll("[data-familia]");
        for(var i=0;i<grupos.length;i++){
          (function(grupo){
            grupo.addEventListener("click", function(){
              var activo = grupo.classList.contains("activo");
              var familia = grupo.getAttribute("data-familia");
              var exclusivo = grupo.getAttribute("data-unica") !== null;

              if(exclusivo){
                var mismos = document.querySelectorAll("[data-familia-grupo='" + (grupo.getAttribute("data-familia-grupo") || "") + "']");
                for(var h=0;h<mismos.length;h++){ mismos[h].classList.remove("activo"); }
              }else if(activo){
                grupo.classList.remove("activo");
                filtrarBecas()();
                return;
              }

              if(activo && exclusivo){ grupo.classList.add("activo"); }
              if(!activo){ grupo.classList.add("activo"); }
              filtrarBecas()();
            });
          })(grupos[i]);
        }
      }

      function construirMigas(){}
      function construirCompartir(){}
      function construirFlotantes(){}
      function datosEstructurados(){}
      function construirContadores(){}
      function enlazarContacto(){}
      function enlazarCabecera(){}
      function enlazarFiltrosArranque(){
        enlazarFiltros();
        filtrarBecas()();
      }

      construirMigas();
      construirCompartir();
      construirFlotantes();
      datosEstructurados();
      construirContadores();
      enlazarContacto();
      enlazarCabecera();
      actualizarEstadosConvocatoria();
      enlazarFiltrosArranque();

    })();

  }
  _cuandoListo();
})();

//]]>
</script>
'@

$nuevo = $prefijo + $cola
$nuevo = $nuevo -replace "`r`l", "`n"
[System.IO.File]::WriteAllText($ruta, $nuevo, (New-Object System.Text.UTF8Encoding($false)))
"Reescrito. Anterior longitud: $($contenido.Length) -> Nueva: $($nuevo.Length)"
