
(function(){
  function _cuandoListo(){
    if(document.readyState === "loading"){
      document.addEventListener("DOMContentLoaded", _cuandoListo);
      return;
    }

/* =========================================================
       PORTAL DE INICIO (solo si existe #empleosGrid)
       ========================================================= */
    (function(){
      "use strict";
      try {

/* =========================================================
   CONFIGURACIâ€œN DEL PORTAL
   Cambia estas dos lÃ­neas con tus datos reales:
   - whatsapp: tu nÃºmero con cÃ³digo de paÃ­s SIN el signo +
     (ejemplo "51950123456" para PerÃº)
   - correoContacto: el correo para recibir mensajes
   ========================================================= */
window.PORTAL_CONFIG = {
  whatsapp: "",
  correoContacto: "empleosperuhoy@gmail.com",
  nombreSitio: "EMPLEOS PERÅ¡ HOY",
  dominio: "https://empleosperuhoy.blogspot.com"
};

/* El feed se pide en dos tamanos distintos:
   - primer lote pequeno (FEED_LOTE_INICIAL) para pintar la pagina ya
   - lotes grandes (FEED_LOTE) en segundo plano para filtros y sectores
   El numero total de ofertas (contador real) viene en la PRIMERA respuesta,
   no hace falta cargar todo el feed para mostrarlo. */
var FEED_URL_BASE =
"https://empleosperuhoy.blogspot.com/feeds/posts/default/-/Empleo?alt=json-in-script&orderby=published";
var FEED_URL_INICIAL = 18;
var FEED_URL_LOTE = 150;
var FEED_CALLBACK = "empleosPeruHoyCallback";
var FEED_URL =
FEED_URL_BASE + "&max-results=" + FEED_URL_INICIAL + "&callback=" + FEED_CALLBACK;

var empleos = [];
var categoriaActiva = "Todos";

var LIMITE_INICIAL_EMPLEOS = 18;
var cantidadActualEMPLEOS = LIMITE_INICIAL_EMPLEOS;

(function iniciarCategoriaSEO(){
  var portal = document.querySelector(".portal-empleos");
  if(!portal){
    return;
  }
  var inicial = portal.getAttribute("data-categoria-inicial");
  if(inicial){
    categoriaActiva = inicial;
    document.querySelectorAll(".categoria-card").forEach(function(card){
      if(card.getAttribute("data-categoria") === inicial){
        card.classList.add("activa");
      }else{
        card.classList.remove("activa");
      }
    });
  }
  var sectorInicial = portal.getAttribute("data-sector-inicial");
  var sectorBase = (sectorInicial === "estado" || sectorInicial === "privado")
    ? sectorInicial
    : "privado";
  setTimeout(function(){
    aplicarSector(sectorBase);
  }, 0);
})();

var filtrosAplicados = {
  modalidad:[],
  experiencia:[],
  departamento:[],
  salario:[],
  contratante:[],
  tipoContrato:[],
  entidad:[]
};

var sectorActivo = "privado";

var busquedaActual = "";

function normalizar(texto){

  return String(texto || "")
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g,"")
    .replace(/\s+/g," ")
    .trim();

}

function textoElemento(elemento){

  if(!elemento){
    return "";
  }

  return String(
    elemento.textContent ||
    elemento.innerText ||
    ""
  ).trim();

}

function limpiarTexto(texto){

  return String(texto || "")
    .replace(/\s+/g," ")
    .trim();

}

function pasoAnuncio(grid){
  var cols = 3;
  try{
    var tc = getComputedStyle(grid).gridTemplateColumns;
    if(tc && tc !== "none"){
      cols = tc.split(" ").filter(function(s){ return s && s.trim(); }).length || 3;
    }
  }catch(e){}
  return Math.max(6, cols * 2);
}
window.pasoAnuncio = pasoAnuncio;

function insertarAnuncioEnGrid(grid, selectorTarjeta){
  if(!grid){ return; }
  var paso = pasoAnuncio(grid);
  var viejos = grid.querySelectorAll(".empleo-anuncio-feed");
  for(var v=0; v<viejos.length; v++){
    if(viejos[v].parentNode){ viejos[v].parentNode.removeChild(viejos[v]); }
  }
  var tarjetas = grid.querySelectorAll(selectorTarjeta || ".empleo-card");
  if(!tarjetas.length){ return; }
  var contador = 0;
  var ref = null;
  for(var i=0; i<tarjetas.length; i++){
    var t = tarjetas[i];
    if(t.style && t.style.display === "none"){ continue; }
    contador++;
    if(contador % paso === 0 && i < tarjetas.length - 1){
      var hueco = document.createElement("div");
      hueco.className = "empleo-anuncio empleo-anuncio-feed";
      hueco.innerHTML = '<div class="empleo-anuncio-inner">Espacio publicitario</div>';
      var sig = t.nextElementSibling;
      while(sig && sig.classList && sig.classList.contains("empleo-anuncio-feed")){
        sig = sig.nextElementSibling;
      }
      grid.insertBefore(hueco, sig);
    }
  }
}
window.insertarAnuncioEnGrid = insertarAnuncioEnGrid;

function escaparHTML(texto){

  return String(texto || "")
    .replace(/&/g,"&amp;")
    .replace(/</g,"&lt;")
    .replace(/>/g,"&gt;")
    .replace(/"/g,"&quot;")
    .replace(/'/g,"&#39;");

}

function obtenerUrlEntrada(entry){

  if(!entry){
    return "";
  }

  if(entry.link){

    for(var i=0;i<entry.link.length;i++){

      if(entry.link[i].rel === "alternate"){
        return entry.link[i].href || "";
      }

    }

  }

  return "";

}

function obtenerInfo(entry){

  if(!entry || !entry.content){
    return "";
  }

  return String(entry.content.$t || "");

}

function obtenerSeccion(entry){

  if(!entry || !entry.category){
    return "";
  }

  for(var i=0;i<entry.category.length;i++){

    var categoria =
      entry.category[i].term || "";

    if(normalizar(categoria) !== "empleo"){
      return categoria;
    }

  }

  return "";

}

/* =========================================================
   EXTRACCIâ€œN ROBUSTA DE CAMPOS
   ========================================================= */

function obtenerCampoOferta(html,nombres){

  var contenedor =
    document.createElement("div");

  contenedor.innerHTML =
    html || "";

  var nombresNormalizados =
    nombres.map(normalizar);

  var elementos =
    contenedor.querySelectorAll(
      "p,li,div,td,tr,strong,b,span"
    );

  for(var i=0;i<elementos.length;i++){

    var elemento =
      elementos[i];

    var texto =
      limpiarTexto(
        textoElemento(elemento)
      );

    if(
      !texto ||
      texto.length > 500
    ){
      continue;
    }

    var normal =
      normalizar(texto);

    for(var j=0;j<nombresNormalizados.length;j++){

      var nombre =
        nombresNormalizados[j];

      if(normal === nombre){

        var siguiente =
          elemento.nextElementSibling;

        if(siguiente){

          var valorSiguiente =
            limpiarTexto(
              textoElemento(siguiente)
            );

          if(
            valorSiguiente &&
            normalizar(valorSiguiente) !== nombre
          ){

            return valorSiguiente;

          }

        }

        var padre =
          elemento.parentElement;

        if(padre){

          var textoPadre =
            limpiarTexto(
              textoElemento(padre)
            );

          if(
            textoPadre.length > texto.length
          ){

            var resto =
              limpiarTexto(
                textoPadre
                  .replace(
                    new RegExp(
                      "^" + nombre + "\\s*[:\\-]?\\s*",
                      "i"
                    ),
                    ""
                  )
              );

            if(
              resto &&
              normalizar(resto) !== nombre
            ){

              return resto;

            }

          }

        }

      }

      if(
        normal.indexOf(
          nombre + ":"
        ) === 0
      ){

        var posicion =
          texto.indexOf(":");

        if(posicion !== -1){

          var valor =
            limpiarTexto(
              texto.substring(
                posicion + 1
              )
            );

          if(valor){
            return valor;
          }

        }

      }

      if(
        normal.indexOf(
          nombre + " -"
        ) === 0
      ){

        var posicionGuion =
          texto.indexOf("-");

        if(posicionGuion !== -1){

          var valorGuion =
            limpiarTexto(
              texto.substring(
                posicionGuion + 1
              )
            );

          if(valorGuion){
            return valorGuion;
          }

        }

      }

    }

  }

  var textoCompleto =
    limpiarTexto(
      contenedor.textContent ||
      ""
    );

  var lineas =
    textoCompleto
      .split(/\n+/)
      .map(limpiarTexto)
      .filter(Boolean);

  for(var k=0;k<lineas.length;k++){

    var linea =
      lineas[k];

    var lineaNormal =
      normalizar(linea);

    for(var z=0;z<nombresNormalizados.length;z++){

      var nombreSalario =
        nombresNormalizados[z];

      if(
        lineaNormal.indexOf(
          nombreSalario
        ) === 0
      ){

        var resultado =
          linea.replace(
            new RegExp(
              "^\\s*" +
              nombreSalario +
              "\\s*[:\\-]?\\s*",
              "i"
            ),
            ""
          );

        resultado =
          limpiarTexto(resultado);

        if(
          resultado &&
          normalizar(resultado) !==
          nombreSalario
        ){

          return resultado;

        }

        if(lineas[k+1]){

          return limpiarTexto(
            lineas[k+1]
          );

        }

      }

    }

  }

  return "";

}

function obtenerDescripcion(html){

  var contenedor =
    document.createElement("div");

  contenedor.innerHTML =
    html || "";

  var candidatos =
    contenedor.querySelectorAll(
      ".empleo-descripcion,p"
    );

  var textos = [];

  for(var i=0;i<candidatos.length;i++){

    var texto =
      limpiarTexto(
        textoElemento(candidatos[i])
      );

    var normal =
      normalizar(texto);

    if(
      texto.length > 60 &&
      normal.indexOf(
        "fecha de publicacion"
      ) !== 0 &&
      normal.indexOf(
        "fecha de cierre"
      ) !== 0 &&
      normal.indexOf(
        "vacantes:"
      ) !== 0
    ){

      textos.push(texto);

    }

  }

  if(textos.length){
    return textos.slice(0,3).join(" ");
  }

  return "Oportunidad laboral disponible en Empleos PerÃº Hoy.";

}

/* =========================================================
   CATEGORIZACIâ€œN INTELIGENTE
   ========================================================= */

function contieneCualquiera(texto,palabras){

  var t =
    normalizar(texto);

  for(var i=0;i<palabras.length;i++){

    if(
      t.indexOf(
        normalizar(palabras[i])
      ) !== -1
    ){

      return true;

    }

  }

  return false;

}

function categoriaControlada(
  valor,
  titulo,
  descripcion,
  html
){

  var v =
    normalizar(valor);

  var tituloNormal =
    normalizar(titulo);

  var descripcionNormal =
    normalizar(descripcion);

  /* =======================================================
     PRIORIDAD: la categorÃ­a DECLARADA en la entrada manda
     sobre cualquier palabra del tÃ­tulo. Ej.: "Practicante
     para el Instituto de InvestigaciÃ³n" NO pasa a EducaciÃ³n
     si la entrada dice CategorÃ­a: IngenierÃ­a.
     ======================================================= */

  if(
    contieneCualquiera(
      v,
      [
        "salud",
        "medicina",
        "enfermeria"
      ]
    )
  ){

    return "Salud";

  }

  if(
    contieneCualquiera(
      v,
      [
        "ingenieria",
        "ingeniero",
        "ingeniera",
        "arquitectura",
        "arquitecto",
        "arquitecta",
        "operaciones",
        "logistica",
        "seguridad",
        "ssoma",
        "sst",
        "hse",
        "ehs",
        "medio ambiente",
        "produccion",
        "mantenimiento",
        "procesos"
      ]
    )
  ){

    return "IngenierÃ­a";

  }

  if(
    contieneCualquiera(
      v,
      [
        "ventas",
        "venta",
        "comercial",
        "servicios"
      ]
    )
  ){

    return "Ventas y Servicios";

  }

  if(
    contieneCualquiera(
      v,
      [
        "abogado",
        "abogada",
        "derecho",
        "legal",
        "juridico",
        "juridica"
      ]
    )
  ){

    return "Derecho";

  }

  if(
    contieneCualquiera(
      v,
      [
        "administracion",
        "administrativo",
        "contabilidad",
        "finanzas",
        "recursos humanos",
        "rrhh",
        "tesoreria"
      ]
    )
  ){

    return "AdministraciÃ³n y Finanzas";

  }

  if(
    contieneCualquiera(
      v,
      [
        "educacion",
        "docencia"
      ]
    )
  ){

    return "EducaciÃ³n";

  }

  /* =======================================================
     DERECHO
     Se evalÃºa antes que AdministraciÃ³n y Finanzas.
     ======================================================= */

  if(
    contieneCualquiera(
      tituloNormal,
      [
        "abogado",
        "abogada",
        "derecho",
        "legal",
        "juridico",
        "juridica",
        "asesor legal",
        "asesora legal",
        "asesor juridico",
        "asesora juridica",
        "asesoria legal",
        "asuntos legales",
        "contratos",
        "compliance legal",
        "notaria",
        "notario",
        "procurador",
        "procuradora"
      ]
    )
  ){

    return "Derecho";

  }

  /* =======================================================
     SALUD
     ======================================================= */

  if(
    contieneCualquiera(
      tituloNormal,
      [
        "medico",
        "medica",
        "medicina",
        "enfermero",
        "enfermera",
        "enfermeria",
        "odontologo",
        "odontologa",
        "odontologia",
        "farmaceutico",
        "farmaceutica",
        "farmacia",
        "nutricionista",
        "nutricion",
        "fisioterapeuta",
        "fisioterapia",
        "obstetra",
        "obstetricia",
        "laboratorio clinico",
        "tecnologo medico",
        "psicologo",
        "psicologa",
        "psicologia",
        "salud"
      ]
    )
  ){

    return "Salud";

  }

  /* =======================================================
     INGENIERÃA
     
     Arquitectura forma parte de IngenierÃ­a.
     ======================================================= */

  if(
    contieneCualquiera(
      tituloNormal,
      [
        "ingeniero",
        "ingeniera",
        "ingenieria",
        "arquitecto",
        "arquitecta",
        "arquitectura",
        "disenador arquitectonico",
        "disenadora arquitectonica",
        "urbanismo",
        "operations",
        "operaciones",
        "jefe de operaciones",
        "supervisor de operaciones",
        "coordinador de operaciones",
        "operador de planta",
        "operaciones de planta",
        "produccion",
        "produccion industrial",
        "supervisor de produccion",
        "jefe de produccion",
        "mantenimiento",
        "mantenimiento industrial",
        "procesos",
        "ingenieria de procesos",
        "logistica",
        "logistico",
        "almacen",
        "almacenes",
        "supply chain",
        "cadena de suministro",
        "distribucion",
        "transporte",
        "ssoma",
        "sst",
        "hse",
        "ehs",
        "seguridad ocupacional",
        "seguridad y salud ocupacional",
        "prevencion de riesgos",
        "riesgos laborales",
        "medio ambiente",
        "ambiental",
        "seguridad industrial",
        "mecanico",
        "mecanica",
        "electricista",
        "electricidad",
        "electrico",
        "electrica",
        "industrial",
        "civil",
        "calidad",
        "mineria"
      ]
    )
  ){

    return "IngenierÃ­a";

  }

  /* =======================================================
     VENTAS Y SERVICIOS
     ======================================================= */

  if(
    contieneCualquiera(
      tituloNormal,
      [
        "ventas",
        "venta",
        "vendedor",
        "vendedora",
        "asesor comercial",
        "asesora comercial",
        "ejecutivo comercial",
        "ejecutiva comercial",
        "representante comercial",
        "promotor",
        "promotora",
        "comercial",
        "televentas",
        "call center",
        "atencion al cliente",
        "atencion al usuario",
        "servicio al cliente",
        "customer service",
        "cobranzas",
        "cobrador",
        "cobradora",
        "ejecutivo de cuenta",
        "ejecutiva de cuenta",
        "retail",
        "tienda",
        "restaurante",
        "hotel"
      ]
    )
  ){

    return "Ventas y Servicios";

  }

  /* =======================================================
     ADMINISTRACIâ€œN Y FINANZAS
     ======================================================= */

  if(
    contieneCualquiera(
      tituloNormal,
      [
        "administrador",
        "administradora",
        "administracion",
        "asistente administrativo",
        "asistente administrativa",
        "auxiliar administrativo",
        "auxiliar administrativa",
        "secretaria",
        "secretario",
        "recepcionista",
        "recursos humanos",
        "rrhh",
        "talento humano",
        "contador",
        "contadora",
        "contabilidad",
        "finanzas",
        "financiero",
        "financiera",
        "tesoreria",
        "tesorero",
        "tesorera",
        "compras",
        "credito",
        "creditos",
        "cobranzas administrativas",
        "auditoria",
        "auditor",
        "auditor interno"
      ]
    )
  ){

    return "AdministraciÃ³n y Finanzas";

  }

  /* =======================================================
     EDUCACIâ€œN
     ======================================================= */

  if(
    contieneCualquiera(
      tituloNormal,
      [
        "docente",
        "profesor",
        "profesora",
        "maestro",
        "maestra",
        "educacion",
        "educativo",
        "educativa",
        "pedagogia",
        "pedagogo",
        "pedagoga",
        "tutor",
        "tutora",
        "tutoria",
        "instructor",
        "instructora",
        "capacitador",
        "capacitadora",
        "capacitacion",
        "colegio",
        "universidad",
        "instituto",
        "docencia"
      ]
    )
  ){

    return "EducaciÃ³n";

  }

  /* =======================================================
     CATEGORÃA ORIGINAL DE BLOGGER COMO APOYO
     ======================================================= */

  if(
    contieneCualquiera(
      v,
      [
        "salud",
        "medicina",
        "enfermeria"
      ]
    )
  ){

    return "Salud";

  }

  if(
    contieneCualquiera(
      v,
      [
        "ingenieria",
        "ingeniero",
        "ingeniera",
        "arquitectura",
        "arquitecto",
        "arquitecta",
        "operaciones",
        "logistica",
        "seguridad",
        "ssoma",
        "sst",
        "hse",
        "ehs",
        "medio ambiente",
        "produccion",
        "mantenimiento",
        "procesos"
      ]
    )
  ){

    return "IngenierÃ­a";

  }

  if(
    contieneCualquiera(
      v,
      [
        "ventas",
        "venta",
        "comercial",
        "servicios"
      ]
    )
  ){

    return "Ventas y Servicios";

  }

  if(
    contieneCualquiera(
      v,
      [
        "abogado",
        "abogada",
        "derecho",
        "legal",
        "juridico",
        "juridica"
      ]
    )
  ){

    return "Derecho";

  }

  if(
    contieneCualquiera(
      v,
      [
        "administracion",
        "administrativo",
        "contabilidad",
        "finanzas",
        "recursos humanos",
        "rrhh",
        "tesoreria"
      ]
    )
  ){

    return "AdministraciÃ³n y Finanzas";

  }

  if(
    contieneCualquiera(
      v,
      [
        "educacion",
        "docencia"
      ]
    )
  ){

    return "EducaciÃ³n";

  }

  /* =======================================================
     EVALUACIâ€œN SECUNDARIA DEL TEXTO
     ======================================================= */

  if(
    contieneCualquiera(
      descripcionNormal,
      [
        "ingeniero",
        "ingenieria",
        "arquitectura",
        "arquitecto",
        "operaciones",
        "logistica",
        "ssoma",
        "sst",
        "hse",
        "medio ambiente",
        "seguridad ocupacional",
        "mantenimiento",
        "produccion"
      ]
    )
  ){

    return "IngenierÃ­a";

  }

  if(
    contieneCualquiera(
      descripcionNormal,
      [
        "abogado",
        "abogada",
        "derecho",
        "asesoria legal",
        "asesor legal",
        "asesora legal",
        "juridico",
        "juridica"
      ]
    )
  ){

    return "Derecho";

  }

  if(
    contieneCualquiera(
      descripcionNormal,
      [
        "docente",
        "profesor",
        "profesora",
        "educacion",
        "pedagogia"
      ]
    )
  ){

    return "EducaciÃ³n";

  }

  if(
    contieneCualquiera(
      descripcionNormal,
      [
        "administracion",
        "administrativo",
        "contabilidad",
        "finanzas",
        "recursos humanos",
        "tesoreria"
      ]
    )
  ){

    return "AdministraciÃ³n y Finanzas";

  }

  /* =======================================================
     SI NO HAY COINCIDENCIA CLARA
     ======================================================= */

  return "Otros";

}

/* =========================================================
   CIUDADES DEL PERÅ¡
   ========================================================= */

var ciudadesPeru = [
  "Lima",
  "Trujillo",
  "Arequipa",
  "Cusco",
  "Piura",
  "Chiclayo",
  "Chimbote",
  "Ica",
  "Tacna",
  "Puno",
  "Huancayo",
  "Cajamarca",
  "Ayacucho",
  "HuÃ¡nuco",
  "Tarapoto",
  "Tumbes",
  "Moquegua",
  "Iquitos",
  "Pucallpa",
  "Huaraz",
  "Sullana",
  "Talara",
  "JaÃ©n",
  "Chincha",
  "Pisco",
  "Ilo",
  "Puerto Maldonado",
  "Abancay",
  "Andahuaylas",
  "CaÃ±ete",
  "Barranca",
  "Chancay",
  "Huacho",
  "Moyobamba",
  "Chachapoyas",
  "Bagua",
  "Cerro de Pasco",
  "Huancavelica",
  "Juliaca",
  "Nazca",
  "Sechura",
  "VirÃº",
  "ChepÃ©n",
  "Pacasmayo",
  "Guadalupe",
  "Tingo MarÃ­a"
];

var departamentosPeru = [
  "Amazonas",
  "Ãncash",
  "ApurÃ­mac",
  "Arequipa",
  "Ayacucho",
  "Cajamarca",
  "Callao",
  "Cusco",
  "Huancavelica",
  "HuÃ¡nuco",
  "Ica",
  "JunÃ­n",
  "La Libertad",
  "Lambayeque",
  "Lima",
  "Loreto",
  "Madre de Dios",
  "Moquegua",
  "Pasco",
  "Piura",
  "Puno",
  "San MartÃ­n",
  "Tacna",
  "Tumbes",
  "Ucayali"
];

var ciudadADepartamento = {
  "lima":"Lima",
  "caÃ±ete":"Lima",
  "barranca":"Lima",
  "chancay":"Lima",
  "huacho":"Lima",
  "callao":"Callao",
  "trujillo":"La Libertad",
  "viru":"La Libertad",
  "chepen":"La Libertad",
  "pacasmayo":"La Libertad",
  "guadalupe":"La Libertad",
  "arequipa":"Arequipa",
  "ilo":"Arequipa",
  "cusco":"Cusco",
  "piura":"Piura",
  "sullana":"Piura",
  "talara":"Piura",
  "sechura":"Piura",
  "chiclayo":"Lambayeque",
  "chimbote":"Ãncash",
  "huaraz":"Ãncash",
  "ica":"Ica",
  "nazca":"Ica",
  "chincha":"Ica",
  "pisco":"Ica",
  "tacna":"Tacna",
  "puno":"Puno",
  "juliaca":"Puno",
  "huancayo":"JunÃ­n",
  "cajamarca":"Cajamarca",
  "jaen":"Cajamarca",
  "ayacucho":"Ayacucho",
  "huanuco":"HuÃ¡nuco",
  "tingo maria":"HuÃ¡nuco",
  "tarapoto":"San MartÃ­n",
  "moyobamba":"San MartÃ­n",
  "tumbes":"Tumbes",
  "moquegua":"Moquegua",
  "iquitos":"Loreto",
  "pucallpa":"Ucayali",
  "abancay":"ApurÃ­mac",
  "andahuaylas":"ApurÃ­mac",
  "puerto maldonado":"Madre de Dios",
  "chachapoyas":"Amazonas",
  "bagua":"Amazonas",
  "cerro de pasco":"Pasco",
  "huancavelica":"Huancavelica"
};

function contieneFrase(texto, frase){

  if(!frase){
    return false;
  }

  var escapada =
    frase.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

  var re =
    new RegExp(
      "(^|[^a-z0-9])" + escapada + "([^a-z0-9]|$)"
    );

  return re.test(texto);

}

function detectarDepartamento(ubicacion, ciudad){

  var texto =
    normalizar(ubicacion);

  var ciudadNorm =
    normalizar(ciudad);

  if(ciudadADepartamento[ciudadNorm]){
    return ciudadADepartamento[ciudadNorm];
  }

  for(var i=0;i<departamentosPeru.length;i++){

    if(
      ciudadNorm ===
      normalizar(departamentosPeru[i])
    ){
      return departamentosPeru[i];
    }

  }

  for(var j=0;j<departamentosPeru.length;j++){

    if(
      contieneFrase(
        texto,
        normalizar(departamentosPeru[j])
      )
    ){
      return departamentosPeru[j];
    }

  }

  var deptFallback =
    ciudadADepartamento[ciudadNorm] || "";

  if(
    deptFallback &&
    contieneFrase(
      texto,
      normalizar(deptFallback)
    )
  ){
    return deptFallback;
  }

  return "No especificado";

}

function detectarCiudad(ubicacion){

  var texto =
    normalizar(ubicacion);

  for(var i=0;i<ciudadesPeru.length;i++){

    if(
      contieneFrase(
        texto,
        normalizar(ciudadesPeru[i])
      )
    ){
      return ciudadesPeru[i];
    }

  }

  var partes =
    String(ubicacion || "")
      .split(",");

  if(partes.length){
    return limpiarTexto(partes[0]);
  }

  return "No especificado";

}

/* =========================================================
   EXPERIENCIA
   ========================================================= */

function analizarExperiencia(texto){

  var t =
    normalizar(texto);

  t = t.replace(
    /(\d+(?:[.,]\d+)?)\s*(dias?|semanas?|meses?)/g,
    function(m,num,unidad){
      var v =
        parseFloat(num.replace(",",".")) || 0;
      if(unidad.indexOf("mes") === 0){
        return String(v / 12);
      }
      if(unidad.indexOf("semana") === 0){
        return String(v / 52);
      }
      return String(v / 365);
    }
  );

  function rango(mi,ma){
    if(mi > 0 && mi < 1){ mi = 0; }
    if(ma > 0 && ma < 1){ ma = 1; }
    if(ma < mi){ ma = mi; }
    return { min:mi, max:ma };
  }

  if(
    !t ||
    t.indexOf("no especificado") !== -1
  ){

    return {
      texto:"No especificado",
      min:null,
      max:null,
      sin:false
    };

  }

  if(
    t.indexOf("sin experiencia") !== -1 ||
    t.indexOf("no requiere experiencia") !== -1
  ){

    return {
      texto:texto,
      min:0,
      max:0,
      sin:true
    };

  }

  var numeros =
    t.match(
      /\d+(?:[.,]\d+)?/g
    ) || [];

  if(!numeros.length){

    return {
      texto:texto,
      min:null,
      max:null,
      sin:false
    };

  }

  var valores =
    numeros.map(function(n){

      return parseFloat(
        n.replace(",",".")
      ) || 0;

    });

  var min =
    valores[0];

  var max =
    valores.length > 1
      ? valores[1]
      : valores[0];

  if(
    t.indexOf("menor a") !== -1 ||
    t.indexOf("menor que") !== -1 ||
    t.indexOf("menos de") !== -1 ||
    t.indexOf("hasta") !== -1 ||
    t.indexOf("maximo") !== -1 ||
    t.indexOf("mÃ¡ximo") !== -1 ||
    t.indexOf("no mas de") !== -1 ||
    t.indexOf("no mÃ¡s de") !== -1
  ){

    min = 0;

    max = Math.max(
      valores[0] >= 1
        ? valores[0] - 1
        : valores[0],
      0
    );

    var r = rango(min,max);

    return {
      texto:texto,
      min:r.min,
      max:r.max,
      sin:r.max === 0
    };

  }

  if(
    t.indexOf("mas de") !== -1 ||
    t.indexOf("mÃ¡s de") !== -1 ||
    t.indexOf("+") !== -1 ||
    t.indexOf("minimo") !== -1 ||
    t.indexOf("mÃ­nimo") !== -1 ||
    t.indexOf("o mas") !== -1 ||
    t.indexOf("o mÃ¡s") !== -1 ||
    t.indexOf("en adelante") !== -1 ||
    t.indexOf("al menos") !== -1
  ){
    max = 99;
  }

  var r = rango(min,max);

  return {
    texto:texto,
    min:r.min,
    max:r.max,
    sin:false
  };

}

function coincideExperiencia(
  experiencia,
  filtro
){

  if(filtro === "sin"){
    return experiencia.sin === true;
  }

  if(
    experiencia.min === null &&
    experiencia.max === null
  ){
    return false;
  }

  if(filtro === "1-2"){

    return experiencia.max >= 1 &&
           experiencia.min <= 2;

  }

  if(filtro === "3-5"){

    return experiencia.max >= 3 &&
           experiencia.min <= 5;

  }

  if(filtro === "mas5"){

    return experiencia.min >= 5 ||
           ( experiencia.max >= 6 && experiencia.min >= 3 );

  }

  return false;

}

/* =========================================================
   SALARIO
   ========================================================= */

function analizarSalario(texto){

  var t =
    limpiarTexto(texto);

  if(
    !t ||
    normalizar(t).indexOf(
      "no especificado"
    ) !== -1
  ){

    return {
      texto:"No especificado",
      min:null,
      max:null
    };

  }

  var numeros =
    t.match(
      /\d{1,3}(?:[.,]\d{3})+|\d+(?:[.,]\d+)?/g
    ) || [];

  var valores = [];

  for(var i=0;i<numeros.length;i++){

    var numero =
      numeros[i]
        .replace(/[^\d]/g,"");

    var valor =
      parseInt(numero,10);

    if(
      !isNaN(valor) &&
      valor >= 100
    ){

      valores.push(valor);

    }

  }

  if(!valores.length){

    return {
      texto:t,
      min:null,
      max:null
    };

  }

  return {
    texto:t,
    min:valores[0],
    max:
      valores.length > 1
        ? valores[1]
        : valores[0]
  };

}

function coincideSalario(
  salario,
  filtro
){

  var limite =
    parseInt(filtro,10);

  if(
    salario.max === null ||
    isNaN(limite)
  ){
    return false;
  }

  return salario.max >= limite;

}

/* =========================================================
   PALABRAS CLAVE
   ========================================================= */

function obtenerKeywords(
  html,
  titulo,
  categoria,
  descripcion
){

  var keywords =
    obtenerCampoOferta(
      html,
      [
        "Palabras clave",
        "Keywords",
        "Palabras claves"
      ]
    );

  if(keywords){
    return keywords;
  }

  return [
    titulo,
    categoria,
    descripcion
  ].join(" ");

}

/* =========================================================
   NIVEL DEL PUESTO
   ========================================================= */

function obtenerNivel(
  titulo,
  texto
){

  var t =
    normalizar(
      String(titulo || "") +
      " " +
      String(texto || "")
    );

  if(
    t.indexOf("gerente") !== -1 ||
    t.indexOf("director") !== -1 ||
    t.indexOf("jefe") !== -1
  ){
    return "gerencial";
  }

  if(
    t.indexOf("supervisor") !== -1 ||
    t.indexOf("coordinador") !== -1 ||
    t.indexOf("encargado") !== -1
  ){
    return "supervision";
  }

  if(
    t.indexOf("analista") !== -1 ||
    t.indexOf("especialista") !== -1 ||
    t.indexOf("ingeniero") !== -1 ||
    t.indexOf("ingeniera") !== -1
  ){
    return "profesional";
  }

  if(
    t.indexOf("asistente") !== -1 ||
    t.indexOf("auxiliar") !== -1 ||
    t.indexOf("practicante") !== -1
  ){
    return "asistente";
  }

  return "general";

}

/* =========================================================
   FECHAS
   ========================================================= */

function formatearFecha(valor){

  if(!valor){
    return "No especificada";
  }

  var fecha =
    new Date(valor);

  if(isNaN(fecha.getTime())){
    return "No especificada";
  }

  var dia =
    String(
      fecha.getDate()
    ).padStart(2,"0");

  var mes =
    String(
      fecha.getMonth()+1
    ).padStart(2,"0");

  var anio =
    fecha.getFullYear();

  return (
    dia +
    "/" +
    mes +
    "/" +
    anio
  );

}

function parseFechaOferta(valor){
  if(!valor){
    return null;
  }
  var s = String(valor).trim();
  if(
    !s ||
    s === "No especificada" ||
    s.indexOf("No especific") === 0
  ){
    return null;
  }
  var m = s.match(/^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})$/);
  if(m){
    return new Date(
      parseInt(m[3],10),
      parseInt(m[2],10)-1,
      parseInt(m[1],10)
    );
  }
  var d = new Date(s);
  return isNaN(d.getTime()) ? null : d;
}

function clasificarContratante(valor){
  var n = normalizar(valor);
  if(
    !n ||
    n.indexOf("no especific") === 0
  ){
    return "No especificado";
  }
  if(
    n.indexOf("estado") !== -1 ||
    n.indexOf("publico") !== -1 ||
    n.indexOf("gobierno") !== -1 ||
    n.indexOf("municipal") !== -1 ||
    n.indexOf("region") !== -1 ||
    n.indexOf("ministerio") !== -1 ||
    n.indexOf("gob.") !== -1 ||
    n.indexOf("cas 728") !== -1
  ){
    return "Estado";
  }
  if(
    n.indexOf("privad") !== -1 ||
    n.indexOf("empresa privada") !== -1
  ){
    return "Privado";
  }
  return valor;
}

function clasificarTipoContratoEstado(valor){
  var n = normalizar(valor);
  if(
    !n ||
    n.indexOf("no espec") === 0 ||
    n === "no aplica"
  ){
    return "No especificado";
  }
  // OJO: "practicas" CONTIENE la subcadena "cas"; por eso prÃ¡cticas/pasantÃ­as
  // se revisan ANTES que CAS, y CAS exige la palabra suelta (\bcas\b).
  if(
    n.indexOf("practic") !== -1 ||
    n.indexOf("pasant") !== -1
  ){
    return "PrÃ¡cticas";
  }
  if(
    /\bcas\b/.test(n) ||
    n.indexOf("contrato administrativo") !== -1
  ){
    return "CAS";
  }
  if(n.indexOf("728") !== -1){
    return "728";
  }
  if(n.indexOf("276") !== -1){
    return "276";
  }
  if(n.indexOf("servicio civil") !== -1){
    return "Servicio Civil";
  }
  if(n.indexOf("locacion") !== -1){
    return "LocaciÃ³n de servicios";
  }
  if(n.indexOf("consultoria") !== -1){
    return "ConsultorÃ­a";
  }
  return "Otro";
}

function clasificarTipoEntidad(valor){
  var n = normalizar(valor);
  if(
    !n ||
    n.indexOf("no espec") === 0 ||
    n === "no aplica"
  ){
    return "No especificado";
  }
  if(
    n.indexOf("municipal") !== -1 ||
    n.indexOf("distrital") !== -1 ||
    n.indexOf("provincial") !== -1
  ){
    return "Municipalidad";
  }
  if(
    n.indexOf("ministerio") !== -1 ||
    n.indexOf("viceministerio") !== -1
  ){
    return "Ministerio";
  }
  if(
    n.indexOf("gobierno regional") !== -1 ||
    n.indexOf("gobernacion") !== -1 ||
    n.indexOf("gob. regional") !== -1
  ){
    return "Gobierno Regional";
  }
  if(
    n.indexOf("salud") !== -1 ||
    n.indexOf("essalud") !== -1 ||
    n.indexOf("hospital") !== -1 ||
    n.indexOf("minsa") !== -1 ||
    n.indexOf("diresa") !== -1 ||
    n.indexOf("red de salud") !== -1
  ){
    return "Salud";
  }
  if(
    n.indexOf("educacion") !== -1 ||
    n.indexOf("ugel") !== -1 ||
    n.indexOf("minedu") !== -1 ||
    n.indexOf("dre") !== -1 ||
    n.indexOf("colegio") !== -1 ||
    n.indexOf("instituto") !== -1 ||
    n.indexOf("universidad") !== -1
  ){
    return "EducaciÃ³n";
  }
  return "Otra entidad";
}

/* =========================================================
   CONSTRUCCIâ€œN DEL OBJETO ESTRUCTURADO
   ========================================================= */

function construirEmpleo(entry){

  var html =
    obtenerInfo(entry);

  var titulo =
    entry.title &&
    entry.title.$t
      ? limpiarTexto(
          entry.title.$t
        )
      : "Oferta de empleo";

  var source =
    obtenerCampoOferta(
      html,
      [
        "Fuente",
        "Portal",
        "Origen"
      ]
    ) ||
    "Empleos PerÃº Hoy";

  var categoriaOriginal =
    obtenerSeccion(entry) ||
    obtenerCampoOferta(
      html,
      [
        "CategorÃ­a",
        "Categoria"
      ]
    );

  var descripcion =
    obtenerDescripcion(html);

  var categoria =
    categoriaControlada(
      categoriaOriginal,
      titulo,
      descripcion,
      html
    );

  var empresa =
    obtenerCampoOferta(
      html,
      [
        "Empresa",
        "CompaÃ±Ã­a",
        "Compania"
      ]
    ) ||
    "Empresa no especificada";

  var ubicacion =
    obtenerCampoOferta(
      html,
      [
        "UbicaciÃ³n",
        "Ubicacion",
        "Lugar"
      ]
    ) ||
    "No especificado";

  var ciudad =
    obtenerCampoOferta(
      html,
      ["Ciudad"]
    );

  if(!datoValidoEstado(ciudad)){
    ciudad =
      detectarCiudad(
        ubicacion
      ) || "No especificado";
  }

  var modalidad =
    obtenerCampoOferta(
      html,
      ["Modalidad"]
    ) ||
    "No especificado";

  var salarioTexto =
    obtenerCampoOferta(
      html,
      [
        "Salario",
        "Sueldo",
        "RemuneraciÃ³n",
        "Remuneracion",
        "RemuneraciÃ³n mensual",
        "Remuneracion mensual"
      ]
    ) ||
    "No especificado";

  var contrato =
    obtenerCampoOferta(
      html,
      [
        "Contrato",
        "Tipo de contrato"
      ]
    ) ||
    "No especificado";

  var experienciaTexto =
    obtenerCampoOferta(
      html,
      ["Experiencia"]
    ) ||
    "No especificado";

  var estudios =
    obtenerCampoOferta(
      html,
      [
        "Estudios",
        "FormaciÃ³n",
        "Formacion"
      ]
    ) ||
    "No especificado";

  var dirigidoA =
    obtenerCampoOferta(
      html,
      [
        "Dirigido a",
        "Pueden postular",
        "Perfil requerido"
      ]
    ) ||
    "No especificado";

  var vacantes =
    obtenerCampoOferta(
      html,
      [
        "Vacantes",
        "Vacantes disponibles"
      ]
    ) ||
    "No especificado";

  var jornada =
    obtenerCampoOferta(
      html,
      [
        "Jornada",
        "Horario",
        "Jornada laboral"
      ]
    ) ||
    "No especificado";

  var fechaPublicacion =
    obtenerCampoOferta(
      html,
      [
        "Fecha de publicaciÃ³n",
        "Fecha de publicacion"
      ]
    ) ||
    "No especificada";

  var fechaCierre =
    obtenerCampoOferta(
      html,
      [
        "Fecha de cierre",
        "Fecha cierre"
      ]
    ) ||
    "No especificada";

  var tipoContratante =
    clasificarContratante(
      obtenerCampoOferta(
        html,
        [
          "Tipo contratante",
          "Tipo de contratante",
          "Contratante"
        ]
      ) ||
      "No especificado"
    );

  var tipoContratoEstado =
    clasificarTipoContratoEstado(
      obtenerCampoOferta(
        html,
        [
          "Tipo de contrato Estado",
          "Tipo contrato Estado",
          "Tipo de contrato (Estado)"
        ]
      ) ||
      (
        normalizar(tipoContratante) === "estado"
          ? contrato
          : "No aplica"
      )
    );

  var tipoEntidad =
    clasificarTipoEntidad(
      obtenerCampoOferta(
        html,
        [
          "Tipo de entidad",
          "Tipo entidad",
          "Entidad"
        ]
      ) ||
      (
        normalizar(tipoContratante) === "estado"
          ? empresa
          : "No aplica"
      )
    );

  var keywords =
    obtenerKeywords(
      html,
      titulo,
      categoria,
      descripcion
    );

  var experiencia =
    analizarExperiencia(
      experienciaTexto
    );

  var salario =
    analizarSalario(
      salarioTexto
    );

  var fechaEntrada =
    entry.published &&
    entry.published.$t
      ? entry.published.$t
      : "";

  var url =
    obtenerUrlEntrada(entry);

  return {

    title:titulo,

    company:empresa,

    category:categoria,

    categoryOriginal:
      categoriaOriginal ||
      "No especificado",

    location:ubicacion,

    city:ciudad,

    department:
      detectarDepartamento(
        ubicacion,
        ciudad
      ),

    modality:modalidad,

    salary:salario.texto,

    salaryMin:salario.min,

    salaryMax:salario.max,

    contract:contrato,

    experience:
      experiencia.texto,

    experienceMin:
      experiencia.min,

    experienceMax:
      experiencia.max,

    experienceSin:
      experiencia.sin,

    studies:estudios,

    audience:dirigidoA,

    workday:jornada,

    vacancies:vacantes,

    publicationDate:
      fechaPublicacion,

    closingDate:
      fechaCierre,

    contratante:
      tipoContratante,

    tipoContratoEstado:
      tipoContratoEstado,

    tipoEntidad:
      tipoEntidad,

    description:
      descripcion,

    keywords:
      keywords,

    source:
      source,

    url:
      url,

    fechaEntrada:
      fechaEntrada,

    jobLevel:
      obtenerNivel(
        titulo,
        html
      ),

    rawHtml:
      html

  };

}

/* =========================================================
   CLASE VISUAL
   ========================================================= */

function claseCategoria(
  categoria
){

  var c =
    normalizar(categoria);

  if(c === "ingenieria"){
    return "visual-ingenieria";
  }

  if(c === "salud"){
    return "visual-salud";
  }

  if(c === "ventas y servicios"){
    return "visual-ventas-servicios";
  }

  if(c === "administracion y finanzas"){
    return "visual-administracion-finanzas";
  }

  if(c === "derecho"){
    return "visual-derecho";
  }

  if(c === "educacion"){
    return "visual-educacion";
  }

  if(c === "otros"){
    return "visual-otros";
  }

  return "visual-otros";

}

/* =========================================================
   ICONOS SVG POR CATEGORÃA
   ========================================================= */

function iconoCategoria(
  categoria
){

  var c =
    normalizar(categoria);

  if(c === "ingenieria"){

    return '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 20h16"></path><path d="M6 20V8l6-4 6 4v12"></path><path d="M9 20v-5h6v5"></path><path d="M9 10h1"></path><path d="M14 10h1"></path></svg>';

  }

  if(c === "salud"){

    return '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 21s-7-4.6-9-9.1C1.5 8.5 3.4 5 7 5c2 0 3.6 1.1 5 3 1.4-1.9 3-3 5-3 3.6 0 5.5 3.5 4 6.9C19 16.4 12 21 12 21z"></path><path d="M12 9v6"></path><path d="M9 12h6"></path></svg>';

  }

  if(c === "ventas y servicios"){

    return '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 19V5"></path><path d="M4 19h16"></path><path d="M7 15l4-4 3 2 5-6"></path><path d="M16 7h3v3"></path></svg>';

  }

  if(c === "administracion y finanzas"){

    return '<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="4" y="7" width="16" height="13" rx="2"></rect><path d="M9 7V5h6v2"></path><path d="M4 12h16"></path><path d="M10 12v2h4v-2"></path></svg>';

  }

  if(c === "derecho"){

    return '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 4v16"></path><path d="M6 7h12"></path><path d="M6 7l-3 6h6z"></path><path d="M18 7l-3 6h6z"></path><path d="M8 20h8"></path></svg>';

  }

  if(c === "educacion"){

    return '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 9l9-5 9 5-9 5z"></path><path d="M7 11.5V16c3 2 7 2 10 0v-4.5"></path><path d="M21 9v6"></path></svg>';

  }

  return '<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="8"></circle><path d="M12 8v8"></path><path d="M8 12h8"></path></svg>';

}

/* =========================================================
   CONVOCATORIAS DEL ESTADO: ICONOS Y AYUDANTES
   ========================================================= */

var SVG_ESTADO = {
  dirigido:'<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"></path><circle cx="12" cy="7" r="4"></circle></svg>',
  ubicacion:'<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M20 10c0 6-8 12-8 12s-8-6-8-12a8 8 0 0 1 16 0"></path><circle cx="12" cy="10" r="3"></circle></svg>',
  plazas:'<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path><circle cx="9" cy="7" r="4"></circle><path d="M23 21v-2a4 4 0 0 0-3-3.87"></path><path d="M16 3.13a4 4 0 0 1 0 7.75"></path></svg>',
  sueldo:'<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="8" cy="8" r="6"></circle><path d="M18.09 10.37A6 6 0 1 1 10.34 18"></path><path d="M7 6h1v4"></path><path d="m16.71 13.88.7.71-2.82 2.82"></path></svg>',
  calendario:'<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="3" y="4" width="18" height="18" rx="2"></rect><path d="M16 2v4"></path><path d="M8 2v4"></path><path d="M3 10h18"></path></svg>'
};

function datoValidoEstado(valor){
  if(!valor){
    return false;
  }

  var texto = limpiarTexto(valor);

  if(!texto){
    return false;
  }

  var normal = normalizar(texto);

  return (
    normal !== "no especificado" &&
    normal !== "no especificada" &&
    normal !== "no aplica" &&
    normal !== "no determinado" &&
    normal !== "-"
  );

}

function puestoEstado(empleo){

  var titulo = String(empleo.title || "");
  var empresa = String(empleo.company || "").trim();

  if(!titulo || !empresa){
    return titulo;
  }

  var escapada = empresa.replace(
    /[.*+?^${}()|[\]\\]/g,
    "\\$&"
  );

  var patron = new RegExp(
    "^\\s*" + escapada +
    "\\s*[:\\-\u2013\u2014>\u00BB]\\s*",
    "i"
  );

  var coincidencia = titulo.match(patron);

  if(
    coincidencia &&
    titulo.length > coincidencia[0].length
  ){
    return titulo
      .slice(coincidencia[0].length)
      .trim();
  }

  return titulo;

}

function campoEstado(icono, etiqueta, valor, claseExtra){

  if(!datoValidoEstado(valor)){
    return null;
  }

  var campo = document.createElement("span");

  campo.className =
    "estado-campo" +
    (claseExtra ? " " + claseExtra : "");

  var grafico = document.createElement("span");

  grafico.innerHTML =
    SVG_ESTADO[icono] || "";

  campo.appendChild(grafico);

  var texto = document.createElement("span");

  if(etiqueta){

    var etiquetaNegrita =
      document.createElement("b");

    etiquetaNegrita.textContent =
      etiqueta + ":";

    texto.appendChild(etiquetaNegrita);

  }

  texto.appendChild(
    document.createTextNode(" " + valor)
  );

  campo.appendChild(texto);

  return campo;

}

function filaEstado(campos){

  if(!campos.length){
    return null;
  }

  var fila = document.createElement("div");

  fila.className = "estado-fila";

  for(var f=0;f<campos.length;f++){
    fila.appendChild(campos[f]);
  }

  return fila;

}

function construirCamposEstado(empleo){

  var filas = [];

  var dirigido = campoEstado(
    "dirigido",
    "Dirigido a",
    empleo.audience,
    "estado-campo-completo"
  );

  filas.push(
    filaEstado(
      dirigido ? [dirigido] : []
    )
  );

  var ciudad = campoEstado(
    "ubicacion",
    "",
    empleo.city
  );

  var plazas = datoValidoEstado(empleo.vacancies)
    ? campoEstado(
        "plazas",
        "N\u00b0 plazas",
        limpiarTexto(empleo.vacancies)
      )
    : null;

  filas.push(
    filaEstado(
      [ciudad, plazas].filter(Boolean)
    )
  );

  var sueldo = campoEstado(
    "sueldo",
    "Sueldo",
    empleo.salary
  );

  var fechaCierre = parseFechaOferta(
    empleo.closingDate
  );

  var finaliza = fechaCierre
    ? campoEstado(
        "calendario",
        "Finaliza",
        formatearFecha(fechaCierre)
      )
    : null;

  filas.push(
    filaEstado(
      [sueldo, finaliza].filter(Boolean)
    )
  );

  filas = filas.filter(Boolean);

  if(!filas.length){
    return null;
  }

  var contenedor = document.createElement("div");

  contenedor.className = "estado-campos";

  for(var i=0;i<filas.length;i++){
    contenedor.appendChild(filas[i]);
  }

  return contenedor;

}

/* =========================================================
   TARJETA MAESTRA
   ========================================================= */

function crearTarjeta(
  empleo
){

  var esEstado =
    empleo.contratante === "Estado";

  var tarjeta =
    document.createElement("article");

  tarjeta.className =
    esEstado
      ? "empleo-card estado-card"
      : "empleo-card";

  var visual =
    document.createElement("div");

  visual.className =
    "empleo-visual " +
    claseCategoria(
      empleo.category
    );

  var etiqueta =
    document.createElement("span");

  etiqueta.className =
    "empleo-etiqueta";

  etiqueta.textContent =
    empleo.category;

  var icono =
    document.createElement("span");

  icono.className =
    "empleo-icono";

  icono.innerHTML =
    iconoCategoria(
      empleo.category
    );

  visual.appendChild(
    etiqueta
  );

  visual.appendChild(
    icono
  );

  tarjeta.setAttribute(
    "data-contratante",
    empleo.contratante || ""
  );

  var esNuevo =
    empleo.fechaEntrada &&
    (new Date().getTime() -
      new Date(
        empleo.fechaEntrada
      ).getTime()) <
      7*24*60*60*1000;

  if(esNuevo){

    var insigniaNuevo =
      document.createElement("span");

    insigniaNuevo.className =
      "empleo-nuevo";

    insigniaNuevo.textContent =
      "NUEVO";

    visual.appendChild(
      insigniaNuevo
    );

  }

  if(
    empleo.fechaEntrada ||
    empleo.closingDate
  ){

    var finCierre =
      parseFechaOferta(
        empleo.closingDate
      );

    if(!finCierre){

      finCierre =
        new Date(
          empleo.fechaEntrada
        );

      finCierre.setDate(
        finCierre.getDate() + 30
      );

    }

    if(
      !isNaN(
        finCierre.getTime()
      )
    ){

      var hoyCierre =
        new Date();
      hoyCierre.setHours(
        0,0,0,0
      );

      /* dias de calendario: 25/09 -> 29/09 = 4 dias (no 5).
         Antes se comparaba contra las 23:59:59 del dia de cierre
         con Math.ceil y redondeaba un dia mas. */
      var finDiaCierre =
        new Date(
          finCierre.getTime()
        );
      finDiaCierre.setHours(
        0,0,0,0
      );

      var diasCierre =
        Math.round(
          (
            finDiaCierre.getTime() -
            hoyCierre.getTime()
          ) / 86400000
        );

      if(
        diasCierre < 0
      ){

        tarjeta.style.display =
          "none";
        return tarjeta;

      }

      if(
        diasCierre >= 0 &&
        diasCierre <= 5
      ){

        var insigniaCierre =
          document.createElement(
            "span"
          );

        insigniaCierre.className =
          "empleo-cierre " +
          (
            diasCierre <= 2
              ? "empleo-cierre-urgente"
              : "empleo-cierre-pronto"
          );

        insigniaCierre.textContent =
          diasCierre === 0
            ? "CIERRA HOY"
            : diasCierre === 1
              ? "CIERRA MAÃ‘ANA"
              : "CIERRA EN " +
                diasCierre +
                " DÃAS";

        insigniaCierre.style.top =
          esNuevo
            ? "38px"
            : "12px";

        visual.appendChild(
          insigniaCierre
        );

      }

    }

  }

  var contenido =
    document.createElement("div");

  contenido.className =
    "empleo-contenido";

  var titulo =
    document.createElement("h3");

  titulo.className =
    esEstado
      ? "empleo-titulo estado-titulo"
      : "empleo-titulo";

  titulo.textContent =
    esEstado
      ? puestoEstado(empleo)
      : empleo.title;

  var empresa =
    document.createElement("div");

  empresa.className =
    "empleo-empresa";

  empresa.textContent =
    empleo.company;

  var datos =
    document.createElement("div");

  datos.className =
    "empleo-datos";

  if(
    empleo.city &&
    empleo.city !==
    "No especificado"
  ){

    var ciudad =
      document.createElement("span");

    ciudad.className =
      "empleo-dato";

    ciudad.textContent =
      empleo.city;

    datos.appendChild(
      ciudad
    );

  }

  if(
    empleo.modality &&
    empleo.modality !==
    "No especificado"
  ){

    var modalidad =
      document.createElement("span");

    modalidad.className =
      "empleo-dato";

    modalidad.textContent =
      empleo.modality;

    datos.appendChild(
      modalidad
    );

  }

  var salario =
    document.createElement("div");

  salario.className =
    "empleo-salario";

  salario.textContent =
    empleo.salary;

  var descripcion =
    document.createElement("div");

  descripcion.className =
    "empleo-descripcion";

  descripcion.textContent =
    empleo.description;

  var pie =
    document.createElement("div");

  pie.className =
    "empleo-pie";

  var fecha =
    document.createElement("span");

  fecha.className =
    "empleo-fecha";

  var fechaMostrar =
    empleo.fechaEntrada
      ? formatearFecha(
          empleo.fechaEntrada
        )
      : empleo.publicationDate;

  fecha.textContent =
    fechaMostrar ===
    "No especificada"
      ? ""
      : fechaMostrar;

  var boton =
    document.createElement("a");

  boton.className =
    "empleo-boton";

  boton.href =
    empleo.url || "#";

  boton.textContent =
    esEstado
      ? "VER CONVOCATORIA"
      : "VER OFERTA";

  if(empleo.url){

    boton.target =
      "_self";

  }

  if(!esEstado){

    pie.appendChild(
      fecha
    );

  }

  pie.appendChild(
    boton
  );

  contenido.appendChild(
    titulo
  );

  contenido.appendChild(
    empresa
  );

  if(esEstado){

    var camposEstadoTarjeta =
      construirCamposEstado(empleo);

    if(camposEstadoTarjeta){
      contenido.appendChild(
        camposEstadoTarjeta
      );
    }

  }else{

    contenido.appendChild(
      datos
    );

    contenido.appendChild(
      salario
    );

    contenido.appendChild(
      descripcion
    );

  }

  contenido.appendChild(
    pie
  );

  tarjeta.appendChild(
    visual
  );

  tarjeta.appendChild(
    contenido
  );

  return tarjeta;

}

/* Expone la tarjeta MAESTRA al bloque de convocatorias
   relacionadas (IIFE aparte) para que las entradas del Estado
   se pinten con la misma estructura (.empleo-card estado-card). */
window.crearTarjeta = crearTarjeta;

/* =========================================================
   TEXTO DE BÅ¡SQUEDA
   ========================================================= */

function textoBusquedaOferta(
  empleo
){

  return normalizar([

    empleo.title,
    empleo.company,
    empleo.category,
    empleo.location,
    empleo.city,
    empleo.modality,
    empleo.salary,
    empleo.contract,
    empleo.experience,
    empleo.studies,
    empleo.workday,
    empleo.vacancies,
    empleo.description,
    empleo.keywords,
    empleo.source,
    empleo.jobLevel,
    empleo.contratante

  ].join(" "));

}

function coincideBusqueda(
  empleo
){

  if(!busquedaActual){
    return true;
  }

  var contenido =
    textoBusquedaOferta(
      empleo
    );

  var palabras =
    normalizar(
      busquedaActual
    )
      .split(" ")
      .filter(function(p){
        return p.length > 1;
      });

  for(var i=0;i<palabras.length;i++){

    if(
      contenido.indexOf(
        palabras[i]
      ) === -1
    ){

      return false;

    }

  }

  return true;

}

/* =========================================================
   FILTROS
   ========================================================= */

function coincideFiltros(
  empleo
){

  if(
    filtrosAplicados.modalidad.length
  ){

    var modalidadNorm =
      normalizar(
        empleo.modality
      );

    var esMixta =
      modalidadNorm.indexOf("presencial") !== -1 &&
      modalidadNorm.indexOf("remoto") !== -1;

    var modalidadValida =
      false;

    for(
      var k=0;
      k<filtrosAplicados.modalidad.length;
      k++
    ){

      var seleccionMod =
        normalizar(
          filtrosAplicados
            .modalidad[k]
        );

      var coincide =
        seleccionMod &&
        modalidadNorm.indexOf(
          seleccionMod
        ) !== -1;

      if(
        seleccionMod === "hibrido" &&
        esMixta
      ){

        coincide = true;

      }

      if(
        coincide
      ){

        modalidadValida =
          true;

        break;

      }

    }

    if(!modalidadValida){
      return false;
    }

  }

  if(
    filtrosAplicados.departamento.length &&
    filtrosAplicados.departamento.indexOf(
      empleo.department
    ) === -1
  ){

    return false;

  }

  if(
    filtrosAplicados.experiencia.length
  ){

    var experienciaValida =
      false;

    for(
      var i=0;
      i<filtrosAplicados.experiencia.length;
      i++
    ){

      if(
        coincideExperiencia(
          {
            min:
              empleo.experienceMin,

            max:
              empleo.experienceMax,

            sin:
              empleo.experienceSin

          },
          filtrosAplicados
            .experiencia[i]
        )
      ){

        experienciaValida =
          true;

        break;

      }

    }

    if(!experienciaValida){
      return false;
    }

  }

  if(
    filtrosAplicados.salario.length
  ){

    var salarioValido =
      false;

    for(
      var j=0;
      j<filtrosAplicados.salario.length;
      j++
    ){

      if(
        coincideSalario(
          {
            min:
              empleo.salaryMin,

            max:
              empleo.salaryMax
          },
          filtrosAplicados
            .salario[j]
        )
      ){

        salarioValido =
          true;

        break;

      }

    }

    if(!salarioValido){
      return false;
    }

  }

  if(
    filtrosAplicados.contratante &&
    filtrosAplicados.contratante.length
  ){

    var contratanteNorm =
      normalizar(
        empleo.contratante
      );

    var contratanteSinEtiqueta =
      !contratanteNorm ||
      contratanteNorm.indexOf("no especific") === 0 ||
      contratanteNorm === "no aplica";

    if(!contratanteSinEtiqueta){

      var contratanteValido =
        false;

      for(
        var t=0;
        t<filtrosAplicados.contratante.length;
        t++
      ){

        var selContratante =
          normalizar(
            filtrosAplicados
              .contratante[t]
          );

        if(
          selContratante &&
          (
            contratanteNorm.indexOf(
              selContratante
            ) !== -1 ||
            (
              selContratante === "estado" &&
              (
                contratanteNorm.indexOf("publico") !== -1 ||
                contratanteNorm.indexOf("gobierno") !== -1
              )
            ) ||
            (
              selContratante === "privado" &&
              (
                contratanteNorm.indexOf("empresa") !== -1 ||
                contratanteNorm.indexOf("particular") !== -1
              )
            )
          )
        ){

          contratanteValido =
            true;

          break;

        }

      }

      if(!contratanteValido){
        return false;
      }

    }

  }

  if(
    filtrosAplicados.tipoContrato &&
    filtrosAplicados.tipoContrato.length
  ){

    var tipoContratoNorm =
      normalizar(
        empleo.tipoContratoEstado
      );

    var tipoContratoValido =
      false;

    for(
      var c=0;
      c<filtrosAplicados.tipoContrato.length;
      c++
    ){

      var selTipoContrato =
        normalizar(
          filtrosAplicados
            .tipoContrato[c]
        );

      if(
        selTipoContrato &&
        tipoContratoNorm === selTipoContrato
      ){

        tipoContratoValido =
          true;

        break;

      }

    }

    if(!tipoContratoValido){
      return false;
    }

  }

  if(
    filtrosAplicados.entidad &&
    filtrosAplicados.entidad.length
  ){

    var entidadNorm =
      normalizar(
        empleo.tipoEntidad
      );

    var entidadValida =
      false;

    for(
      var e=0;
      e<filtrosAplicados.entidad.length;
      e++
    ){

      var selEntidad =
        normalizar(
          filtrosAplicados
            .entidad[e]
        );

      if(
        selEntidad &&
        entidadNorm.indexOf(
          selEntidad
        ) !== -1
      ){

        entidadValida =
          true;

        break;

      }

    }

    if(!entidadValida){
      return false;
    }

  }

  return true;

}

function ofertaVencida(
  empleo
){

  if(
    !empleo.fechaEntrada &&
    !empleo.closingDate
  ){
    return false;
  }

  var fin = parseFechaOferta(
    empleo.closingDate
  );

  if(!fin){
    fin = new Date(
      empleo.fechaEntrada
    );
    fin.setDate(
      fin.getDate() + 30
    );
  }

  if(isNaN(fin.getTime())){
    return false;
  }

  fin.setHours(0,0,0,0);

  var hoy = new Date();
  hoy.setHours(0,0,0,0);

  return fin.getTime() < hoy.getTime();

}

function ofertaVisible(
  empleo
){

  if(
    categoriaActiva !== "Todos" &&
    empleo.category !==
    categoriaActiva
  ){

    return false;

  }

  if(ofertaVencida(empleo)){
    return false;
  }

  if(
    !coincideBusqueda(
      empleo
    )
  ){

    return false;

  }

  if(
    !coincideFiltros(
      empleo
    )
  ){

    return false;

  }

  return true;

}

/* =========================================================
   RENDER
   ========================================================= */

function render(){

  var grid =
    document.getElementById(
      "empleosGrid"
    );

  if(!grid){
    return;
  }

  var hayFiltrosYBusqueda =
    categoriaActiva !== "Todos" ||
    busquedaActual ||
    Object.keys(filtrosAplicados).some(function(k){
      return k !== "contratante" &&
        filtrosAplicados[k] &&
        filtrosAplicados[k].length;
    });

  if(
    hayFiltrosYBusqueda &&
    !window.__feedCompleto &&
    !(window.__feedEnVuelo || 0)
  ){
    arrancarCargaCompleta();
  }

  actualizarContadoresSector();

  var visibles =
    empleos.filter(
      ofertaVisible
    );

  var visiblesMostradas =
    visibles.slice(
      0,
      cantidadActualEMPLEOS
    );

  var firmaTarjetas =
    visibles.length +
    "|" +
    cantidadActualEMPLEOS +
    "|" +
    visiblesMostradas
      .map(function(e){

        return e.url || e.title;

      })
      .join("|");

  var seReescribeTarjeta =
    window.__firmaTarjetas !== firmaTarjetas;

  if(seReescribeTarjeta){

    window.__firmaTarjetas = firmaTarjetas;
    window.__ultimoEstadoVacio = "";
    grid.innerHTML = "";

  }

  var titulo =
    document.getElementById(
      "tituloResultados"
    );

  var contador =
    document.getElementById(
      "contadorResultados"
    );

  if(
    categoriaActiva ===
    "Todos"
  ){

    if(
      sectorActivo === "estado"
    ){
      titulo.textContent =
        "Convocatorias del Estado";
    }else{
      titulo.textContent =
        busquedaActual ||
        Object.keys(
          filtrosAplicados
        ).some(function(k){

          return filtrosAplicados[k]
            .length;

        })
          ? "Resultados de bÃºsqueda"
          : "Empleos del sector privado";
    }

  }else{

    titulo.textContent =
      categoriaActiva +
      (
        sectorActivo === "estado"
          ? " Â· Estado"
          : " Â· Privado"
      );

  }

  var sinFiltrosActivos =
    categoriaActiva === "Todos" &&
    !busquedaActual &&
    Object.keys(filtrosAplicados).every(function(k){
      return k === "contratante" ||
        !filtrosAplicados[k] ||
        !filtrosAplicados[k].length;
    });

  var totalSector = visibles.length;
  var nodoSector =
    document.querySelector(
      '.sector-num[data-sector-num="' +
      sectorActivo +
      '"]'
    );

  if(nodoSector){
    var desdeAtributo = parseInt(nodoSector.getAttribute("data-sector-total") || "", 10);
    if(!isNaN(desdeAtributo)){
      totalSector = desdeAtributo;
    }else{
      var desdeTexto = parseInt(nodoSector.textContent || "", 10);
      if(!isNaN(desdeTexto)){
        totalSector = desdeTexto;
      }
    }
  }

  var totalMostrado =
    (sinFiltrosActivos && !window.__feedCompleto)
      ? totalSector
      : visibles.length;

  contador.textContent =
    totalMostrado +
    (
      totalMostrado === 1
        ? " oferta encontrada"
        : " ofertas encontradas"
    );

  if(!visibles.length){

    /* REGLA: el sector activo NUNCA se cambia solo. El sitio abre en
       Privado por defecto y, si ese sector no tiene ofertas visibles,
       se dice tal cual en vez de saltar a Estado. */
    if(!window.__feedCargado){
      if(window.__ultimoEstadoVacio !== "cargando"){
        window.__ultimoEstadoVacio = "cargando";
        grid.innerHTML =
          '<div class="empleo-vacio">Cargando ofertas...</div>';
      }
      return;
    }

    if(
      !window.__feedCompleto &&
      (window.__portalTotalEmpleos || 0) >
        empleos.length
    ){
      /* Faltan datos: NO se sustituye la cuadricula por un texto de
         "cargando"; el avance vive en la linea de contadores. */
      programarCargaFondo();
      return;
    }

    if(window.__ultimoEstadoVacio !== "vacio"){

      window.__ultimoEstadoVacio = "vacio";

      var vacio =
        document.createElement(
          "div"
        );

      vacio.className =
        "empleo-vacio";

      vacio.textContent =
        (sectorActivo === "estado"
          ? "No hay convocatorias del Estado"
          : "No hay ofertas del sector privado") +
        " que coincidan con tu bÇ§squeda.";

      grid.innerHTML = "";
      grid.appendChild(
        vacio
      );

    }

    return;

  }

  var pasoAnuncios = pasoAnuncio(grid);

  if(seReescribeTarjeta){

    visiblesMostradas.forEach(
      function(empleo, indice){

      grid.appendChild(
        crearTarjeta(
          empleo
        )
      );

      if(
        (indice + 1) % pasoAnuncios === 0 &&
        indice !== visiblesMostradas.length - 1
      ){

        var huecoAnuncio =
          document.createElement("div");

        huecoAnuncio.className =
          "empleo-anuncio empleo-anuncio-feed";

        huecoAnuncio.innerHTML =
          '<div class="empleo-anuncio-inner">Espacio publicitario</div>';

        grid.appendChild(
          huecoAnuncio
        );

      }

    }
    );

  }

}

/* =========================================================
   CIUDADES DINÃMICAS
   ========================================================= */

function actualizarDepartamentos(){

  var contenedor =
    document.getElementById(
      "opcionesDepartamentos"
    );

  if(!contenedor){
    return;
  }

  contenedor.innerHTML =
    "";

  var departamentos = {};

  empleos.forEach(
    function(empleo){

      if(ofertaVencida(empleo)){
        return;
      }

      var departamento =
        limpiarTexto(
          empleo.department
        );

      if(
        departamento &&
        departamento !==
        "No especificado"
      ){

        departamentos[departamento] =
          (
            departamentos[departamento] ||
            0
          ) + 1;

      }

    }
  );

  var lista =
    Object.keys(
      departamentos
    ).sort(
      function(a,b){

        if(
          departamentos[b] !==
          departamentos[a]
        ){

          return
            departamentos[b] -
            departamentos[a];

        }

        return a.localeCompare(
          b
        );

      }
    );

  if(!lista.length){

    var sin =
      document.createElement(
        "div"
      );

    sin.className =
      "filtro-opcion";

    sin.textContent =
      "No hay departamentos disponibles";

    contenedor.appendChild(
      sin
    );

    return;

  }

  lista.forEach(
    function(departamento){

      var label =
        document.createElement(
          "label"
        );

      label.className =
        "filtro-opcion";

      var input =
        document.createElement(
          "input"
        );

      input.type =
        "checkbox";

      input.value =
        departamento;

      var span =
        document.createElement(
          "span"
        );

      span.textContent =
        departamento;

      label.appendChild(
        input
      );

      label.appendChild(
        span
      );

      contenedor.appendChild(
        label
      );

      input.addEventListener(
        "change",
        manejarFiltro
      );

    }
  );

}

/* =========================================================
   ESTADO VISUAL DE FILTROS
   ========================================================= */

function actualizarEstadoFiltros(){

  cantidadActualEMPLEOS = LIMITE_INICIAL_EMPLEOS;

  document.querySelectorAll(
    ".filtro-grupo"
  ).forEach(
    function(grupo){

      var tipo =
        grupo.getAttribute(
          "data-filtro"
        );

      if(tipo){

        var activo =
          filtrosAplicados[tipo] &&
          filtrosAplicados[tipo]
            .length > 0;

        if(activo){
          grupo.classList.add("tiene-seleccion");
        }else{
          grupo.classList.remove("tiene-seleccion");
        }

      }else{

        var checks = grupo.querySelectorAll(
          'input[type="checkbox"]:checked'
        );
        if(checks.length > 0){
          grupo.classList.add("tiene-seleccion");
        }else{
          grupo.classList.remove("tiene-seleccion");
        }

      }

    }
  );

}

function manejarFiltro(){

  var input =
    this;

  var grupo =
    input.closest(
      ".filtro-grupo"
    );

  if(!grupo){
    return;
  }

  var tipo =
    grupo.getAttribute(
      "data-filtro"
    );

  if(!tipo){
    return;
  }

  var seleccionados =
    grupo.querySelectorAll(
      'input[type="checkbox"]:checked'
    );

  filtrosAplicados[tipo] =
    [];

  for(
    var i=0;
    i<seleccionados.length;
    i++
  ){

    filtrosAplicados[tipo]
      .push(
        seleccionados[i].value
      );

  }

  actualizarEstadoFiltros();
  render();

}

function limpiarFiltrosSoloEstado(){

  document.querySelectorAll(
    ".filtro-solo-estado input[type='checkbox']"
  ).forEach(
    function(check){
      check.checked = false;
    }
  );

  filtrosAplicados.tipoContrato = [];
  filtrosAplicados.entidad = [];

}

function limpiarFiltrosSoloPrivado(){

  document.querySelectorAll(
    ".filtro-solo-privado input[type='checkbox']"
  ).forEach(
    function(check){
      check.checked = false;
    }
  );

  filtrosAplicados.modalidad = [];
  filtrosAplicados.experiencia = [];

}

function ocultarGruposSolo(Selector, visible){

  document.querySelectorAll(
    Selector
  ).forEach(
    function(grupo){

      if(visible){
        grupo.removeAttribute("hidden");
      }else{
        grupo.setAttribute("hidden", "");
        grupo.classList.remove(
          "abierto",
          "tiene-seleccion"
        );
      }

    }
  );

}

function aplicarSector(sector){

  sectorActivo =
    sector === "estado"
      ? "estado"
      : "privado";

  filtrosAplicados.contratante =
    sectorActivo === "estado"
      ? ["Estado"]
      : ["Privado"];

  ocultarGruposSolo(
    ".filtro-solo-estado",
    sectorActivo === "estado"
  );

  ocultarGruposSolo(
    ".filtro-solo-privado",
    sectorActivo === "privado"
  );

  if(sectorActivo !== "estado"){
    limpiarFiltrosSoloEstado();
  }

  if(sectorActivo !== "privado"){
    limpiarFiltrosSoloPrivado();
  }

  document.querySelectorAll(
    ".sector-btn"
  ).forEach(
    function(boton){
      if(
        boton.getAttribute(
          "data-sector"
        ) === sectorActivo
      ){
        boton.classList.add(
          "activa"
        );
      }else{
        boton.classList.remove(
          "activa"
        );
      }
    }
  );

  actualizarEstadoFiltros();
  render();

}

document.querySelectorAll(
  ".sector-btn"
).forEach(
  function(boton){
    boton.addEventListener(
      "click",
      function(){
        aplicarSector(
          this.getAttribute(
            "data-sector"
          ) || "privado"
        );
      }
    );
  }
);

/* =========================================================
   DROPDOWNS
   ========================================================= */

function cerrarFiltros(){

  document.querySelectorAll(
    ".filtro-grupo.abierto"
  ).forEach(
    function(grupo){

      grupo.classList.remove(
        "abierto"
      );

    }
  );

}

document.querySelectorAll(
  ".filtro-grupo-titulo"
).forEach(
  function(boton){

    boton.addEventListener(
      "click",
      function(event){

        event.stopPropagation();

        var grupo =
          this.closest(
            ".filtro-grupo"
          );

        if(
          event.target &&
          event.target.closest &&
          event.target.closest(".flecha") &&
          grupo &&
          grupo.classList.contains(
            "tiene-seleccion"
          )
        ){

          grupo.querySelectorAll(
            "input[type='checkbox']"
          ).forEach(
            function(check){
              check.checked = false;
            }
          );

          var tipo =
            grupo.getAttribute(
              "data-filtro"
            );

          if(tipo){
            filtrosAplicados[tipo] = [];
          }

          cerrarFiltros();
          actualizarEstadoFiltros();
          render();
          paginacionActualizarEstado();
          return;

        }

        var estabaAbierto =
          grupo.classList.contains(
            "abierto"
          );

        cerrarFiltros();

        if(!estabaAbierto){

          grupo.classList.add(
            "abierto"
          );

        }

      }
    );

  }
);

document.querySelectorAll(
  ".filtro-opcion input[type='checkbox']"
).forEach(
  function(input){

    if(
      input.dataset.filtroVinculado
    ){
      return;
    }

    input.dataset.filtroVinculado =
      "1";

    input.addEventListener(
      "change",
      manejarFiltro
    );

  }
);

document.addEventListener(
  "click",
  function(event){

    if(
      !event.target.closest(
        ".filtro-grupo"
      )
    ){

      cerrarFiltros();

    }

  }
);

/* =========================================================
   BÅ¡SQUEDA
   ========================================================= */

var campoBusqueda =
  document.getElementById(
    "portalBusqueda"
  );

var botonBusqueda =
  document.getElementById(
    "portalBuscar"
  );

function ejecutarBusqueda(){

  busquedaActual =
    campoBusqueda
      ? campoBusqueda.value.trim()
      : "";

  cantidadActualEMPLEOS = LIMITE_INICIAL_EMPLEOS;
  render();

}

if(campoBusqueda){

  campoBusqueda.addEventListener(
    "input",
    ejecutarBusqueda
  );

  campoBusqueda.addEventListener(
    "keydown",
    function(event){

      if(
        event.key ===
        "Enter"
      ){

        ejecutarBusqueda();

      }

    }
  );

}

if(botonBusqueda){

  botonBusqueda.addEventListener(
    "click",
    ejecutarBusqueda
  );

}

/* =========================================================
   CATEGORÃAS
   ========================================================= */

document.querySelectorAll(
  ".categoria-card"
).forEach(
  function(card){

    card.addEventListener(
      "click",
      function(){

        document.querySelectorAll(
          ".categoria-card"
        ).forEach(
          function(c){

            c.classList.remove(
              "activa"
            );

          }
        );

        this.classList.add(
          "activa"
        );

        categoriaActiva =
          this.getAttribute(
            "data-categoria"
          ) ||
          "Todos";

        cantidadActualEMPLEOS = LIMITE_INICIAL_EMPLEOS;
        render();

        var seccion =
          document.getElementById(
            "empleos-recientes"
          );

        if(seccion){

          setTimeout(
            function(){

              seccion.scrollIntoView(
                {
                  behavior:
                    "smooth",
                  block:
                    "start"
                }
              );

            },
            50
          );

        }

      }
    );

  }
);

/* =========================================================
   CARRUSEL
   ========================================================= */

var carruselCategorias =
  document.getElementById(
    "categoriasCarrusel"
  );

var anterior =
  document.getElementById(
    "categoriaAnterior"
  );

var siguiente =
  document.getElementById(
    "categoriaSiguiente"
  );

if(
  anterior &&
  carruselCategorias
){

  anterior.addEventListener(
    "click",
    function(){

      carruselCategorias.scrollBy(
        {
          left:-450,
          behavior:"smooth"
        }
      );

    }
  );

}

if(
  siguiente &&
  carruselCategorias
){

  siguiente.addEventListener(
    "click",
    function(){

      carruselCategorias.scrollBy(
        {
          left:450,
          behavior:"smooth"
        }
      );

    }
  );

}

/* =========================================================
   ARRASTRE DEL CARRUSEL
   ========================================================= */

if(carruselCategorias){

  var arrastrando =
    false;

  var inicioX =
    0;

  var scrollInicial =
    0;

  carruselCategorias.addEventListener(
    "mousedown",
    function(e){

      arrastrando =
        true;

      inicioX =
        e.pageX;

      scrollInicial =
        carruselCategorias
          .scrollLeft;

      carruselCategorias.style.cursor =
        "grabbing";

    }
  );

  carruselCategorias.addEventListener(
    "mouseleave",
    function(){

      arrastrando =
        false;

      carruselCategorias.style.cursor =
        "grab";

    }
  );

  carruselCategorias.addEventListener(
    "mouseup",
    function(){

      arrastrando =
        false;

      carruselCategorias.style.cursor =
        "grab";

    }
  );

  carruselCategorias.addEventListener(
    "mousemove",
    function(e){

      if(!arrastrando){
        return;
      }

      e.preventDefault();

      var distancia =
        e.pageX -
        inicioX;

      carruselCategorias.scrollLeft =
        scrollInicial -
        distancia;

    }
  );

}

/* =========================================================
   FEED DE BLOGGER
   ========================================================= */

window.empleosPeruHoyCallback =
function(data){

  try{

    window.__feedCargado = true;

    if(
      !data ||
      !data.feed ||
      !data.feed.entry
    ){

      if(!window.__feedPrimeraCarga){
        empleos = [];
        window.__feedPrimeraCarga = true;
      }
      window.__feedCompleto = true;
      window.__feedCargandoTodo = false;
      if((window.__feedEnVuelo || 0) > 0){
        window.__feedEnVuelo = 0;
      }

      actualizarDepartamentos();
      render();
      paginacionActualizarEstado();

      return;

    }

    var nuevos =
      data.feed.entry
        .map(
          construirEmpleo
        )
        .filter(
          function(empleo){

            return empleo &&
              empleo.title &&
              empleo.url;

          }
        );

    window.__portalTotalEmpleos =
      data.feed.openSearch$totalResults
        ? parseInt(
            data.feed.openSearch$totalResults.$t,
            10
          )
        : nuevos.length;

    if(!window.__feedPrimeraCarga){

      window.__feedPrimeraCarga = true;
      empleos = nuevos;

    }else{

      var claves = {};
      empleos.forEach(function(e){
        claves[e.url] = true;
      });
      nuevos.forEach(function(e){
        if(!claves[e.url]){
          claves[e.url] = true;
          empleos.push(e);
        }
      });

    }

    if(
      (window.__feedEnVuelo || 0) > 0
    ){
      window.__feedEnVuelo--;
    }

    if(window.__portalCargarMas){
      window.__portalCargarMas = false;
      paginacionActualizar(false);
    }

    var totalCargado =
      window.__portalTotalEmpleos || 0;

    if(
      totalCargado > 0 &&
      empleos.length >= totalCargado
    ){
      window.__feedCompleto = true;
      window.__feedCargandoTodo = false;
    }else if(totalCargado > 0){
      window.__feedCargandoTodo = true;
    }

    actualizarDepartamentos();
    actualizarEstadoFiltros();
    render();
    if(window.__feedCargandoTodo){
      programarCargaFondo();
    }
    paginacionActualizarEstado();

  }catch(error){

    console.error(
      "Error procesando ofertas:",
      error
    );

    if((window.__feedEnVuelo || 0) > 0){
      window.__feedEnVuelo--;
    }

    if(!window.__feedPrimeraCarga){
      empleos = [];
      window.__feedPrimeraCarga = true;
    }

    render();

    if(window.__feedCargandoTodo){
      programarCargaFondo();
    }
    paginacionActualizarEstado();

  }

};

/* =========================================================
   CARGAR FEED
   ========================================================= */

function cargarOfertas(){
  cargarOfertasDesde(0);
}

/* La carga de fondo se aplaza un poco para que el primer lote pinte la
   pagina sin competir con descargas grandes. Solo se programa UNA vez. */
function programarCargaFondo(){

  if(window.__feedCompleto){
    return;
  }

  if(window.__feedProgramado){
    return;
  }

  window.__feedProgramado = true;

  setTimeout(
    function(){
      window.__feedProgramado = false;
      arrancarCargaCompleta();
    },
    600
  );

}

function arrancarCargaCompleta(){

  if(window.__feedCompleto){
    return;
  }

  var total =
    window.__portalTotalEmpleos || 0;

  if(!total){
    return;
  }

  if(empleos.length >= total){
    window.__feedCompleto = true;
    window.__feedCargandoTodo = false;
    paginacionActualizarEstado();
    return;
  }

  window.__feedCargandoTodo = true;

  if(
    typeof window.__feedSiguiente !== "number" ||
    window.__feedSiguiente <= empleos.length
  ){
    window.__feedSiguiente = empleos.length + 1;
  }

  var paso = FEED_URL_LOTE;
  var enVuelo = window.__feedEnVuelo || 0;

  while(
    enVuelo < 3 &&
    window.__feedSiguiente <= total
  ){

    var desde = window.__feedSiguiente;
    window.__feedSiguiente += paso;
    enVuelo++;
    cargarOfertasDesde(desde);

  }

  window.__feedEnVuelo = enVuelo;

}

function cargarOfertasDesde(desde){

  if(
    !document.getElementById(
      "empleosGrid"
    )
  ){
    return;
  }

  var script =
    document.createElement(
      "script"
    );

  var tamanoLote =
    (desde && desde > 1)
      ? FEED_URL_LOTE
      : FEED_URL_INICIAL;

  script.src =
    FEED_URL_BASE +
    "&max-results=" + tamanoLote +
    "&start-index=" + (desde || 1) +
    "&callback=" + FEED_CALLBACK +
    "&_=" +
    new Date().getTime();

  script.async =
    true;

  script.onerror =
    function(){

      if(window.__feedCargandoTodo){

        if((window.__feedEnVuelo || 0) > 0){
          window.__feedEnVuelo--;
        }

        window.__feedReintentos =
          (window.__feedReintentos || 0) + 1;

        if(window.__feedReintentos < 12){
          setTimeout(
            arrancarCargaCompleta,
            1500
          );
        }else{
          window.__feedError = true;
          window.__feedCargandoTodo = false;
          paginacionActualizarEstado();
        }

        return;

      }

      paginacionActualizar(false);

      var grid =
        document.getElementById(
          "empleosGrid"
        );

      if(grid){

        grid.innerHTML =
          '<div class="empleo-vacio">No fue posible cargar las ofertas en este momento.</div>';

      }

    };

  document.body.appendChild(
    script
  );

}

/* Contadores reales por sector:
   - si el feed ya esta completo, se cuentan desde los datos cargados
   - si no, se usan los totales precargados en la pagina
     (data-sector-total="privado|estado", escritos por actualizar-contadores.ps1) */
function actualizarContadoresSector(){

  var nodos =
    document.querySelectorAll(
      "[data-sector-num]"
    );

  if(!nodos.length){
    return;
  }

  var total =
    window.__portalTotalEmpleos || 0;

  if(
    window.__feedCompleto &&
    empleos.length
  ){

    var cuenta = { privado: 0, estado: 0 };

    empleos.forEach(function(empleo){

      if(ofertaVencida(empleo)){
        return;
      }

      var norm =
        normalizar(
          empleo.contratante || ""
        );

      if(
        !norm ||
        norm.indexOf("no especific") === 0 ||
        norm === "no aplica"
      ){
        return;
      }

      if(
        norm.indexOf("estado") !== -1 ||
        norm.indexOf("publico") !== -1 ||
        norm.indexOf("gobierno") !== -1
      ){
        cuenta.estado++;
      }

      if(
        norm.indexOf("privado") !== -1 ||
        norm.indexOf("empresa") !== -1 ||
        norm.indexOf("particular") !== -1
      ){
        cuenta.privado++;
      }

    });

    nodos.forEach(function(nodo){
      var sector = nodo.getAttribute("data-sector-num");
      if(cuenta[sector] !== undefined){
        nodo.textContent = cuenta[sector];
        nodo.removeAttribute("data-sector-total");
      }
    });

    return;
  }

  nodos.forEach(function(nodo){
    var precargado =
      parseInt(
        nodo.getAttribute("data-sector-total") || "",
        10
      );

    if(!isNaN(precargado)){
      nodo.textContent = precargado;
    }else if(total){
      nodo.textContent = total;
    }
  });

}

function paginacionActualizarEstado(){

  var contenedor =
    document.getElementById(
      "cargarMasContenedor"
    );

  if(!contenedor){
    return;
  }

  var estado =
    document.getElementById(
      "cargarMasEstado"
    );

  var total =
    window.__portalTotalEmpleos || 0;

  var hayError =
    !!window.__feedError &&
    !window.__feedCompleto &&
    total > empleos.length;

  var completo =
    !!window.__feedCompleto;

  var visiblesTotal = 0;
  try {
    visiblesTotal = empleos.filter(ofertaVisible).length;
  } catch(e) {}

  var hayMas = visiblesTotal > cantidadActualEMPLEOS;
  var hayFinal =
    visiblesTotal > LIMITE_INICIAL_EMPLEOS &&
    !hayMas;

  if(estado){
    /* Mientras carga NO se pinta ningun texto de carga: los contadores
       reales (por sector y totales) viven en sus propios huecos. */
    if(hayError){
      estado.textContent =
        "No pudimos cargar todas las ofertas.";
    }else if(hayFinal){
      estado.textContent =
        "Has llegado al final de las ofertas";
    }else{
      estado.textContent = "";
    }
  }

  var hayFiltros =
    categoriaActiva !== "Todos" ||
    busquedaActual ||
    Object.keys(filtrosAplicados).some(function(k){
      return k !== "contratante" &&
        filtrosAplicados[k].length;
    });

  var boton =
    document.getElementById(
      "cargarMasOfertas"
    );

  if(hayError || hayMas || hayFinal){
    contenedor.removeAttribute("hidden");
  }else{
    contenedor.setAttribute("hidden", "");
  }

  if(boton){
    if(hayMas){
      boton.disabled = false;
      boton.style.display = "";
    }else{
      boton.style.display = "none";
    }
  }

  actualizarContadoresSector();

}

function paginacionActualizar(ocultar){

  var contenedor =
    document.getElementById(
      "cargarMasContenedor"
    );

  if(!contenedor){
    return;
  }

  if(ocultar){
    contenedor.setAttribute("hidden", "");
  }else{
    contenedor.removeAttribute("hidden");
  }

}

(function(){

  var boton =
    document.getElementById(
      "cargarMasOfertas"
    );

  if(!boton){
    return;
  }

  boton.addEventListener(
    "click",
    function(){

      cantidadActualEMPLEOS +=
        LIMITE_INICIAL_EMPLEOS;

      render();
      paginacionActualizarEstado();

    }
  );

})();

cargarOfertas();

      } catch(e) { console.error("[Empleos Portal] Error:", e); }
    })();

    /* =========================================================
       PORTALES SECUNDARIOS (Becas y ArtÃ­culos)
       Se activan solo si existe #becasGrid o #articulosGrid
       ========================================================= */
    (function(){
      "use strict";
      try {

      var SECCIONES = {
        becas:{
          gridId:"becasGrid",
          contadorId:"contadorBecas",
          etiqueta:"Beca",
          callback:"becasPeruHoyCallback",
          tipo:"beca",
          maxCaracteres:180,
          vacio:"No encontramos becas disponibles en este momento."
        },
        articulos:{
          gridId:"articulosGrid",
          contadorId:"contadorArticulos",
          etiqueta:"Articulo",
          callback:"articulosPeruHoyCallback",
          tipo:"articulo",
          maxCaracteres:220,
          vacio:"No encontramos artÃ­culos publicados todavÃ­a."
        }
      };

      function normalizarS(texto){
        return String(texto || "")
          .replace(/\u00a0/g," ")
          .replace(/\s+/g," ")
          .trim();
      }

      function limpiarHtml(html){
        var contenedor = document.createElement("div");
        contenedor.innerHTML = html || "";
        var eliminar = contenedor.querySelectorAll(
          "script,style,noscript,template,iframe,object,embed"
        );
        for(var i=0;i<eliminar.length;i++){
          eliminar[i].remove();
        }
        return contenedor;
      }

      function urlDe(entry){
        if(!entry || !entry.link){ return ""; }
        for(var i=0;i<entry.link.length;i++){
          if(entry.link[i].rel === "alternate"){
            return entry.link[i].href || "";
          }
        }
        return "";
      }

      function tituloDe(entry){
        if(entry && entry.title && entry.title.$t){
          return normalizarS(entry.title.$t);
        }
        return "";
      }

      function valorPorEtiqueta(root, etiquetas){
        var elementos = root.querySelectorAll(
          ".empleo-info-card,.empleo-destacado p,.empleo-info-card div"
        );
        for(var i=0;i<elementos.length;i++){
          var elemento = elementos[i];
          var etiquetaNodo = elemento.querySelector
            ? elemento.querySelector(".empleo-info-label")
            : null;
          if(etiquetaNodo){
            var etiquetaTexto = normalizarS(etiquetaNodo.textContent).toLowerCase();
            for(var j=0;j<etiquetas.length;j++){
              if(etiquetaTexto === String(etiquetas[j]).toLowerCase()){
                var valorNodo = elemento.querySelector(".empleo-info-value");
                if(valorNodo){
                  return normalizarS(valorNodo.textContent);
                }
              }
            }
          }
      if(
        elemento.matches &&
        (
          elemento.matches(".empleo-destacado p") ||
          elemento.matches(".empleo-datos-ocultos p")
        )
      ){
            var textoCompleto = normalizarS(elemento.textContent);
            for(var k=0;k<etiquetas.length;k++){
              var exp = new RegExp(
                "^\\s*" +
                etiquetas[k].replace(/[.*+?^${}()|[\]\\]/g,"\\$&") +
                "\\s*:\\s*(.+)$",
                "i"
              );
              var co = textoCompleto.match(exp);
              if(co){
                return normalizarS(co[1]);
              }
            }
          }
        }
        return "";
      }

      function descripcionDe(root, max){
        var p = root.querySelector(".empleo-descripcion");
        if(!p){
          p = root.querySelector(".empleo-seccion p");
        }
        if(!p){
          return "";
        }
        var texto = normalizarS(p.textContent);
        if(texto && max && texto.length > max){
          texto = texto.substring(0, max - 1) + "â€¦";
        }
        return texto;
      }

      function iconoDiploma(){
        return '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 9l9-5 9 5-9 5z"></path><path d="M7 11.5V16c3 2 7 2 10 0v-4.5"></path><path d="M21 9v6"></path></svg>';
      }

      function crearTarjetaBeca(beca){
        var tarjeta = document.createElement("article");
        tarjeta.className = "empleo-card";

        var visual = document.createElement("div");
        visual.className = "empleo-visual visual-educacion";

        var etiqueta = document.createElement("span");
        etiqueta.className = "empleo-etiqueta";
        etiqueta.textContent = "BECA";

        var icono = document.createElement("span");
        icono.className = "empleo-icono";
        icono.innerHTML = iconoDiploma();

        visual.appendChild(etiqueta);
        visual.appendChild(icono);

        var contenido = document.createElement("div");
        contenido.className = "empleo-contenido";

        var titulo = document.createElement("h3");
        titulo.className = "empleo-titulo";
        titulo.textContent = beca.title;

        var empresa = document.createElement("div");
        empresa.className = "empleo-empresa";
        empresa.textContent = beca.entidad;

        var datos = document.createElement("div");
        datos.className = "empleo-datos";

        if(beca.ubicacion){
          var u = document.createElement("span");
          u.className = "empleo-dato";
          u.textContent = beca.ubicacion;
          datos.appendChild(u);
        }

        if(beca.modalidad){
          var mo = document.createElement("span");
          mo.className = "empleo-dato";
          mo.textContent = beca.modalidad;
          datos.appendChild(mo);
        }

        var salario = document.createElement("div");
        salario.className = "empleo-salario";
        salario.textContent = beca.cobertura;

        var descripcion = document.createElement("div");
        descripcion.className = "empleo-descripcion";
        descripcion.textContent = beca.descripcion;

        var pie = document.createElement("div");
        pie.className = "empleo-pie";

        var fecha = document.createElement("span");
        fecha.className = "empleo-fecha";
        fecha.textContent = beca.fechaLimite || "";

        var boton = document.createElement("a");
        boton.className = "empleo-boton";
        boton.href = beca.url || "#";
        boton.target = "_self";
        boton.textContent = "VER BECA";

        pie.appendChild(fecha);
        pie.appendChild(boton);

        contenido.appendChild(titulo);
        contenido.appendChild(empresa);
        contenido.appendChild(datos);
        contenido.appendChild(salario);
        contenido.appendChild(descripcion);
        contenido.appendChild(pie);

        tarjeta.appendChild(visual);
        tarjeta.appendChild(contenido);
        return tarjeta;
      }

      function crearTarjetaArticulo(articulo){
        var card = document.createElement("a");
        card.className = "articulo-card";
        card.href = articulo.url || "#";
        card.target = "_self";
        card.setAttribute("data-tema", articulo.tema || "");
        card.setAttribute("data-titulo", articulo.title || "");

        var categoria = document.createElement("span");
        categoria.className = "articulo-categoria";
        categoria.textContent = articulo.tema || "ArtÃ­culo";

        var titulo = document.createElement("h3");
        titulo.className = "articulo-titulo";
        titulo.textContent = articulo.title;

        var resumen = document.createElement("p");
        resumen.className = "articulo-resumen";
        resumen.textContent = articulo.descripcion;

        var meta = document.createElement("div");
        meta.className = "articulo-meta";

        var fecha = document.createElement("span");
        fecha.textContent = articulo.fecha;

        var leer = document.createElement("span");
        leer.className = "articulo-leer";
        leer.textContent = "LEER â†’";

        meta.appendChild(fecha);
        meta.appendChild(leer);

        card.appendChild(categoria);
        card.appendChild(titulo);
        card.appendChild(resumen);
        card.appendChild(meta);

        return card;
      }

      function formatearFechaSeccion(fecha){
        if(!fecha){ return ""; }
        var d = new Date(fecha);
        if(isNaN(d.getTime())){ return ""; }
        var dd = String(d.getDate()).padStart(2,"0");
        var mm = String(d.getMonth() + 1).padStart(2,"0");
        var aa = d.getFullYear();
        return dd + "/" + mm + "/" + aa;
      }

      function construirItem(data, seccion){
        var entry = data;
        var root = limpiarHtml(
          (entry.content && entry.content.$t) || ""
        );
        var item = {
          title:tituloDe(entry),
          url:urlDe(entry),
          entidad:valorPorEtiqueta(root,["InstituciÃ³n","Institucion","Entidad","Empresa","OrganizaciÃ³n","Organizacion"]),
          ubicacion:valorPorEtiqueta(root,["UbicaciÃ³n","Ubicacion","Lugar","Ciudad"]),
          modalidad:valorPorEtiqueta(root,["Modalidad","Tipo"]),
          cobertura:valorPorEtiqueta(root,["Cobertura","Monto","Salario","Beneficio","SubvenciÃ³n","Subvencion"]),
          fechaLimite:valorPorEtiqueta(root,["Fecha de cierre","Fecha lÃ­mite","Fecha limite","Plazo"]),
          tema:valorPorEtiqueta(root,["Tema","CategorÃ­a","Categoria","Tipo de artÃ­culo","Tipo de articulo"]),
          descripcion:descripcionDe(root, seccion.maxCaracteres),
          fecha:formatearFechaSeccion(
            entry.published && entry.published.$t
              ? entry.published.$t
              : ""
          )
        };
        if(!item.tema && seccion.tipo === "articulo"){
          var nodoTema = root.querySelector(".empleo-cabecera .empleo-categoria");
          if(nodoTema){
            item.tema = normalizarS(nodoTema.textContent);
          }
        }
        return item;
      }

      function renderPortal(data, seccion){
        var grid = document.getElementById(seccion.gridId);
        if(!grid){ return; }
        var contador = document.getElementById(seccion.contadorId);
        var entradas = (
          data &&
          data.feed &&
          data.feed.entry
            ? data.feed.entry
            : []
        );
        var items = [];
        for(var i=0;i<entradas.length;i++){
          var entrada = entradas[i];
          var url = urlDe(entrada);
          var titulo = tituloDe(entrada);
          if(!titulo || !url){ continue; }
          var item = construirItem(entrada, seccion);
          if(!item.title || !item.url){ continue; }
          items.push(item);
        }
        grid.innerHTML = "";
        if(!items.length){
          grid.innerHTML =
            '<div class="empleo-vacio">' + seccion.vacio + '</div>';
          if(contador){
            contador.textContent = "0";
          }
          return;
        }
        for(var j=0;j<items.length;j++){
          var tarjeta = seccion.tipo === "beca"
            ? crearTarjetaBeca(items[j])
            : crearTarjetaArticulo(items[j]);
          grid.appendChild(tarjeta);
        }
        if(contador){
          contador.textContent =
            items.length +
            (items.length === 1
              ? " resultado"
              : " resultados");
        }
      }

      window.becasPeruHoyCallback =
        function(data){
          renderPortal(data, SECCIONES.becas);
        };

      window.articulosPeruHoyCallback =
        function(data){
          renderPortal(data, SECCIONES.articulos);
        };

      function cargarPortal(seccion){
        var grid = document.getElementById(seccion.gridId);
        if(!grid){ return; }
        var script = document.createElement("script");
        script.src =
          "https://empleosperuhoy.blogspot.com/feeds/posts/default/-/" +
          encodeURIComponent(seccion.etiqueta) +
          "?alt=json-in-script&max-results=50&orderby=published&callback=" +
          seccion.callback +
          "&_=" + new Date().getTime();
        script.async = true;
        script.onerror = (function(sec){
          return function(){
            var g = document.getElementById(sec.gridId);
            if(g){
              g.innerHTML =
                '<div class="empleo-vacio">No fue posible cargar el contenido en este momento.</div>';
            }
          };
        })(seccion);
        document.body.appendChild(script);
      }

      // cargarPortal(SECCIONES.becas); â€” desactivado: ahora se usa el sistema dinÃ¡mico en cargarBecasDinamicas()
      // cargarPortal(SECCIONES.articulos); â€” desactivado: ahora se usa cargarArticulosDinamicas()

  } catch(e) { console.error("[Becas/ArtÃ­culos Portal] Error:", e); }
    })();

/* =========================================================
       OFERTAS RELACIONADAS (solo si existe .empleo-individual)
       ========================================================= */
    (function(){
      "use strict";
      try {
        var contenedorOferta = document.querySelector(
          ".empleo-individual"
        );

      if(!contenedorOferta){
        return;
      }

  var CONTENEDOR_ID = "ofertasRelacionadas";

  function normalizarTexto(texto){

    return String(texto || "")
      .replace(/\u00a0/g," ")
      .replace(/\s+/g," ")
      .trim();

  }

  function escaparHTML(texto){

    return String(texto || "")
      .replace(/&/g,"&amp;")
      .replace(/</g,"&lt;")
      .replace(/>/g,"&gt;")
      .replace(/"/g,"&quot;")
      .replace(/'/g,"&#39;");

  }

  function escaparAtributo(texto){

    return escaparHTML(texto);

  }

  function limpiarHTMLParaLectura(html){

    var contenedor = document.createElement("div");

    contenedor.innerHTML = html || "";

    var elementosEliminar = contenedor.querySelectorAll(
      "script,style,noscript,template,iframe,object,embed"
    );

    for(var i=0;i<elementosEliminar.length;i++){
      elementosEliminar[i].remove();
    }

    return contenedor;

  }

  function textoNodo(nodo){

    if(!nodo){
      return "";
    }

    return normalizarTexto(
      nodo.textContent ||
      nodo.innerText ||
      ""
    );

  }

  function obtenerTextoPagina(selector){

    var nodo = document.querySelector(selector);

    return nodo ? textoNodo(nodo) : "";

  }

  function obtenerCiudadPagina(){

    var tarjetas = document.querySelectorAll(".empleo-info-card");

    for(var i=0;i<tarjetas.length;i++){

      var etiqueta = tarjetas[i].querySelector(".empleo-info-label");

      if(!etiqueta){
        continue;
      }

      if(
        textoNodo(etiqueta).toLowerCase() ===
        "ubicaciÃ³n".toLowerCase()
      ){

        var valor = tarjetas[i].querySelector(".empleo-info-value");

        if(valor){

          var texto = textoNodo(valor);

          return texto.split(",")[0].trim() || "";

        }

      }

    }

    return "";

  }

  var TITULO_ACTUAL =
    obtenerTextoPagina(".empleo-cabecera h1") ||
    (document.title || "");

  var URL_ACTUAL =
    window.location.href || "";

var CATEGORIA_ACTUAL =
    normalizarCategoria(
      obtenerTextoPagina(".empleo-cabecera .empleo-categoria")
    );

  if(
    CATEGORIA_ACTUAL === "Otros"
  ){

    CATEGORIA_ACTUAL =
      normalizarCategoria(
        TITULO_ACTUAL
      );

  }

  var EMPRESA_ACTUAL =
    obtenerTextoPagina(".empleo-cabecera .empleo-empresa");

  var CIUDAD_ACTUAL =
    obtenerCiudadPagina();

  function normalizarCategoria(categoria){

    var texto = normalizarTexto(categoria)
      .toLowerCase()
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g,"");

    if(
      /abogad|derecho|legal|juridic|asesor legal|asesor juridic|asesoria legal|contratos|compliance|notar|procurador/.test(texto)
    ){
      return "Derecho";
    }

    if(
      /medic|enfermer|odontolog|farmaci|fisioter|nutri|psicolog|obstetr|clinic|hospital|salud/.test(texto)
    ){
      return "Salud";
    }

    if(
      /ingenier|arquitect|urbanismo|operaciones|produccion|mantenimiento|procesos|logistic|almacen|supply chain|cadena de suministro|distribucion|transporte|ssoma|sst|hse|ehs|seguridad ocupacional|medio ambiente|prevencion de riesgos|mecanico|electricista|industrial|civil|calidad|mineria/.test(texto)
    ){
      return "IngenierÃ­a";
    }

    if(
      /ventas|venta|vendedor|asesor comercial|ejecutivo comercial|representante comercial|promotor|comercial|televentas|call center|atencion al cliente|atencion al usuario|servicio al cliente|cobranzas|ejecutivo de cuenta|retail|tienda|restaurante|hotel/.test(texto)
    ){
      return "Ventas y Servicios";
    }

    if(
      /administrad|administracion|asistente administrativ|auxiliar administrativ|secretaria|secretario|recepcionista|recursos humanos|rrhh|talento humano|contador|contabilidad|finanzas|financiero|tesorer|compras|credito|auditor/.test(texto)
    ){
      return "AdministraciÃ³n y Finanzas";
    }

    if(
      /docente|profesor|maestro|educacion|educativo|pedagogia|tutor|instructor|capacitador|colegio|universidad|instituto|docencia/.test(texto)
    ){
      return "EducaciÃ³n";
    }

    return "Otros";

  }

  function claseCategoria(categoria){

    var texto = normalizarCategoria(categoria);

    if(texto === "IngenierÃ­a"){
      return "visual-ingenieria";
    }

    if(texto === "Salud"){
      return "visual-salud";
    }

    if(texto === "Ventas y Servicios"){
      return "visual-ventas-servicios";
    }

    if(texto === "AdministraciÃ³n y Finanzas"){
      return "visual-administracion-finanzas";
    }

    if(texto === "Derecho"){
      return "visual-derecho";
    }

    if(texto === "EducaciÃ³n"){
      return "visual-educacion";
    }

    return "visual-otros";

  }

  function iconoCategoria(categoria){

    var categoriaNormalizada = normalizarCategoria(categoria);

    if(categoriaNormalizada === "IngenierÃ­a"){

      return '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 20h16"></path><path d="M6 20V8l6-4 6 4v12"></path><path d="M9 20v-5h6v5"></path><path d="M9 10h1"></path><path d="M14 10h1"></path></svg>';

    }

    if(categoriaNormalizada === "Salud"){

      return '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 21s-7-4.6-9-9.1C1.5 8.5 3.4 5 7 5c2 0 3.6 1.1 5 3 1.4-1.9 3-3 5-3 3.6 0 5.5 3.5 4 6.9C19 16.4 12 21 12 21z"></path><path d="M12 9v6"></path><path d="M9 12h6"></path></svg>';

    }

    if(categoriaNormalizada === "Ventas y Servicios"){

      return '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 19V5"></path><path d="M4 19h16"></path><path d="M7 15l4-4 3 2 5-6"></path><path d="M16 7h3v3"></path></svg>';

    }

    if(categoriaNormalizada === "AdministraciÃ³n y Finanzas"){

      return '<svg viewBox="0 0 24 24" aria-hidden="true"><rect x="4" y="7" width="16" height="13" rx="2"></rect><path d="M9 7V5h6v2"></path><path d="M4 12h16"></path><path d="M10 12v2h4v-2"></path></svg>';

    }

    if(categoriaNormalizada === "Derecho"){

      return '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 4v16"></path><path d="M6 7h12"></path><path d="M6 7l-3 6h6z"></path><path d="M18 7l-3 6h6z"></path><path d="M8 20h8"></path></svg>';

    }

    if(categoriaNormalizada === "EducaciÃ³n"){

      return '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 9l9-5 9 5-9 5z"></path><path d="M7 11.5V16c3 2 7 2 10 0v-4.5"></path><path d="M21 9v6"></path></svg>';

    }

    return '<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="8"></circle><path d="M12 8v8"></path><path d="M8 12h8"></path></svg>';

  }

  function obtenerValorPorEtiqueta(root, etiquetas){

    var elementos = root.querySelectorAll(
      ".empleo-info-card,.empleo-destacado p,.empleo-info-card div,.empleo-datos-ocultos p"
    );

    for(var i=0;i<elementos.length;i++){

      var elemento = elementos[i];

      var etiquetaNodo = elemento.querySelector
        ? elemento.querySelector(".empleo-info-label")
        : null;

      if(etiquetaNodo){

        var etiquetaTexto = textoNodo(etiquetaNodo).toLowerCase();

        for(var j=0;j<etiquetas.length;j++){

          if(etiquetaTexto === etiquetas[j].toLowerCase()){

            var valorNodo = elemento.querySelector(".empleo-info-value");

            if(valorNodo){
              return textoNodo(valorNodo);
            }

          }

        }

      }

      if(elemento.matches && elemento.matches(".empleo-destacado p")){

        var textoCompleto = textoNodo(elemento);

        for(var k=0;k<etiquetas.length;k++){

          var expresion = new RegExp(
            "^\\s*" +
            etiquetas[k].replace(/[.*+?^${}()|[\]\\]/g,"\\$&") +
            "\\s*:\\s*(.+)$",
            "i"
          );

          var coincidencia = textoCompleto.match(expresion);

          if(coincidencia){
            return normalizarTexto(coincidencia[1]);
          }

        }

      }

    }

    return "";

  }

  function obtenerSeccion(root,nombre){

    var secciones = root.querySelectorAll(".empleo-seccion");

    for(var i=0;i<secciones.length;i++){

      var titulo = secciones[i].querySelector("h2");

      if(!titulo){
        continue;
      }

      var tituloTexto = textoNodo(titulo).toLowerCase();

      if(tituloTexto === nombre.toLowerCase()){

        var copia = secciones[i].cloneNode(true);

        var tituloCopia = copia.querySelector("h2");

        if(tituloCopia){
          tituloCopia.remove();
        }

        var anuncios = copia.querySelectorAll(
          ".empleo-anuncio,.empleo-postular,.ofertas-relacionadas"
        );

        for(var j=0;j<anuncios.length;j++){
          anuncios[j].remove();
        }

        return textoNodo(copia);

      }

    }

    return "";

  }

  function extraerOferta(entry){

    var contenido = "";

    if(
      entry &&
      entry.content &&
      entry.content.$t
    ){
      contenido = entry.content.$t;
    }

    var root = limpiarHTMLParaLectura(contenido);

    var tituloNodo = root.querySelector(
      ".empleo-cabecera h1"
    );

    var empresaNodo = root.querySelector(
      ".empleo-cabecera .empleo-empresa"
    );

    var categoriaNodo = root.querySelector(
      ".empleo-cabecera .empleo-categoria"
    );

    var titulo = textoNodo(tituloNodo);

    var empresa = textoNodo(empresaNodo);

    var categoriaOriginal = textoNodo(categoriaNodo);

    if(!titulo){

      titulo = normalizarTexto(
        entry &&
        entry.title &&
        entry.title.$t
          ? entry.title.$t
          : ""
      );

    }

    if(!empresa){

      empresa = obtenerValorPorEtiqueta(
        root,
        ["Empresa"]
      );

    }

if(!categoriaOriginal){

      categoriaOriginal = obtenerValorPorEtiqueta(
        root,
        ["CategorÃ­a","Categoria"]
      );

    }

    var categoriaDesdeTitulo = normalizarCategoria(
      titulo
    );

    var categoria = normalizarCategoria(
      categoriaOriginal
    );

    if(categoria === "Otros"){
      categoria = categoriaDesdeTitulo;
    }

    var ubicacion = obtenerValorPorEtiqueta(
      root,
      ["UbicaciÃ³n","Ubicacion"]
    );

    var modalidad = obtenerValorPorEtiqueta(
      root,
      ["Modalidad"]
    );

    var contrato = obtenerValorPorEtiqueta(
      root,
      ["Contrato"]
    );

    var salario = obtenerValorPorEtiqueta(
      root,
      ["Salario","RemuneraciÃ³n","Remuneracion","Sueldo"]
    );

    if(!salario){

      salario = textoNodo(
        root.querySelector(".empleo-salario-header")
      );

    }

    var etiquetaContratante =
      obtenerValorPorEtiqueta(
        root,
        ["Tipo contratante","Tipo de contratante","Contratante"]
      ) || "";

    /* El bloque oculto .empleo-datos-ocultos es donde vive
       "Tipo contratante: Estado"; si el nodo no se pudo leer,
       se busca sobre el HTML crudo de la entrada. */
    if(!etiquetaContratante){

      var mContratante = contenido.match(
        /Tipo\s+(?:de\s+)?contratante\s*:\s*(?:<\/strong>)?\s*([^<\r\n]{1,60})/i
      );

      if(mContratante){
        etiquetaContratante = normalizarTexto(mContratante[1]);
      }

    }

    var contratanteMinus = etiquetaContratante
      .toLowerCase()
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g,"");

    var tipoContratante = "No especificado";

    if(etiquetaContratante){

      if(
        contratanteMinus.indexOf("estado") !== -1 ||
        contratanteMinus.indexOf("publico") !== -1 ||
        contratanteMinus.indexOf("gobierno") !== -1 ||
        contratanteMinus.indexOf("municipal") !== -1 ||
        contratanteMinus.indexOf("ministerio") !== -1
      ){
        tipoContratante = "Estado";
      }else if(
        contratanteMinus.indexOf("privad") !== -1
      ){
        tipoContratante = "Privado";
      }else{
        tipoContratante = etiquetaContratante;
      }

    }

    var vacantes = obtenerValorPorEtiqueta(
      root,
      ["Vacantes","Nro de vacantes","NÂ° de vacantes","Plazas","NÂ° plazas"]
    );

    var dirigido = obtenerValorPorEtiqueta(
      root,
      ["Dirigido a","Dirigido A"]
    );

    var fechaCierre = obtenerValorPorEtiqueta(
      root,
      ["Fecha de cierre","Fecha cierre","Fechas para postular"]
    );

    var experiencia = obtenerValorPorEtiqueta(
      root,
      ["Experiencia"]
    );

    var descripcion = obtenerSeccion(
      root,
      "DescripciÃ³n del puesto"
    );

    if(!descripcion){

      descripcion = obtenerSeccion(
        root,
        "Descripcion del puesto"
      );

    }

    var fecha = "";

    if(
      entry &&
      entry.published &&
      entry.published.$t
    ){

      fecha = entry.published.$t;

    }

    var url = "";

    if(
      entry &&
      entry.link
    ){

      for(var i=0;i<entry.link.length;i++){

        if(entry.link[i].rel === "alternate"){

          url = entry.link[i].href || "";
          break;

        }

      }

    }

    return {
      titulo:titulo,
      title:titulo,
      empresa:empresa || "Empresa no especificada",
      company:empresa || "Empresa no especificada",
      categoria:categoria,
      category:categoria,
      ubicacion:ubicacion || "No especificada",
      city:ubicacion || "No especificada",
      modalidad:modalidad || "No especificada",
      modality:modalidad || "No especificada",
      contrato:contrato || "No especificado",
      salario:salario || "No especificado",
      salary:salario || "No especificado",
      vacancies:vacantes || "",
      audience:dirigido || "",
      contratante:tipoContratante,
      closingDate:fechaCierre || "",
      experiencia:experiencia || "",
      descripcion:descripcion || "",
      description:descripcion || "",
      fecha:fecha,
      fechaEntrada:fecha,
      url:url
    };

  }

  function palabras(texto){

    return normalizarTexto(texto)
      .toLowerCase()
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g,"")
      .replace(/[^a-z0-9\s]/g," ")
      .split(/\s+/)
      .filter(function(palabra){
        return palabra.length >= 4;
      });

  }

  function normalizarUrl(url){

    return String(url || "")
      .toLowerCase()
      .replace(/^https?:\/\//,"")
      .replace(/^www\./,"")
      .replace(/\/+$/,"")
      .replace(/\?.*$/,"");

  }

  function calcularRelevancia(oferta){

    var actual = (
      TITULO_ACTUAL +
      " " +
      CATEGORIA_ACTUAL +
      " " +
      CIUDAD_ACTUAL
    ).toLowerCase();

    var textoOferta = (
      oferta.titulo +
      " " +
      oferta.categoria +
      " " +
      oferta.ubicacion +
      " " +
      oferta.descripcion
    ).toLowerCase();

    var puntuacion = 0;

    var categoriaCoincide = false;

if(
      CATEGORIA_ACTUAL &&
      normalizarCategoria(oferta.categoria) ===
      normalizarCategoria(CATEGORIA_ACTUAL)
    ){
      puntuacion += 30;
      categoriaCoincide = true;
    }

    oferta.mismaCategoria = categoriaCoincide;

    var ciudadCoincide = false;

    if(
      CIUDAD_ACTUAL &&
      textoOferta.indexOf(CIUDAD_ACTUAL.toLowerCase()) !== -1
    ){
      puntuacion += 20;
      ciudadCoincide = true;
    }

    if(
      oferta.modalidad &&
      CATEGORIA_ACTUAL
    ){

      var modalidadActual =
        obtenerTextoPagina(".empleo-info-card .empleo-info-value");

      var modalidadValor = "";

      var tarjetasDOM = document.querySelectorAll(".empleo-info-card");

      for(var m=0;m<tarjetasDOM.length;m++){

        var lab = tarjetasDOM[m].querySelector(".empleo-info-label");

        if(
          lab &&
          textoNodo(lab).toLowerCase() === "modalidad"
        ){

          var v = tarjetasDOM[m].querySelector(".empleo-info-value");

          if(v){
            modalidadValor = textoNodo(v).toLowerCase();
          }

          break;

        }

      }

      if(
        modalidadValor &&
        modalidadValor !== "no especificada" &&
        oferta.modalidad.toLowerCase() === modalidadValor
      ){
        puntuacion += 12;
      }

    }

    var tokensActuales = palabras(actual);
    var tokensOferta = palabras(textoOferta);

    var coincidencias = 0;

    for(var i=0;i<tokensActuales.length;i++){

      if(tokensOferta.indexOf(tokensActuales[i]) !== -1){

        coincidencias++;
        puntuacion += 8;

      }

    }

    var grupos = [
      {
        palabras:[
          "ssoma","hse","ehs","sst",
          "seguridad","ocupacional",
          "riesgos","prevencion",
          "epp","ambiente"
        ],
        peso:5
      },
      {
        palabras:[
          "supervisor","coordinador",
          "jefe","encargado"
        ],
        peso:4
      },
      {
        palabras:[
          "ingeniero","ingenieria",
          "industrial","planta",
          "produccion","operaciones"
        ],
        peso:3
      },
      {
        palabras:[
          "calidad","auditoria",
          "iso","procesos","gestion"
        ],
        peso:3
      },
      {
        palabras:[
          "administracion","contabilidad",
          "finanzas","recursos",
          "humanos","rrhh"
        ],
        peso:3
      },
      {
        palabras:[
          "ventas","comercial",
          "vendedor","asesor","cliente"
        ],
        peso:3
      },
      {
        palabras:[
          "logistica","almacen",
          "compras","distribucion",
          "transporte","supply"
        ],
        peso:3
      }
    ];

    for(var g=0;g<grupos.length;g++){

      for(var p=0;p<grupos[g].palabras.length;p++){

        if(
          textoOferta.indexOf(
            grupos[g].palabras[p]
          ) !== -1
        ){

          puntuacion += grupos[g].peso;

        }

      }

    }

    if(
      /gerente|director|jefe/.test(
        oferta.titulo.toLowerCase()
      )
    ){
      puntuacion += 4;
    }

    if(
      /supervisor|coordinador/.test(
        oferta.titulo.toLowerCase()
      )
    ){
      puntuacion += 3;
    }

    if(
      /analista|especialista|ingeniero/.test(
        oferta.titulo.toLowerCase()
      )
    ){
      puntuacion += 2;
    }

    if(
      /asistente|auxiliar|practicante/.test(
        oferta.titulo.toLowerCase()
      )
    ){
      puntuacion += 2;
    }

    if(
      CIUDAD_ACTUAL &&
      normalizarTexto(oferta.empresa).toLowerCase() ===
      normalizarTexto(EMPRESA_ACTUAL).toLowerCase()
    ){
      puntuacion += 15;
    }

    if(coincidencias){
      puntuacion += coincidencias;
    }

    return puntuacion;

  }

  function formatearFecha(fecha){

    if(!fecha){
      return "Fecha no especificada";
    }

    var objetoFecha = new Date(fecha);

    if(isNaN(objetoFecha.getTime())){
      return "Fecha no especificada";
    }

    var dia = String(
      objetoFecha.getDate()
    ).padStart(2,"0");

    var mes = String(
      objetoFecha.getMonth()+1
    ).padStart(2,"0");

    var anio = objetoFecha.getFullYear();

    return dia + "/" + mes + "/" + anio;

  }

  function crearTarjeta(oferta){

    var categoria = normalizarCategoria(
      oferta.categoria
    );

    var clase = claseCategoria(
      categoria
    );

    var titulo = escaparHTML(
      oferta.titulo
    );

    var empresa = escaparHTML(
      oferta.empresa
    );

    var ubicacion = escaparHTML(
      oferta.ubicacion
    );

    var modalidad = escaparHTML(
      oferta.modalidad
    );

    var contrato = escaparHTML(
      oferta.contrato
    );

    var salario = escaparHTML(
      oferta.salario
    );

    var descripcion = escaparHTML(
      oferta.descripcion ||
      "Consulta todos los detalles de esta oferta."
    );

    var fecha = escaparHTML(
      formatearFecha(oferta.fecha)
    );

    var url = escaparAtributo(
      oferta.url
    );

    return (
      '<article class="relacionado-card">' +

        '<div class="relacionado-visual ' + clase + '">' +

          '<span class="relacionado-etiqueta">' +
            escaparHTML(categoria) +
          '</span>' +

          '<span class="relacionado-icono">' +
            iconoCategoria(categoria) +
          '</span>' +

        '</div>' +

        '<div class="relacionado-contenido">' +

          '<div class="relacionado-titulo">' +
            titulo +
          '</div>' +

          '<div class="relacionado-empresa">' +
            empresa +
          '</div>' +

          '<div class="relacionado-datos">' +

            '<span class="relacionado-chip">' +
              ubicacion +
            '</span>' +

            '<span class="relacionado-chip">' +
              modalidad +
            '</span>' +

            '<span class="relacionado-chip">' +
              contrato +
            '</span>' +

          '</div>' +

          '<div class="relacionado-salario">' +
            salario +
          '</div>' +

          '<div class="relacionado-descripcion">' +
            descripcion +
          '</div>' +

          '<div class="relacionado-fecha">' +
            'Publicado: ' + fecha +
          '</div>' +

          '<a class="relacionado-boton" ' +
             'href="' + url + '" ' +
             'target="_blank" ' +
             'rel="noopener noreferrer">' +
             'VER OFERTA' +
          '</a>' +

        '</div>' +

      '</article>'
    );

  }

  function mostrarOfertas(data){

    var contenedor = document.getElementById(
      CONTENEDOR_ID
    );

    if(!contenedor){
      return;
    }

    var entradas = (
      data &&
      data.feed &&
      data.feed.entry
        ? data.feed.entry
        : []
    );

    var urlActualNormalizada =
      normalizarUrl(URL_ACTUAL);

    var ofertas = [];

    var urlsVistas = {};

    for(var i=0;i<entradas.length;i++){

      var oferta = extraerOferta(
        entradas[i]
      );

      if(!oferta.titulo){
        continue;
      }

      var urlOfertaNormalizada =
        normalizarUrl(oferta.url);

      if(
        urlOfertaNormalizada &&
        urlOfertaNormalizada === urlActualNormalizada
      ){
        continue;
      }

      var mismoTitulo =
        normalizarTexto(oferta.titulo).toLowerCase() ===
        normalizarTexto(TITULO_ACTUAL).toLowerCase();

      if(mismoTitulo){
        continue;
      }

      if(
        !oferta.url ||
        oferta.url.indexOf("empleosperuhoy.blogspot.com") === -1
      ){
        continue;
      }

      if(urlsVistas[urlOfertaNormalizada]){
        continue;
      }

      urlsVistas[urlOfertaNormalizada] = true;

      oferta.relevancia =
        calcularRelevancia(oferta);

      if(oferta.relevancia <= 0){
        continue;
      }

      ofertas.push(oferta);

    }

ofertas.sort(function(a,b){

      if(
        a.mismaCategoria !==
        b.mismaCategoria
      ){

        return a.mismaCategoria
          ? -1
          : 1;

      }

      if(
        b.relevancia !==
        a.relevancia
      ){

        return b.relevancia -
          a.relevancia;

      }

      return (
        new Date(b.fecha || 0) -
        new Date(a.fecha || 0)
      );

    });

    if(!ofertas.length){

      contenedor.innerHTML =
        '<div style="padding:15px;color:#6b7280;font-size:13px;">No hay ofertas recomendadas disponibles.</div>';

      return;

    }

    contenedor.classList.add("rel-scroll");
    window._ofertasRelTodas = ofertas;
    window._ofertasRelMostradas = 0;
    window._ofertasRelBatch = 12;

    function _htmlOfertasBatch(desde, hasta){
      var html = "";
      var total = Math.min(hasta, ofertas.length);
      for(var j = desde; j < total; j++){
        html += crearTarjeta(ofertas[j]);
        var n = j - desde + 1;
        if(n % 4 === 0 && j < total - 1){
          html += '<div class="empleo-anuncio empleo-anuncio-feed rel-ad" style="flex:0 0 300px;grid-column:auto;align-self:stretch;margin:0;"><div class="empleo-anuncio-inner">Espacio publicitario</div></div>';
        }
      }
      return html;
    }

    function _anuncioRel(){
      var nodo = document.createElement("div");
      nodo.className = "empleo-anuncio empleo-anuncio-feed rel-ad";
      nodo.setAttribute("style","flex:0 0 300px;grid-column:auto;align-self:stretch;margin:0;");
      var interno = document.createElement("div");
      interno.className = "empleo-anuncio-inner";
      interno.textContent = "Espacio publicitario";
      nodo.appendChild(interno);
      return nodo;
    }

    function _pintarSiguienteBatch(){
      var desde = window._ofertasRelMostradas;
      if(desde >= ofertas.length) return false;
      var hasta = desde + window._ofertasRelBatch;
      var total = Math.min(hasta, ofertas.length);

      /* Usa la TARJETA MAESTRA (window.crearTarjeta) para que las
         convocatorias del Estado se pinten con la MISMA estructura
         que la pagina (.empleo-card estado-card + campos de estado).
         La version local en cadena solo queda como respaldo. */
      var maestra = typeof window.crearTarjeta === "function"
        ? window.crearTarjeta
        : null;

      if(maestra){
        var frag = document.createDocumentFragment();
        for(var j = desde; j < total; j++){
          var nodo = null;
          try { nodo = maestra(ofertas[j]); } catch(eNodo){ nodo = null; }
          if(nodo){ frag.appendChild(nodo); }
          var n = j - desde + 1;
          if(n % 4 === 0 && j < total - 1){ frag.appendChild(_anuncioRel()); }
        }
        if(desde === 0){ contenedor.innerHTML = ""; }
        contenedor.appendChild(frag);
      } else {
        var html = _htmlOfertasBatch(desde, hasta);
        if(desde === 0){
          contenedor.innerHTML = html;
        } else {
          contenedor.insertAdjacentHTML("beforeend", html);
        }
      }

      window._ofertasRelMostradas = hasta;
      return window._ofertasRelMostradas < ofertas.length;
    }

    function _arrancarRelacionados(){
      /* La tarjeta maestra (window.crearTarjeta) se publica en
         DOMContentLoaded desde el portal de inicio: si el feed
         responde antes, se espera a ese momento para pintar con
         la MISMA tarjeta de la pagina de Empleos. */
      if(
        typeof window.crearTarjeta !== "function" &&
        document.readyState === "loading"
      ){
        document.addEventListener("DOMContentLoaded", _arrancarRelacionados);
        return;
      }

      _pintarSiguienteBatch();

      if(!contenedor._relInfinito){
        contenedor._relInfinito = true;
        contenedor.addEventListener("scroll", function(){
          if(window._ofertasRelMostradas >= ofertas.length) return;
          var faltaFin = contenedor.scrollWidth - contenedor.clientWidth - contenedor.scrollLeft;
          if(faltaFin > 360) return;
          _pintarSiguienteBatch();
        }, { passive: true });
      }
    }

    _arrancarRelacionados();

  }

  window.ofertasRelacionadasCallback = function(data){
    try {
      mostrarOfertas(data);
    } catch(errOfertas){
      console.error("[Ofertas Relacionadas] callback:", errOfertas);
      try {
        var cErr = document.getElementById("ofertasRelacionadas");
        if(cErr && !cErr.children.length){
          cErr.innerHTML = '<div style="padding:15px;color:#6b7280;font-size:13px;">No hay ofertas recomendadas disponibles.</div>';
        }
      } catch(ePaint){}
    }
  };

  var script =
    document.createElement("script");

  script.src =
    "https://empleosperuhoy.blogspot.com/feeds/posts/default/-/Empleo?alt=json-in-script&max-results=50&orderby=published&callback=ofertasRelacionadasCallback";

  script.async = true;

document.body.appendChild(script);

  } catch(e) { console.error("[Ofertas Relacionadas] Error:", e); }
    })();

    /* =========================================================
       CORRECTOR UNIVERSAL DE TARJETAS RELACIONADAS
       Los posts viejos llevan su propio JS incrustado que
       clasifica categorias SIN quitar tildes, por lo que
       "Educacion"/"Administracion y Finanzas" caen a "Otros".
       PRIORIDAD: primero la categoria declarada en la entrada
       (.empleo-categoria / .relacionado-etiqueta). Solo si no
       es una categoria valida se reclasifica por el titulo con
       el normalizador sin tildes. Si tampoco hay titulo util,
       la etiqueta se conserva tal cual (nunca se pisa por "Otros").
       ========================================================= */
    (function(){
  try {

      var REGLAS_CATEGORIA = [
        { e: /abogad|derecho|legal|juridic|asesor legal|asesor juridic|asesoria legal|contratos|compliance|notar|procurador/, c: "Derecho", v: "visual-derecho" },
        { e: /medic|enfermer|odontolog|farmaci|fisioter|nutri|psicolog|obstetr|clinic|hospital|salud/, c: "Salud", v: "visual-salud" },
        { e: /ingenier|arquitect|urbanismo|operaciones|produccion|mantenimiento|procesos|logistic|almacen|supply chain|cadena de suministro|distribucion|transporte|ssoma|sst|hse|ehs|seguridad ocupacional|medio ambiente|prevencion de riesgos|mecanico|electricista|industrial|civil|calidad|mineria/, c: "IngenierÃ­a", v: "visual-ingenieria" },
        { e: /ventas|venta|vendedor|asesor comercial|ejecutivo comercial|representante comercial|promotor|comercial|televentas|call center|atencion al cliente|atencion al usuario|servicio al cliente|cobranzas|ejecutivo de cuenta|retail|tienda|restaurante|hotel/, c: "Ventas y Servicios", v: "visual-ventas-servicios" },
        { e: /administrad|administracion|asistente administrativ|auxiliar administrativ|secretaria|secretario|recepcionista|recursos humanos|rrhh|talento humano|contador|contabilidad|finanzas|financiero|tesorer|compras|credito|auditor/, c: "AdministraciÃ³n y Finanzas", v: "visual-administracion-finanzas" },
        { e: /docente|profesor|maestro|educacion|educativo|pedagogia|tutor|instructor|capacitador|colegio|universidad|instituto|docencia/, c: "EducaciÃ³n", v: "visual-educacion" }
      ];

      function normalizarParaClase(texto){
        return String(texto || "")
          .toLowerCase()
          .normalize("NFD")
          .replace(/[\u0300-\u036f]/g,"")
          .replace(/\s+/g," ")
          .trim();
      }

      function clasificarCategoria(texto){
        var t = normalizarParaClase(texto);
        for(var i=0;i<REGLAS_CATEGORIA.length;i++){
          if(REGLAS_CATEGORIA[i].e.test(t)){
            return REGLAS_CATEGORIA[i];
          }
        }
        return { c: "Otros", v: "visual-otros" };
      }

      var NOMBRES_CATEGORIA = [
        { c: "Derecho", v: "visual-derecho" },
        { c: "Salud", v: "visual-salud" },
        { c: "IngenierÃ­a", v: "visual-ingenieria" },
        { c: "Ventas y Servicios", v: "visual-ventas-servicios" },
        { c: "AdministraciÃ³n y Finanzas", v: "visual-administracion-finanzas" },
        { c: "EducaciÃ³n", v: "visual-educacion" }
      ];

      function reglaPorNombre(texto){
        var t = normalizarParaClase(texto);
        if(!t || t === "otros"){ return null; }
        for(var i=0;i<NOMBRES_CATEGORIA.length;i++){
          if(normalizarParaClase(NOMBRES_CATEGORIA[i].c) === t){
            return NOMBRES_CATEGORIA[i];
          }
        }
        return null;
      }

      function resolverRegla(textoDeclarado, textoTitulo){
        var porNombre = reglaPorNombre(textoDeclarado);
        if(porNombre){ return porNombre; }
        var porTitulo = clasificarCategoria(textoTitulo);
        if(porTitulo.c !== "Otros"){ return porTitulo; }
        return null;
      }

function corregirTarjetas(){
        var contenedor = document.getElementById("ofertasRelacionadas");
        if(!contenedor){ return; }
        var tarjetas = contenedor.querySelectorAll(".relacionado-card");
        for(var i=0;i<tarjetas.length;i++){
          var tarjeta = tarjetas[i];
          if(tarjeta.getAttribute("data-corregida") === "1"){ continue; }
          var visual = tarjeta.querySelector(".relacionado-visual");
          var titulo = tarjeta.querySelector(".relacionado-titulo");
          if(!visual || !titulo){ continue; }
          var etiqueta = tarjeta.querySelector(".relacionado-etiqueta");
          var regla = resolverRegla(
            etiqueta ? etiqueta.textContent : "",
            titulo.textContent
          );
          if(!regla){ continue; }
          var clases = (visual.className || "").split(/\s+/).filter(function(c){
            return c && c.indexOf("visual-") !== 0;
          });
          if(clases.indexOf(regla.v) === -1){
            clases.push(regla.v);
          }
          var nuevoVisual = clases.join(" ");
          if(visual.className !== nuevoVisual){
            visual.className = nuevoVisual;
          }
          if(etiqueta && etiqueta.textContent !== regla.c){
            etiqueta.textContent = regla.c;
          }
          tarjeta.setAttribute("data-corregida", "1");
        }
        reordenarPorCategoria();
      }

      function reordenarPorCategoria(){
        var contenedor = document.getElementById("ofertasRelacionadas");
        if(!contenedor){ return; }
        var tituloEntrada = document.querySelector(".empleo-cabecera h1");
        if(!tituloEntrada){ return; }
        var catEntrada = document.querySelector(".empleo-cabecera .empleo-categoria");
        var reglaActual = resolverRegla(
          catEntrada ? catEntrada.textContent : "",
          tituloEntrada.textContent
        );
        if(!reglaActual || reglaActual.c === "Otros"){ return; }
        var grid = contenedor.querySelector(".relacionados-grid") || contenedor;

        function soloTarjetas(){
          var cards = [];
          for(var n=0;n<grid.children.length;n++){
            var el = grid.children[n];
            if(el && el.classList && el.classList.contains("relacionado-card")){
              cards.push(el);
            }
          }
          return cards;
        }

        var tarjetas = soloTarjetas();
        if(tarjetas.length < 2){ return; }

        var extras = grid.children.length - tarjetas.length;
        if(extras > 0){ return; }

        var mismas = [];
        var resto = [];
        for(var i=0;i<tarjetas.length;i++){
          var tituloTarjeta = tarjetas[i].querySelector(".relacionado-titulo");
          var etiquetaTarjeta = tarjetas[i].querySelector(".relacionado-etiqueta");
          var regla = resolverRegla(
            etiquetaTarjeta ? etiquetaTarjeta.textContent : "",
            tituloTarjeta ? tituloTarjeta.textContent : ""
          );
          if(regla && regla.c === reglaActual.c){
            mismas.push(tarjetas[i]);
          } else {
            resto.push(tarjetas[i]);
          }
        }
        if(!mismas.length){ return; }
        var orden = mismas.concat(resto);
        var actual = soloTarjetas();
        var igual = true;
        for(var j=0;j<orden.length;j++){
          if(actual[j] !== orden[j]){
            igual = false;
            break;
          }
        }
        if(igual){ return; }
        for(var k=0;k<orden.length;k++){
          grid.appendChild(orden[k]);
        }
      }

      function corregirCabeceraEntrada(){
        var etiquetaCategoria = document.querySelector(".empleo-cabecera .empleo-categoria");
        var tituloEntrada = document.querySelector(".empleo-cabecera h1");
        if(!etiquetaCategoria || !tituloEntrada){ return; }
        if(etiquetaCategoria.getAttribute("data-corregida") === "1"){ return; }
        var regla = resolverRegla(
          etiquetaCategoria.textContent,
          tituloEntrada.textContent
        );
        if(regla && etiquetaCategoria.textContent !== regla.c){
          etiquetaCategoria.textContent = regla.c;
        }
        etiquetaCategoria.setAttribute("data-corregida", "1");
      }

      var _corrBloqueando = false;
      function ejecutarCorreccion(){
        if(_corrBloqueando){ return; }
        _corrBloqueando = true;
        try {
          corregirCabeceraEntrada();
          corregirTarjetas();
        } finally {
          _corrBloqueando = false;
        }
      }

ejecutarCorreccion();
      if(window.MutationObserver){
        var objetivo = document.getElementById("ofertasRelacionadas");
        if(objetivo){
          new MutationObserver(function(){
            if(_corrBloqueando){ return; }
            _corrBloqueando = true;
            try {
              corregirCabeceraEntrada();
              corregirTarjetas();
            } finally {
              _corrBloqueando = false;
            }
          }).observe(
            objetivo,
            { childList: true, subtree: true, characterData: false, attributes: false }
          );
        }
      }

  } catch(e) { console.error("[Corrector Universal] Error:", e); }
    })();

    /* =========================================================
       GADGET NAVEGACIâ€œN FLOTANTE (Inicio/Empleos/Becas/ArtÃ­culos)
       Inyecta una barra inferior fija en pÃ¡ginas y entradas del
       portal para poder cambiar de secciÃ³n con un toque.
       ========================================================= */
    (function(){
  try {

      "use strict";

      function esPortal(){
        var pathname = location.pathname || "";
        var esPagina = pathname.indexOf("/p/") === 0;
        var esEntrada = /^\/\d{4}\/\d{2}\//.test(pathname);
        return !!(
          document.querySelector(".portal-empleos") ||
          document.querySelector(".portal-navport") ||
          document.querySelector(".empleo-individual") ||
          document.querySelector(".portal-header") ||
          document.querySelector(".portal-menu") ||
          document.querySelector(".portal-logo") ||
          document.querySelector(".portal-footer") ||
          document.querySelector(".hub-grid") ||
          esPagina ||
          esEntrada
        );
      }

      var ICONOS = {
        inicio:"<path d=\"M3 11l9-8 9 8\"></path><path d=\"M5 10v10h14V10\"></path><path d=\"M9 20v-6h6v6\"></path>",
        empleos:"<rect x=\"4\" y=\"7\" width=\"16\" height=\"13\" rx=\"2\"></rect><path d=\"M9 7V5h6v2\"></path><path d=\"M4 12h16\"></path>",
        becas:"<path d=\"M3 9l9-5 9 5-9 5z\"></path><path d=\"M7 11.5V16c3 2 7 2 10 0v-4.5\"></path><path d=\"M21 9v6\"></path>",
        articulos:"<path d=\"M4 5h16\"></path><path d=\"M4 12h16\"></path><path d=\"M8 19h12\"></path><path d=\"M4 12h4\"></path><path d=\"M8 19l-4-7\"></path>",
        cursos:"<path d=\"M4 5h16v14H4z\"></path><path d=\"M8 9h8\"></path><path d=\"M8 13h8\"></path><path d=\"M8 17h5\"></path>"};

      function rutaActual(){
        return decodeURIComponent(location.pathname || "/");
      }

      function esActiva(url){
        if(url === "/"){
          return rutaActual() === "/" || rutaActual() === "/index.html";
        }
        return rutaActual().indexOf(url.replace(/^\//,"/")) !== -1;
      }

      function construir(){
        if(document.querySelector(".portal-navport") || !esPortal()){ return; }
        var enlaces = [
          { etiqueta: "Inicio", icono: ICONOS.inicio, url: "/" },
          { etiqueta: "Empleos", icono: ICONOS.empleos, url: "/p/empleos.html" },
          { etiqueta: "Becas", icono: ICONOS.becas, url: "/p/becas.html" },
          { etiqueta: "ArtÃ­culos", icono: ICONOS.articulos, url: "/p/articulos.html" },
          { etiqueta: "Cursos", icono: ICONOS.cursos, url: "/p/cursos.html" }
        ];
        var nav = document.createElement("nav");
        nav.className = "portal-navport";
        nav.setAttribute("aria-label", "NavegaciÃ³n principal");
        for(var i=0;i<enlaces.length;i++){
          var a = document.createElement("a");
          a.href = enlaces[i].url;
          if(esActiva(enlaces[i].url)){
            a.className = "activo";
          }
          a.innerHTML =
            "<svg viewBox=\"0 0 24 24\" aria-hidden=\"true\">" +
            enlaces[i].icono +
            "</svg><span>" + enlaces[i].etiqueta + "</span>";
          nav.appendChild(a);
        }
        document.body.appendChild(nav);
        document.body.classList.add("portal-con-navport");
      }

      if(document.readyState === "loading"){
        document.addEventListener("DOMContentLoaded", construir);
      } else {
        construir();
      }

  } catch(e) { console.error("[Navport Flotante] Error:", e); }
    })();

    /* =========================================================
       AVISO DE CONVOCATORIA CERRADA EN ENTRADAS INDIVIDUALES
       ========================================================= */
    (function(){
  try {
      "use strict";
      var pathname = location.pathname || "";
      if(!/^\/\d{4}\/\d{2}\//.test(pathname)) return;

      function parsearFechaLocal(str){
        if(!str) return null;
        var s = str.trim();
        var m = s.match(/^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})$/);
        if(m) return new Date(parseInt(m[3],10), parseInt(m[2],10)-1, parseInt(m[1],10));
        var m2 = s.match(/^(\d{4})[\/\-](\d{1,2})[\/\-](\d{1,2})$/);
        if(m2) return new Date(parseInt(m2[1],10), parseInt(m2[2],10)-1, parseInt(m2[3],10));
        var d = new Date(s);
        return isNaN(d.getTime()) ? null : d;
      }

      function detectar(){
        var html = document.querySelector(".post-body") || document.querySelector(".entry-content") || document.body;
        if(!html) return;
        var texto = html.innerHTML || "";
        var m = texto.match(/Fecha de cierre[:\s]*<\/(?:b|strong)>\s*([^<\n]+)/i);
        if(!m) return;
        var fecha = parsearFechaLocal(m[1]);
        if(!fecha) return;
        var hoy = new Date();
        hoy.setHours(0,0,0,0);
        if(fecha < hoy){
          var banner = document.createElement("div");
          banner.style.cssText = "background:#dc2626;color:#fff;text-align:center;padding:14px 20px;border-radius:10px;margin:16px 0;font-family:Arial,sans-serif;font-weight:800;font-size:15px;letter-spacing:1px;box-shadow:0 4px 12px rgba(220,38,38,.3);";
          banner.textContent = "CONVOCATORIA CERRADA";
          var contenedor = document.querySelector(".post-outer") || document.querySelector(".post") || document.querySelector("article") || document.body;
          if(contenedor && contenedor.firstChild){
            contenedor.insertBefore(banner, contenedor.firstChild);
          }
        }
      }

      if(document.readyState === "loading"){
        document.addEventListener("DOMContentLoaded", detectar);
      } else {
        detectar();
      }
  } catch(e) { console.error("[Aviso Convocatoria Cerrada] Error:", e); }
    })();

    /* =========================================================
       BECAS RECOMENDADAS EN ENTRADAS INDIVIDUALES
       ========================================================= */
    (function(){
  try {
      "use strict";
      var pathname = location.pathname || "";
      if(!/^\/\d{4}\/\d{2}\//.test(pathname)) return;

      function parsearFechaLocal(str){
        if(!str) return null;
        var s = str.trim();
        var m = s.match(/^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})$/);
        if(m) return new Date(parseInt(m[3],10), parseInt(m[2],10)-1, parseInt(m[1],10));
        var m2 = s.match(/^(\d{4})[\/\-](\d{1,2})[\/\-](\d{1,2})$/);
        if(m2) return new Date(parseInt(m2[1],10), parseInt(m2[2],10)-1, parseInt(m2[3],10));
        var d = new Date(s);
        return isNaN(d.getTime()) ? null : d;
      }

      function normalizarTipoBecaLocal(tipo){
        var t = (tipo || "").toLowerCase()
          .normalize("NFD").replace(/[\u0300-\u036f]/g,"")
          .replace(/[^a-z0-9\s]/g,"");
        if(/universitari/.test(t)) return "universitaria";
        if(/no\s*universitari|tecnico|tecnolog/.test(t)) return "no-universitaria";
        if(/movilidad|intercambio|estudio.+exterior|extranjero/.test(t)) return "movilidad";
        if(/idioma|lengua|ingles|frances|aleman|espanol|idiomas/.test(t)) return "idiomas";
        if(/investig|ciencia|cientific/.test(t)) return "investigacion";
        if(/excelenc|merito|academica|rendimiento/.test(t)) return "excelencia";
        if(/social|comunitari|voluntari|desarrollo/.test(t)) return "sociales";
        if(/deport|atlet|futbol|basquet/.test(t)) return "deportivas";
        if(/beca/.test(t)) return "universitaria";
        return "otros";
      }

      function claseVisualBecaLocal(tipo){
        var mapa = {
          "universitaria":"visual-universitaria",
          "no-universitaria":"visual-no-universitaria",
          "movilidad":"visual-movilidad",
          "idiomas":"visual-idiomas",
          "investigacion":"visual-investigacion",
          "excelencia":"visual-excelencia",
          "sociales":"visual-sociales",
          "deportivas":"visual-deportivas"
        };
        var clave = (tipo || "").toLowerCase()
          .replace(/\s+/g,"-")
          .replace(/[^a-z0-9-]/g,"");
        return mapa[clave] || "visual-beca-default";
      }

      function iconoBecaLocal(tipo){
        var mapa = {
          "universitaria":"<svg viewBox='0 0 24 24' width='20' height='20' fill='none' stroke='currentColor' stroke-width='2'><path d='M12 2L2 7l10 5 10-5-10-5z'/><path d='M2 17l10 5 10-5'/><path d='M2 12l10 5 10-5'/></svg>",
          "movilidad":"<svg viewBox='0 0 24 24' width='20' height='20' fill='none' stroke='currentColor' stroke-width='2'><circle cx='12' cy='12' r='10'/><path d='M2 12h20'/><path d='M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z'/></svg>",
          "idiomas":"<svg viewBox='0 0 24 24' width='20' height='20' fill='none' stroke='currentColor' stroke-width='2'><path d='M5 8l6 6'/><path d='M4 14l6-6 2-3'/><path d='M2 5h12'/><path d='M7 2v3'/><path d='M22 22l-5-10-5 10'/><path d='M14 18h6'/></svg>",
          "investigacion":"<svg viewBox='0 0 24 24' width='20' height='20' fill='none' stroke='currentColor' stroke-width='2'><path d='M9 3h6v11l-3 3-3-3V3z'/><path d='M6 21h12'/></svg>",
          "default":"<svg viewBox='0 0 24 24' width='20' height='20' fill='none' stroke='currentColor' stroke-width='2'><path d='M12 2L2 7l10 5 10-5-10-5z'/><path d='M2 17l10 5 10-5'/></svg>"
        };
        var clave = (tipo || "").toLowerCase().replace(/\s+/g,"-");
        return mapa[clave] || mapa["default"];
      }

      function crearTarjetaBecaLocal(beca){
        if(window._becasUtils && typeof window._becasUtils.crearTarjetaBeca === "function"){
          try{
            return window._becasUtils.crearTarjetaBeca(beca);
          }catch(eErrLocal){}
        }
        var tarjeta = document.createElement("article");
        tarjeta.className = "empleo-card beca-card beca-card-pendiente";
        tarjeta.setAttribute("data-pendiente", "1");
        var intentos = 0;
        var timer = setInterval(function(){
          intentos++;
          if(window._becasUtils && typeof window._becasUtils.crearTarjetaBeca === "function"){
            clearInterval(timer);
            try{
              var real = window._becasUtils.crearTarjetaBeca(beca);
              if(tarjeta.parentNode) tarjeta.parentNode.replaceChild(real, tarjeta);
            }catch(eRep){}
            return;
          }
          if(intentos > 40) clearInterval(timer);
        }, 50);
        return tarjeta;
      }

      function cargarRecomendadas(){
        var contenedor = document.querySelector(".post-body") || document.querySelector(".entry-content") || document.querySelector(".post-outer") || document.querySelector(".post") || document.querySelector("article");
        if(!contenedor) return;
        var html = contenedor.innerHTML || "";
        var tipoMatch = html.match(/Tipo:\s*([^<\n]+)/i);
        var ramaMatch = html.match(/Rama:\s*([^<\n]+)/i);
        var tipoActual = tipoMatch ? tipoMatch[1].trim().toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g,"") : "";
        var ramaActual = ramaMatch ? ramaMatch[1].trim().toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g,"") : "";
        var urlActual = location.href.split("#")[0].split("?")[0].replace(/\/+$/,"");
        var tituloEl = contenedor.querySelector("h1") || contenedor.querySelector("h2");
        var tituloActual = tituloEl ? tituloEl.textContent.trim() : "";

        fetch("/feeds/posts/default/-/Beca?alt=json&start-index=1&max-results=30")
          .then(function(r){ return r.json(); })
          .then(function(data){
            var entries = data.feed.entry || [];
            var similares = [];
            for(var i = 0; i < entries.length; i++){
              var entry = entries[i];
              var link = "";
              if(entry.link){
                for(var j = 0; j < entry.link.length; j++){
                  if(entry.link[j].rel === "alternate"){ link = entry.link[j].href; break; }
                }
              }
              if(!link || _mismaUrlRel(link, urlActual)) continue;
              var entryHtml = (entry.content && entry.content.$t) || "";
              var entryTipo = "";
              var tm = entryHtml.match(/Tipo:\s*([^<\n]+)/i);
              if(tm) entryTipo = tm[1].trim().toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g,"");
              var entryRama = "";
              var rm = entryHtml.match(/Rama:\s*([^<\n]+)/i);
              if(rm) entryRama = rm[1].trim().toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g,"");
              var score = 0;
              var entryHtmlNorm = entryHtml.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g,"");
              if(tipoActual && entryTipo && entryTipo === tipoActual) score += 2;
              if(ramaActual && entryRama && entryRama === ramaActual) score += 2;
              if(tipoActual && entryHtmlNorm.indexOf(tipoActual) !== -1) score += 1;
              if(ramaActual && entryHtmlNorm.indexOf(ramaActual) !== -1) score += 1;
              if(score === 0) score = 1;
              {
                var titulo = entry.title ? entry.title.$t : "";
                if(tituloActual && _normHtml(titulo) === _normHtml(tituloActual)) continue;
                var institucion = "";
                var im = entryHtml.match(/Instituci[oÃ³]n:\s*([^<\n]+)/i);
                if(im) institucion = im[1].trim();
                var fechaInicio = "";
                var fim = entryHtml.match(/Fecha de inicio:\s*([^<\n]+)/i);
                if(fim) fechaInicio = fim[1].trim();
                var fechaFin = "";
                var fm = entryHtml.match(/Fecha de cierre:\s*([^<\n]+)/i);
                if(fm) fechaFin = fm[1].trim();
                var cobertura = "";
                var cm = entryHtml.match(/Cobertura:\s*([^<\n]+)/i);
                if(cm) cobertura = cm[1].trim();
                var nivel = "";
                var nm = entryHtml.match(/Nivel:\s*([^<\n]+)/i);
                if(nm) nivel = nm[1].trim();
                var zonaR = "";
                var zm = entryHtml.match(/Zona:\s*([^<\n]+)/i);
                if(zm) zonaR = zm[1].trim();
                var paisR = "";
                var pm = entryHtml.match(/Pa[iÃ­]s:\s*([^<\n]+)/i);
                if(pm) paisR = pm[1].trim();
                var dirR = "";
                var dm = entryHtml.match(/Dirigido a:\s*([^<\n]+)/i);
                if(dm) dirR = dm[1].trim();
                var durR = "";
                var dum = entryHtml.match(/Duraci[oÃ³]n:\s*([^<\n]+)/i);
                if(dum) durR = dum[1].trim();
                var apoyoR = "";
                var am = entryHtml.match(/Apoyo:\s*([^<\n]+)/i);
                if(am) apoyoR = am[1].trim();
                var imagenR = "";
                var imUrl = entryHtml.match(/Imagen:\s*(https?:\/\/[^\s<]+)/i);
                if(imUrl) imagenR = imUrl[1].trim();
                else if(entry.media$thumbnail && entry.media$thumbnail.url){
                  imagenR = entry.media$thumbnail.url;
                }
                similares.push({
                  titulo:titulo,
                  url:link,
                  institucion:institucion,
                  tipo:tm?tm[1].trim():"",
                  rama:rm?rm[1].trim():"",
                  nivel:nivel,
                  cobertura:cobertura,
                  zona:zonaR,
                  pais:paisR,
                  dirigidoA:dirR,
                  duracion:durR,
                  apoyo:apoyoR,
                  imagen:imagenR,
                  fechaInicio:fechaInicio,
                  fechaCierre:fechaFin,
                  score:score
                });
              }
            }
            for(var i = 0; i < similares.length; i++) similares[i]._r = Math.random();
            similares.sort(function(a,b){
              if(b.score !== a.score) return b.score - a.score;
              return a._r - b._r;
            });
            similares = similares.slice(0,12);
            if(similares.length === 0) return;

            var seccion = document.createElement("div");
            seccion.className = "seccion-relacionada seccion-becas-rel";
            seccion.setAttribute("data-rel", "becas");
            seccion.style.cssText = "margin-top:40px;padding-top:24px;border-top:2px solid #e5e7eb;";
            seccion.innerHTML = '<h3 style="margin:0 0 16px;font-size:16px;color:#0f4c81;font-weight:800;">Becas similares</h3>';

            var grid = document.createElement("div");
            grid.className = "empleos-grid rel-scroll";

            var pasoRelBecas = (window.pasoAnuncio ? window.pasoAnuncio(grid) : 6);
            for(var k = 0; k < similares.length; k++){
              var s = similares[k];
              s.fechaFin = s.fechaCierre;
              s.fechaPublicacion = "";
              var tarjeta = crearTarjetaBecaLocal(s);
              grid.appendChild(tarjeta);
              if(k > 0 && (k + 1) % pasoRelBecas === 0 && k < similares.length - 1){
                var adB = document.createElement("div");
                adB.className = "empleo-anuncio empleo-anuncio-feed rel-ad";
                adB.innerHTML = '<div class="empleo-anuncio-inner">Espacio publicitario</div>';
                grid.appendChild(adB);
              }
            }
            seccion.appendChild(grid);
            _insertarRelacionada(contenedor, seccion, "becas");
          })
          .catch(function(){});
      }

      if(document.readyState === "loading"){
        document.addEventListener("DOMContentLoaded", cargarRecomendadas);
      } else {
        cargarRecomendadas();
      }
  } catch(e) { console.error("[Becas Recomendadas] Error:", e); }
    })();

    /* ============================================================
       FUNCIONES MAESTRAS UNIFICADAS - A PRUEBA DE ERRORES
       Disponibles para TODOS los IIFEs (entradas, cursos, etc.)
       ============================================================ */
    var _EXTYes = /^(s[iÃ­]|si\b|yes|con\s+certificad|incluye|otorga|dispone|sÃ­|disponible|emit[ie]|obtiene|recibe|genera|acredita|constancia|badge|credencial|titulo)/i;
    var _EXTNo = /^(no\s*(?:aplica|disponible|incluido|especificado|existe|otorga|ofrece|brinda|entrega|emite)?|none|sin\s+certificad|n\/?a)/i;

    function _mismaUrlRel(a, b){
      if(!a || !b) return false;
      var n = function(u){
        try{
          var el = document.createElement("a");
          el.href = String(u);
          return (el.host + el.pathname).replace(/\/+$/,"").toLowerCase();
        }catch(e){
          return String(u).split("#")[0].split("?")[0].replace(/\/+$/,"").toLowerCase();
        }
      };
      return n(a) === n(b);
    }

    function _detectarTipoEntrada(){
      if(document.querySelector(".empleo-individual")) return "empleos";
      var cont = document.querySelector(".post-body") || document.querySelector(".entry-content") || document.querySelector(".post-outer") || document.querySelector(".post") || document.querySelector("article");
      var html = cont ? (cont.innerHTML || "") : "";
      if(/\bDirigido a\s*:/i.test(html) || (/\bZona\s*:/i.test(html) && /\bCobertura\s*:/i.test(html))) return "becas";
      if(/\bDuraci[oÃ³]n\s*[:=]/i.test(html) || /\bModalidad\s*[:=]/i.test(html)){
        if(!/\bDirigido a\s*:/i.test(html)) return "cursos";
      }
      if(/\bTema\s*[:=]/i.test(html) && !/\bDuraci[oÃ³]n\s*[:=]/i.test(html) && !/\bModalidad\s*[:=]/i.test(html)) return "articulos";
      if(/\bSalario\s*:/i.test(html) || /\bSueldo\s*:/i.test(html) || /\bUbicaci[oÃ³]n\s*:/i.test(html)) return "empleos";
      return "";
    }

    function _tipoEntradaActual(){
      if(!window._tipoEntradaCache){
        var t = _detectarTipoEntrada();
        if(t) window._tipoEntradaCache = t;
      }
      return window._tipoEntradaCache || "";
    }

    function _asegurarHeaderTambien(contenedor){
      var parent = contenedor.parentNode;
      var header = parent.querySelector("[data-rel-header='tambien']");
      if(header) return header;
      header = document.createElement("div");
      header.setAttribute("data-rel-header", "tambien");
      header.style.cssText = "margin-top:40px;padding-top:24px;border-top:2px solid #e5e7eb;";
      header.innerHTML = '<h3 style="margin:0 0 16px;font-size:16px;color:#0f4c81;font-weight:800;">TambiÃ©n te puede interesar</h3>';
      var ref = contenedor.nextSibling;
      while(ref && ref.nodeType === 1){
        if(ref.getAttribute && ref.getAttribute("data-rel-header") === "tambien") return ref;
        var tier = ref.getAttribute ? ref.getAttribute("data-rel-tier") : "";
        var rel = ref.getAttribute ? ref.getAttribute("data-rel") : "";
        if(tier === "cross") break;
        if(tier === "primary" || rel){ ref = ref.nextSibling; continue; }
        break;
      }
      parent.insertBefore(header, ref);
      return header;
    }

    function _insertarRelacionada(contenedor, seccion, modo){
      if(!contenedor || !seccion || !contenedor.parentNode) return;
      var tipo = seccion.getAttribute ? (seccion.getAttribute("data-rel") || "") : "";
      var tipoEntrada = _tipoEntradaActual();
      var esMisma = !!(tipoEntrada && tipo && tipo === tipoEntrada);
      if(tipoEntrada && tipo){
        seccion.setAttribute("data-rel-tier", esMisma ? "primary" : "cross");
      }else{
        seccion.setAttribute("data-rel-tier", "auto");
      }

      if(esMisma || !tipoEntrada){
        var ref = contenedor.nextSibling;
        while(ref && ref.nodeType === 1){
          if(ref.getAttribute && ref.getAttribute("data-rel-header") === "tambien") break;
          if(ref.getAttribute && ref.getAttribute("data-rel-tier") === "cross") break;
          var t = ref.getAttribute ? ref.getAttribute("data-rel-tier") : "";
          var r = ref.getAttribute ? ref.getAttribute("data-rel") : "";
          if(t === "primary" || r){ ref = ref.nextSibling; continue; }
          break;
        }
        contenedor.parentNode.insertBefore(seccion, ref);
        return;
      }

      var header = _asegurarHeaderTambien(contenedor);
      seccion.style.cssText = "margin-top:24px;";
      var refC = header.nextSibling;
      while(refC && refC.nodeType === 1){
        var tc = refC.getAttribute ? refC.getAttribute("data-rel-tier") : "";
        var rc = refC.getAttribute ? refC.getAttribute("data-rel") : "";
        var hc = refC.getAttribute ? refC.getAttribute("data-rel-header") : "";
        if(hc === "tambien"){ refC = refC.nextSibling; continue; }
        if(tc === "primary"){ refC = refC.nextSibling; continue; }
        if(tc === "cross" || (tc === "auto" && rc)){ refC = refC.nextSibling; continue; }
        break;
      }
      contenedor.parentNode.insertBefore(seccion, refC);
    }

    function _ext(html, etiquetas){
      if(!html) return "";
      for(var i=0;i<etiquetas.length;i++){
        var et = etiquetas[i].replace(/[.*+?^${}()|[\]\\]/g,"\\$&");
        var p1 = new RegExp("<(?:b|strong)[^>]*>[^<]{0,30}\\s*"+et+"\\s*[:\\-=]?\\s*</(?:b|strong)>\\s*([^<]*)","i");
        var m1 = html.match(p1);
        if(m1&&m1[1]&&m1[1].trim()) return m1[1].trim().replace(/[.,;:!?]+$/,"").replace(/\s+/g," ");
        var p2 = new RegExp(et+"\\s*[:\\-=]\\s*([^<\\n]+)","i");
        var m2 = html.match(p2);
        if(m2&&m2[1]&&m2[1].trim()) return m2[1].trim().replace(/[.,;:!?]+$/,"").replace(/\s+/g," ");
        var p3 = new RegExp("<(?:b|strong)[^>]*>[^<]{0,30}\\s*"+et+"\\s*[:\\-=]?\\s*</(?:b|strong)>\\s*<[^>]*>([^<]*)","i");
        var m3 = html.match(p3);
        if(m3&&m3[1]&&m3[1].trim()) return m3[1].trim().replace(/[.,;:!?]+$/,"").replace(/\s+/g," ");
      }
      return "";
    }

    function _detCert(html){
      if(!html) return "";
      var l=html.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g,"");
      var bp=/<(?:b|strong)[^>]*>\s*[^<]{0,30}\s*certificad[oe]o?\s*(?:y\s*constancia|academico)?\s*[:=\-]?\s*<\/(?:b|strong)>\s*/i;
      var lp=/certificad[oe]o?\s*(?:y\s*constancia|academico)?\s*[:=\-]?\s*/i;
      var af="";
      var m=l.match(bp);
      if(m) af=l.substr(m.index+m[0].length,200);
      if(!af){var m2=l.match(lp);if(m2) af=l.substr(m2.index+m2[0].length,200);}
      if(!af){var m3=l.match(/certificad[oe]o?\s*[:=\-]\s*\S/i);if(m3) af=l.substr(m3.index,200);}
      if(af){
        var v=af.replace(/<[^>]+>/g,"").replace(/\s+/g," ").trim().substring(0,100).replace(/^[:=\-]\s*/,"").trim();
        if(_EXTYes.test(v)) return "si";
        if(_EXTNo.test(v)) return "no";
        if(v.length>0&&v.length<80) return "si";
      }
      if(/certifico|certificad|constancia|diploma|acredit|badge|credencial|titulo|attest/i.test(html)&&!/no\s*(?:hay|existe|aplica|tiene|cuenta|dispone|otorga|ofrece|brinda)/i.test(html)) return "si";
      return "";
    }

    function _normTipo(tipo, titulo){
      var t=(tipo||"").toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g,"").replace(/[^a-z0-9\s]/g,"");
      var r="otros";
      if(/program|codig|desarroll|tecnolog|software|cibersegur|redes|sistema|datos|python|javascript|html|css|base.?datos|ia|inteligenc|artificial|machine|data|analit|cloud|devops|agil|scrum|testing|qa|automatiz|robot|blockchain|iot|internet.?cosas|server|linux|windows|docker|kubernetes|git|api|rest|microserv|segur|firewall|pentest/.test(t)) r="tecnologia";
      else if(/marketing|seo|sem|social|digital|community|contenido|negoci|empres|emprend|trading|inversion|contab|presupuest|finanz|admin|gestion|recursos.?humanos|oficina|excel|calidad|proces|estrateg|proyect|certific|profesional|diplom|ventas|comerci|crm|erp|supply|logist|compr|licita|adquisi|contrata|factura|boleta|impuest|tribut|nomina|planilla|sueldo|capacit|formac|coach|liderazgo|productiv|lean|kpi|business/.test(t)) r="negocios";
      else if(/competenc|adapt|liderazgo|comunic|habilidad|soft.?skill|innovacion|pensamiento|creativ|futuro.?trabajo|desarrollo.?personal|motivacion|resilienc|mindful|ergonomi|prevencion/.test(t)) r="desarrollo";
      else if(/dise|graphic|ux|ui|visual|figma|canva|creativ|arte|fotograf|video|m[uu]sica|ilustr|animacion|motion|3d|branding|logo|poster|banner|social.?media|content.?creator|edicion|photoshop|premiere|illustrator|blender/.test(t)) r="diseno";
      else if(/idioma|ingl|franc|aleman|espanol|lengua|ses|japones|chino|portugues|italiano|arabe|ruso|toefl|ielts|dele|language|fluency|grammar/.test(t)) r="idiomas";
      if(r==="otros"&&titulo){
        var ti=titulo.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g,"").replace(/[^a-z0-9\s]/g,"");
        if(/program|codig|desarroll|tecnolog|software|cibersegur|redes|sistema|datos|python|javascript|html|css|base.?datos|ia|inteligenc|artificial|machine|data|analit|cloud|devops|testing|automatiz|blockchain|segur|firewall|linux|docker/.test(ti)) r="tecnologia";
        else if(/marketing|seo|social|digital|community|contenido|negoci|empres|emprend|trading|inversion|contab|presupuest|finanz|admin|gestion|recursos.?humanos|oficina|excel|calidad|proces|estrateg|proyect|certific|profesional|diplom|ventas|comerci|crm|logist|capacit|formac|liderazgo|productiv|lean|kpi|business/.test(ti)) r="negocios";
        else if(/competenc|adapt|liderazgo|comunic|habilidad|soft.?skill|innovacion|pensamiento|creativ|futuro.?trabajo|desarrollo.?personal|motivacion/.test(ti)) r="desarrollo";
        else if(/dise|graphic|ux|ui|visual|figma|canva|creativ|arte|fotograf|video|m[uu]sica|ilustr|animacion|branding|logo|edicion|photoshop|premiere/.test(ti)) r="diseno";
        else if(/idioma|ingl|franc|aleman|espanol|japones|chino|portugues|italiano|toefl|ielts|language/.test(ti)) r="idiomas";
      }
      return r;
    }

    function _normHtml(s){
      return(s||"").toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g,"").replace(/<[^>]+>/g," ").replace(/&[a-z]+;/g," ").replace(/[^a-z0-9\s]/g," ").replace(/\s+/g," ").trim();
    }

    function _parseFecha(s){
      if(!s) return null;
      var t=(s||"").trim();
      var m=t.match(/^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})$/);
      if(m) return new Date(parseInt(m[3],10),parseInt(m[2],10)-1,parseInt(m[1],10));
      var m2=t.match(/^(\d{4})[\/\-](\d{1,2})[\/\-](\d{1,2})$/);
      if(m2) return new Date(parseInt(m2[1],10),parseInt(m2[2],10)-1,parseInt(m2[3],10));
      var d=new Date(t);
      return isNaN(d.getTime())?null:d;
    }

    function _badgeCert(certificado){
      var c=(certificado||"").toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g,"");
      if(/^s[iÃ­]/.test(c)){
        var d=document.createElement("div");
        d.style.cssText="display:inline-flex;align-items:center;gap:4px;background:#ecfdf5;color:#065f46;padding:3px 8px;border-radius:4px;font-size:11px;font-weight:600;margin-bottom:8px;";
        d.innerHTML="&#10003; Con certificado";
        return d;
      }
      if(/^no/.test(c)){
        var d2=document.createElement("div");
        d2.style.cssText="display:inline-flex;align-items:center;gap:4px;background:#fef2f2;color:#991b1b;padding:3px 8px;border-radius:4px;font-size:11px;font-weight:600;margin-bottom:8px;";
        d2.innerHTML="&#10007; Sin certificado";
        return d2;
      }
      return null;
    }

    function _claseVisual(tipo){
      var m={"tecnologia":"visual-tecnologia","negocios":"visual-negocios","desarrollo":"visual-desarrollo","diseno":"visual-diseno","idiomas":"visual-idiomas"};
      var k=(tipo||"").toLowerCase().replace(/\s+/g,"-").replace(/[^a-z0-9-]/g,"");
      return m[k]||"visual-curso-default";
    }

    function _iconoCurso(tipo){
      var m={
        "tecnologia":"<svg viewBox='0 0 24 24' width='20' height='20' fill='none' stroke='currentColor' stroke-width='2'><polyline points='16 18 22 12 16 6'/><polyline points='8 6 2 12 8 18'/></svg>",
        "negocios":"<svg viewBox='0 0 24 24' width='20' height='20' fill='none' stroke='currentColor' stroke-width='2'><path d='M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2'/><rect x='8' y='2' width='8' height='4' rx='1'/><path d='M9 14l2 2 4-4'/></svg>",
        "desarrollo":"<svg viewBox='0 0 24 24' width='20' height='20' fill='none' stroke='currentColor' stroke-width='2'><path d='M22 12h-4l-3 9L9 3l-3 9H2'/></svg>",
        "diseno":"<svg viewBox='0 0 24 24' width='20' height='20' fill='none' stroke='currentColor' stroke-width='2'><circle cx='13.5' cy='6.5' r='.5'/><circle cx='17.5' cy='10.5' r='.5'/><circle cx='8.5' cy='7.5' r='.5'/><circle cx='6.5' cy='12.5' r='.5'/><path d='M12 2C6.5 2 2 6.5 2 12s4.5 10 10 10c.926 0 1.648-.746 1.648-1.688 0-.437-.18-.835-.437-1.125-.29-.289-.438-.652-.438-1.125a1.64 1.64 0 0 1 1.668-1.668h1.996c3.051 0 5.555-2.503 5.555-5.554C21.965 6.012 17.461 2 12 2z'/></svg>",
        "idiomas":"<svg viewBox='0 0 24 24' width='20' height='20' fill='none' stroke='currentColor' stroke-width='2'><path d='M5 8l6 6'/><path d='M4 14l6-6 2-3'/><path d='M2 5h12'/><path d='M7 2v3'/><path d='M22 22l-5-10-5 10'/><path d='M14 18h6'/></svg>",
        "default":"<svg viewBox='0 0 24 24' width='20' height='20' fill='none' stroke='currentColor' stroke-width='2'><path d='M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z'/><path d='M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z'/></svg>"
      };
      var k=(tipo||"").toLowerCase().replace(/\s+/g,"-");
      return m[k]||m["default"];
    }

    function _crearTarjetaCursoUnica(curso){
      var tarjeta=document.createElement("article");
      tarjeta.className="empleo-card";
      var tipoN=_normTipo(curso.tipo,curso.titulo);
      tarjeta.setAttribute("data-tipo",tipoN);
      tarjeta.setAttribute("data-nivel",curso.nivel||"");
      tarjeta.setAttribute("data-modalidad",curso.modalidad||"");
      tarjeta.setAttribute("data-institucion",curso.institucion||"");
      var certLower=(curso.certificado||"").toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g,"");
      tarjeta.setAttribute("data-certificado",/^s[iÃ­]/.test(certLower)?"si":(/^no/.test(certLower)?"no":"no"));

      var visual=document.createElement("div");
      visual.className="empleo-visual "+_claseVisual(tipoN);
      var etiq=document.createElement("span");
      etiq.className="empleo-etiqueta";
      etiq.textContent=tipoN.charAt(0).toUpperCase()+tipoN.slice(1);
      var icon=document.createElement("span");
      icon.className="empleo-icono";
      icon.innerHTML=_iconoCurso(tipoN);
      visual.appendChild(etiq);
      visual.appendChild(icon);

      var hoy=new Date();hoy.setHours(0,0,0,0);
      var estado="abierta";
      if(curso.fechaCierre){var ff=_parseFecha(curso.fechaCierre);if(ff&&ff<hoy) estado="cerrada";}
      tarjeta.setAttribute("data-estado",estado);

      if(estado==="cerrada"){
        tarjeta.classList.add("beca-cerrada-card");
        var ing=document.createElement("span");
        ing.className="empleo-cierre empleo-cierre-cerrada";
        ing.textContent="NO DISPONIBLE";
        ing.style.top="12px";
        visual.appendChild(ing);
      }else{
        var vig=document.createElement("span");
        vig.className="beca-vigente";
        vig.textContent="DISPONIBLE";
        vig.style.top="12px";
        visual.appendChild(vig);
      }

      var cont=document.createElement("div");
      cont.className="empleo-contenido";
      var tit=document.createElement("h3");
      tit.className="empleo-titulo";
      tit.textContent=curso.titulo||"Curso sin tÃ­tulo";
      var emp=document.createElement("div");
      emp.className="empleo-empresa";
      emp.textContent=curso.institucion||"InstituciÃ³n no especificada";
      var dat=document.createElement("div");
      dat.className="empleo-datos";

      if(curso.duracion){
        var dur=document.createElement("span");dur.className="empleo-dato";
        dur.innerHTML="<svg viewBox='0 0 24 24' width='13' height='13' fill='none' stroke='currentColor' stroke-width='2'><circle cx='12' cy='12' r='10'/><polyline points='12 6 12 12 16 14'/></svg> "+curso.duracion;
        dat.appendChild(dur);
      }
      if(curso.nivel){
        var niv=document.createElement("span");niv.className="empleo-dato";
        niv.innerHTML="<svg viewBox='0 0 24 24' width='13' height='13' fill='none' stroke='currentColor' stroke-width='2'><path d='M12 2L2 7l10 5 10-5-10-5z'/><path d='M2 17l10 5 10-5'/></svg> "+curso.nivel;
        dat.appendChild(niv);
      }
      if(curso.modalidad){
        var mod=document.createElement("span");mod.className="empleo-dato";
        mod.innerHTML="<svg viewBox='0 0 24 24' width='13' height='13' fill='none' stroke='currentColor' stroke-width='2'><rect x='2' y='3' width='20' height='14' rx='2'/><line x1='8' y1='21' x2='16' y2='21'/><line x1='12' y1='17' x2='12' y2='21'/></svg> "+curso.modalidad;
        dat.appendChild(mod);
      }

      cont.appendChild(tit);cont.appendChild(emp);cont.appendChild(dat);

      var badge=_badgeCert(curso.certificado);
      if(badge) cont.appendChild(badge);

      var tags=document.createElement("div");
      tags.className="empleo-tags";
      var arr=[];
      if(curso.nivel) arr.push(curso.nivel);
      if(curso.modalidad) arr.push(curso.modalidad);
      if(curso.duracion) arr.push(curso.duracion);
      for(var t=0;t<arr.length&&t<3;t++){
        var tg=document.createElement("span");tg.className="empleo-tag";tg.textContent=arr[t];tags.appendChild(tg);
      }
      if(arr.length>0) cont.appendChild(tags);

      var pie=document.createElement("div");
      pie.className="empleo-pie";
      var fechaPie=document.createElement("span");
      fechaPie.className="empleo-fecha";
      fechaPie.textContent="";
      var boton=document.createElement("a");
      boton.className="empleo-boton";
      boton.target="_self";
      if(estado==="cerrada"||!curso.url){
        boton.href="#";
        boton.textContent="NO DISPONIBLE";
        boton.style.opacity="0.55";
        boton.style.pointerEvents="none";
      }else{
        boton.href=curso.url;
        boton.textContent="VER CURSO";
        boton.addEventListener("click",function(e){ e.stopPropagation(); });
      }
      pie.appendChild(fechaPie);
      pie.appendChild(boton);
      cont.appendChild(pie);

      tarjeta.appendChild(visual);tarjeta.appendChild(cont);

      if(estado!=="cerrada"){
        tarjeta.style.cursor="pointer";
        tarjeta.addEventListener("click",function(){if(curso.url) window.location.href=curso.url;});
      }
      return tarjeta;
    }

    function extraerCampo(h,e){ return _ext(h,e); }
    function detectarCertificado(h){ return _detCert(h); }
    function normalizarTipoCurso(t,h){ return _normTipo(t,h); }
    function claseVisualCurso(t){ return _claseVisual(t); }
    function iconoCurso(t){ return _iconoCurso(t); }
    function crearTarjetaCurso(c){ return _crearTarjetaCursoUnica(c); }

    /* =========================================================
       CURSOS RECOMENDADOS EN ENTRADAS INDIVIDUALES
       ========================================================= */
    (function(){
  try {
      "use strict";
      var pathname = location.pathname || "";
      if(!/^\/\d{4}\/\d{2}\//.test(pathname)) return;

      function parsearFechaLocal(str){
        if(!str) return null;
        var s = str.trim();
        var m = s.match(/^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})$/);
        if(m) return new Date(parseInt(m[3],10), parseInt(m[2],10)-1, parseInt(m[1],10));
        var m2 = s.match(/^(\d{4})[\/\-](\d{1,2})[\/\-](\d{1,2})$/);
        if(m2) return new Date(parseInt(m2[1],10), parseInt(m2[2],10)-1, parseInt(m2[3],10));
        var d = new Date(s);
        return isNaN(d.getTime()) ? null : d;
      }

      function normalizarTipoCursoLocal(tipo, titulo){ return _normTipo(tipo, titulo); }

      function claseVisualCursoLocal(tipo){ return _claseVisual(tipo); }

      function iconoCursoLocal(tipo){ return _iconoCurso(tipo); }

      function crearTarjetaCursoLocal(curso){ return _crearTarjetaCursoUnica(curso); }

      function extraerCampoLocal(html, etiquetas){ return _ext(html, etiquetas); }

      function cargarCursosRecomendados(){
        var pathname = location.pathname || "";
        if(!/^\/\d{4}\/\d{2}\//.test(pathname)) return;
        var contenedor = document.querySelector(".post-body") || document.querySelector(".entry-content") || document.querySelector(".post-outer") || document.querySelector(".post") || document.querySelector("article");
        if(!contenedor) return;
        var html = contenedor.innerHTML || "";

        var norm = function(s){
          return (s||"").toLowerCase()
            .normalize("NFD").replace(/[\u0300-\u036f]/g,"")
            .replace(/<[^>]+>/g," ")
            .replace(/&[a-z]+;/g," ")
            .replace(/[^a-z0-9\s]/g," ")
            .replace(/\s+/g," ").trim();
        };
        var normHtml = norm(html);

        var extraerCampoRobusto = function(campo, valoresPosibles){
          var lhtml = html.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g,"");
          var patronBold = new RegExp("<(?:b|strong)[^>]*>[^<]{0,30}\\s*"+campo+"\\s*[:\\-=]?\\s*</(?:b|strong)>\\s*([^<]*)","i");
          var m = lhtml.match(patronBold);
          if(m && m[1] && m[1].trim()) return m[1].trim().replace(/[.,;:!?]+$/,"").replace(/\s+/g," ");
          var patronPlain = new RegExp(campo+"\\s*[:\\-=]\\s*([^<\\n]+)","i");
          var m2 = lhtml.match(patronPlain);
          if(m2 && m2[1] && m2[1].trim()) return m2[1].trim().replace(/[.,;:!?]+$/,"").replace(/\s+/g," ");
          if(valoresPosibles){
            for(var i=0;i<valoresPosibles.length;i++){
              if(lhtml.indexOf(valoresPosibles[i]) !== -1) return valoresPosibles[i];
            }
          }
          return "";
        };

        var nums = {"uno":1,"dos":2,"tres":3,"cuatro":4,"cinco":5,"seis":6,"siete":7,"ocho":8,"nueve":9,"diez":10,"once":12,"doce":12,"trece":13,"catorce":14,"quince":15,"veinte":20,"treinta":30,"cuarenta":40,"cincuenta":50,"sesenta":60,"noventa":90,"cien":100,"doscientos":200,"trescientos":300,"quinientos":500,"mil":1000};
        var extraerNumero = function(texto){
          var t = norm(texto);
          for(var palabra in nums){
            if(t.indexOf(palabra) !== -1) return nums[palabra];
          }
          var m = t.match(/(\d+[\.,]?\d*)/);
          if(m) return parseFloat(m[1].replace(",","."));
          return 0;
        };

        var duracionRaw = extraerCampoRobusto("duracion", ["horas","minutos","dias","semanas","meses"]);
        var modalidadRaw = extraerCampoRobusto("modalidad", ["virtual","presencial","hibrido","online","a distancia","semipresencial"]);
        var tipoRaw = extraerCampoRobusto("tipo", ["marketing","tecnologia","negocios","desarrollo","diseno","idiomas","ventas","ciberseguridad","contabilidad","recursos humanos","finanzas","excel","sql","python","javascript","ingles","frances","data","ia","artificial"]);
        var institucionRaw = extraerCampoRobusto("institucion", ["capacita","ministerio","universidad","instituto","fundacion","coursera","udemy","platzi","edx","miriada","openwebinars","cisco"]);
        var nivelRaw = extraerCampoRobusto("nivel", ["basico","intermedio","avanzado","principiante","experto","introductorio","fundamentos"]);
        var precioRaw = extraerCampoRobusto("precio", ["gratis","free","costo","pago","matricula"]);
        var certificadoRaw = extraerCampoRobusto("certificado", ["si","no"]);

        var tipoEntradaLocal = _tipoEntradaActual();
        var esEntradaCurso = tipoEntradaLocal === "cursos";
        var tieneCampoCurso = /Duraci[oÃ³]n\s*[:=]/i.test(html) || /Modalidad\s*[:=]/i.test(html);
        if(esEntradaCurso && !tieneCampoCurso) return;
        if(tipoEntradaLocal === "empleos" && !tieneCampoCurso) return;

        var tituloEl = contenedor.querySelector("h1") || contenedor.querySelector("h2");
        var tituloActual = tituloEl ? tituloEl.textContent.trim() : "";
        var tipoNorm = normalizarTipoCursoLocal(tipoRaw, tituloActual);
        var urlActual = location.href.split("#")[0].split("?")[0].replace(/\/+$/,"");
        var palabrasClave = norm(tituloActual).split(/\s+/).filter(function(w){ return w.length > 3; });

        fetch("/feeds/posts/default/-/Curso?alt=json&start-index=1&max-results=50")
          .then(function(r){ return r.json(); })
          .then(function(data){
            var entries = data.feed.entry || [];
            var similares = [];
            for(var i=0;i<entries.length;i++){
              var entry = entries[i];
              var link = "";
              if(entry.link){
                for(var j=0;j<entry.link.length;j++){
                  if(entry.link[j].rel==="alternate"){ link=entry.link[j].href; break; }
                }
              }
              if(!link || _mismaUrlRel(link, urlActual)) continue;
              if(_normHtml(entry.title ? entry.title.$t : "") === _normHtml(tituloActual)) continue;
              var entryHtml = (entry.content && entry.content.$t) || "";
              var entryTipo = extraerCampoLocal(entryHtml, ["Tipo","CategorÃ­a","Categoria","Ãrea"]);
              var entryTitulo = entry.title ? entry.title.$t : "";
              var entryTipoNorm = normalizarTipoCursoLocal(entryTipo, entryTitulo);
              var score = 0;
              if(tipoNorm && entryTipoNorm && tipoNorm === entryTipoNorm && tipoNorm !== "otros") score += 3;
              if(tipoRaw && entryHtml.toLowerCase().indexOf(tipoRaw.toLowerCase()) !== -1) score += 2;
              var entryNorm = norm(entryHtml);
              for(var p=0;p<palabrasClave.length;p++){
                if(entryNorm.indexOf(palabrasClave[p]) !== -1){ score += 1; break; }
              }
              if(score === 0) score = 1;
              {
                var institucion = extraerCampoLocal(entryHtml, ["InstituciÃ³n","Institucion","Plataforma","OrganizaciÃ³n"]);
                var duracion = extraerCampoLocal(entryHtml, ["DuraciÃ³n","Duracion","Horas","Tiempo"]);
                var nivel = extraerCampoLocal(entryHtml, ["Nivel","Nivel de dificultad"]);
                var modalidad = extraerCampoLocal(entryHtml, ["Modalidad","Formato"]);
                var precio = extraerCampoLocal(entryHtml, ["Precio","Costo","Coste"]);
                var certificado = extraerCampoLocal(entryHtml, ["Certificado","CertificaciÃ³n"]);
                similares.push({titulo:entryTitulo, url:link, institucion:institucion, tipo:entryTipo, duracion:duracion, nivel:nivel, modalidad:modalidad, precio:precio, certificado:certificado, score:score, _r:Math.random()});
              }
            }
            similares.sort(function(a,b){
              if(b.score !== a.score) return b.score - a.score;
              return a._r - b._r;
            });
            similares = similares.slice(0,12);
            if(similares.length === 0) return;

            var seccion = document.createElement("div");
            seccion.className = "seccion-relacionada seccion-cursos-rel";
            seccion.setAttribute("data-rel", "cursos");
            seccion.style.cssText = "margin-top:40px;padding-top:24px;border-top:2px solid #e5e7eb;";
            seccion.innerHTML = '<h3 style="margin:0 0 16px;font-size:16px;color:#0f4c81;font-weight:800;">Cursos relacionados</h3>';

            var grid = document.createElement("div");
            grid.className = "empleos-grid rel-scroll";

            var pasoRelCursos = (window.pasoAnuncio ? window.pasoAnuncio(grid) : 6);
            for(var k=0;k<similares.length;k++){
              var s = similares[k];
              s.fechaCierre = "";
              s.fechaPublicacion = "";
              var tarjeta = crearTarjetaCursoLocal(s);
              grid.appendChild(tarjeta);
              if(k > 0 && (k + 1) % pasoRelCursos === 0 && k < similares.length - 1){
                var adC = document.createElement("div");
                adC.className = "empleo-anuncio empleo-anuncio-feed rel-ad";
                adC.innerHTML = '<div class="empleo-anuncio-inner">Espacio publicitario</div>';
                grid.appendChild(adC);
              }
            }
            seccion.appendChild(grid);
            _insertarRelacionada(contenedor, seccion, "despues-de");
          })
          .catch(function(){});
      }

      if(document.readyState === "loading"){
        document.addEventListener("DOMContentLoaded", cargarCursosRecomendados);
      } else {
        cargarCursosRecomendados();
      }
  } catch(e) { console.error("[Cursos Recomendados] Error:", e); }
    })();

    /* =========================================================
       CURSOS DINÃMICOS
       ========================================================= */
    (function(){
  try {
      "use strict";

      var CFG =
        window.PORTAL_CONFIG ||
        {
          whatsapp: "",
          correoContacto: "",
          nombreSitio: "EMPLEOS PERÃš HOY",
          dominio: ""
        };

      function esPortalCursos(){
        var pathname = location.pathname || "";
        return pathname.indexOf("/p/cursos.html") !== -1;
      }

      if(!esPortalCursos()) return;

      function normalizarTipoCurso(tipo, titulo){ return _normTipo(tipo, titulo); }

      function claseVisualCurso(tipo){ return _claseVisual(tipo); }

      function iconoCurso(tipo){ return _iconoCurso(tipo); }

      function crearTarjetaCurso(curso){ return _crearTarjetaCursoUnica(curso); }

      function cargarCursos(){
        var grid = document.getElementById("cursosGrid");
        if(!grid) return;

        var buscarInput = document.getElementById("cursoBusqueda");
        var buscarBtn = document.getElementById("cursoBuscar");
        var contadorEl = document.getElementById("contadorResultados");
        var carrusel = document.getElementById("categoriasCarrusel");
        var antBtn = document.getElementById("categoriaAnterior");
        var sigBtn = document.getElementById("categoriaSiguiente");
        var cargarMasBtn = document.getElementById("cargarMasCursos");
        var cargarMasEstado = document.getElementById("cargarMasEstado");

        var indice = 1;
        var porPagina = 12;
        var cargando = false;
        var sinMas = false;

        function parsearFechaLocal(fechaStr){
          if(!fechaStr) return null;
          var s = fechaStr.trim();
          var m = s.match(/^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})$/);
          if(m) return new Date(parseInt(m[3],10), parseInt(m[2],10)-1, parseInt(m[1],10));
          var m2 = s.match(/^(\d{4})[\/\-](\d{1,2})[\/\-](\d{1,2})$/);
          if(m2) return new Date(parseInt(m2[1],10), parseInt(m2[2],10)-1, parseInt(m2[3],10));
        var d = new Date(s);
        return isNaN(d.getTime()) ? null : d;
      }

        function extraerCampo(html, etiquetas){ return _ext(html, etiquetas); }
        function detectarCertificado(html){ return _detCert(html); }

        function procesarEntrada(entry){
          var link = "";
          if(entry.link){
            for(var j=0;j<entry.link.length;j++){
              if(entry.link[j].rel==="alternate"){ link=entry.link[j].href; break; }
            }
          }
          var html = (entry.content && entry.content.$t) || "";
          var titulo = entry.title ? entry.title.$t : "";
          var institucion = extraerCampo(html, ["InstituciÃ³n", "Institucion", "Plataforma", "OrganizaciÃ³n"]);
          var duracion = extraerCampo(html, ["DuraciÃ³n", "Duracion", "Horas", "Tiempo"]);
          var nivel = extraerCampo(html, ["Nivel", "Nivel de dificultad"]);
          var modalidad = extraerCampo(html, ["Modalidad", "Formato"]);
          var precio = extraerCampo(html, ["Precio", "Costo", "Coste"]);
          var certificado = detectarCertificado(html);
          var tipo = extraerCampo(html, ["Tipo", "CategorÃ­a", "Categoria", "Ãrea"]);
          var fechaInicio = extraerCampo(html, ["Fecha de inicio", "Inicio", "Inscripciones"]);
          var fechaFin = extraerCampo(html, ["Fecha de cierre", "Cierre", "Fin"]);
          var fechaPublicacion = entry.published ? entry.published.$t : "";

          var hoy = new Date();
          hoy.setHours(0,0,0,0);
          var estado = "abierta";
          if(fechaFin){
            var fFin = parsearFechaLocal(fechaFin);
            if(fFin && fFin < hoy) estado = "cerrada";
          }

          return {
            titulo:titulo, url:link, institucion:institucion,
            duracion:duracion, nivel:nivel, modalidad:modalidad,
            precio:precio, certificado:certificado, tipo:tipo,
            fechaInicio:fechaInicio, fechaCierre:fechaFin,
            fechaPublicacion:fechaPublicacion, estado:estado
          };
        }

        function cargarPagina(){
          if(cargando || sinMas) return;
          cargando = true;
          if(cargarMasBtn) cargarMasBtn.style.display = "none";
          if(cargarMasEstado) cargarMasEstado.textContent = "Cargando cursos...";

          fetch("/feeds/posts/default/-/Curso?alt=json&start-index=" + indice + "&max-results=" + porPagina)
            .then(function(r){
              if(!r.ok){ throw new Error("HTTP " + r.status); }
              return r.json();
            })
            .then(function(data){
              var entries = (data && data.feed && data.feed.entry) || [];
              if(entries.length < porPagina) sinMas = true;

              for(var i=0;i<entries.length;i++){
                try{
                  var curso = procesarEntrada(entries[i]);
                  var tarjeta = crearTarjetaCurso(curso);
                  grid.appendChild(tarjeta);
                }catch(entryErr){
                  console.warn("Curso omitido:", entryErr);
                }
              }

              if(typeof window.insertarAnuncioEnGrid === "function"){
                try{ window.insertarAnuncioEnGrid(grid, ".empleo-card"); }catch(eAd){}
              }

              indice += entries.length;
              cargando = false;

              if(cargarMasEstado) cargarMasEstado.textContent = "";
              if(cargarMasBtn) cargarMasBtn.style.display = "none";

              filtrarCursosDinamicas();
              revisarScrollInfinito();
            })
            .catch(function(e){
              cargando = false;
              if(cargarMasEstado) cargarMasEstado.textContent = "Error al cargar cursos";
              console.error("Error cargando cursos:", e);
            });
        }

        function filtrarCursosDinamicas(){
          var termino = (buscarInput ? buscarInput.value : "").toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g,"").trim();
          var modalidadActivo = [];
          var certificadoActivo = [];

          document.querySelectorAll("[data-familia='modalidad']:checked").forEach(function(el){
            var v = el.getAttribute("data-valor") || el.value;
            if(v) modalidadActivo.push(v.toLowerCase());
          });
          document.querySelectorAll("[data-familia='certificado']:checked").forEach(function(el){
            var v = el.getAttribute("data-valor") || el.value;
            if(v) certificadoActivo.push(v.toLowerCase());
          });

          var mapaCat = {
            "Tecnologia":"tecnologia","Negocios":"negocios","Desarrollo":"desarrollo",
            "Diseno":"diseno","Idiomas":"idiomas","Otros":"otros"
          };
          var catFiltro = "";
          if(categoriaActual && categoriaActual !== "Todos"){
            catFiltro = mapaCat[categoriaActual] || "";
          }

          var tarjetas = grid.querySelectorAll(".empleo-card");
          var visibles = 0;

          for(var i=0;i<tarjetas.length;i++){
            var tarjeta = tarjetas[i];
            var ok = true;

            if(termino){
              var texto = (
                (tarjeta.getAttribute("data-tipo") || "") + " " +
                (tarjeta.getAttribute("data-modalidad") || "") + " " +
                tarjeta.textContent
              ).toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g,"");
              var partes = termino.split(" ");
              for(var p=0;p<partes.length;p++){
                if(partes[p] && texto.indexOf(partes[p])===-1){ ok=false; break; }
              }
            }

            if(ok && catFiltro){
              var tipo = tarjeta.getAttribute("data-tipo") || "";
              if(tipo !== catFiltro) ok = false;
            }

            if(ok && modalidadActivo.length > 0){
              var modalidad = tarjeta.getAttribute("data-modalidad") || "";
              var modalEnTexto = modalidad;
              for(var m=0;m<modalidadActivo.length;m++){
                if(modalEnTexto.toLowerCase().indexOf(modalidadActivo[m]) !== -1) break;
              }
              if(m === modalidadActivo.length) ok = false;
            }
            if(ok && certificadoActivo.length > 0){
              var cert = tarjeta.getAttribute("data-certificado") || "";
              if(certificadoActivo.indexOf(cert) === -1) ok = false;
            }

            tarjeta.style.display = ok ? "" : "none";
            if(ok) visibles++;
          }

          if(contadorEl){
            contadorEl.textContent = "(" + visibles + " curso" + (visibles !== 1 ? "s" : "") + ")";
          }

          if(typeof window.insertarAnuncioEnGrid === "function"){
            try{ window.insertarAnuncioEnGrid(grid, ".empleo-card"); }catch(eAd){}
          }
        }

        if(buscarInput){
          buscarInput.addEventListener("input", filtrarCursosDinamicas);
        }

        var checks = document.querySelectorAll("[data-familia]");
        for(var i=0;i<checks.length;i++){
          (function(grupo){
            grupo.addEventListener("change", function(){
              var marcados = grupo.querySelectorAll('input[type="checkbox"]:checked');
              if(marcados.length > 0){
                grupo.classList.add("tiene-seleccion");
              }else{
                grupo.classList.remove("tiene-seleccion");
              }
              filtrarCursosDinamicas();
            });
            grupo.addEventListener("click", function(){
              setTimeout(function(){
                var marcados = grupo.querySelectorAll('input[type="checkbox"]:checked');
                if(marcados.length > 0){
                  grupo.classList.add("tiene-seleccion");
                }else{
                  grupo.classList.remove("tiene-seleccion");
                }
                filtrarCursosDinamicas();
              },10);
            });
          })(checks[i]);
        }

        var catBotones = carrusel ? carrusel.querySelectorAll(".categoria-card") : [];
        var categoriaActual = "Todos";
        for(var c=0;c<catBotones.length;c++){
          catBotones[c].addEventListener("click", function(){
            var cat = this.getAttribute("data-categoria");
            for(var j=0;j<catBotones.length;j++) catBotones[j].classList.remove("activa");
            this.classList.add("activa");
            categoriaActual = cat;
            filtrarCursosDinamicas();
          });
        }

        if(antBtn && carrusel){
          antBtn.addEventListener("click", function(){
            carrusel.scrollBy({left:-200,behavior:"smooth"});
          });
        }
        if(sigBtn && carrusel){
          sigBtn.addEventListener("click", function(){
            carrusel.scrollBy({left:200,behavior:"smooth"});
          });
        }

        if(cargarMasBtn){
          cargarMasBtn.style.display = "none";
          cargarMasBtn.addEventListener("click", function(){
            cargarPagina();
          });
        }

        function revisarScrollInfinito(){
          if(cargando || sinMas) return;
          if(!grid) return;
          var rect = grid.getBoundingClientRect();
          if(rect.bottom < window.innerHeight + 500){
            cargarPagina();
          }
        }

        window.addEventListener("scroll", revisarScrollInfinito, { passive: true });

        cargarPagina();
      }

      if(document.readyState === "loading"){
        document.addEventListener("DOMContentLoaded", cargarCursos);
      } else {
        cargarCursos();
      }
  } catch(e) { console.error("[Cursos DinÃ¡micos] Error:", e); }
    })();

/* =========================================================
       MEJORAS UX Y SEO
       - Migas de pan (breadcrumbs) en pÃ¡ginas y entradas
       - Botones de compartir en entradas
       - Botones flotantes WhatsApp + Volver arriba
       - Datos estructurados JSON-LD (JobPosting/WebSite)
       - Contadores reales de estadÃ­sticas en el inicio
       ========================================================= */
    (function(){
  try {

      "use strict";

      var CFG =
        window.PORTAL_CONFIG ||
        {
          whatsapp: "",
          correoContacto: "",
          nombreSitio: "EMPLEOS PERÅ¡ HOY",
          dominio: ""
        };

      function escapar(texto){
        return String(texto || "")
          .replace(/&/g,"&amp;")
          .replace(/</g,"&lt;")
          .replace(/>/g,"&gt;")
          .replace(/"/g,"&quot;");
      }

      /* ---------- MIGAS DE PAN ---------- */

      function construirMigas(){
        if(document.querySelector(".portal-migas")){ return; }

        var contenedor = document.querySelector(".empleo-individual");
        var ruta = [{ nombre: "Inicio", href: "/" }];

        if(contenedor){
          ruta.push({ nombre: "Empleos", href: "/p/empleos.html" });
          var categoria = contenedor.querySelector(".empleo-cabecera .empleo-categoria");
          if(categoria){
            var textoCat = String(categoria.textContent || "").trim();
            if(textoCat && textoCat !== "Otros"){
              ruta.push({ nombre: textoCat, href: "" });
            }
          }
          var titulo = contenedor.querySelector(".empleo-cabecera h1");
          ruta.push({
            nombre: titulo ? String(titulo.textContent).trim().slice(0,54) : "Entrada",
            href: location.pathname
          });
        }else{
          contenedor = document.querySelector(".portal-empleos");
          if(!contenedor){ return; }

          var path = location.pathname || "";
          var mapaPaginas = {
            "/": "Inicio",
            "/p/empleos.html": "Empleos",
            "/p/becas.html": "Becas",
            "/p/cursos.html": "Cursos",
            "/p/articulos.html": "ArtÃ­culos",
            "/p/politica-de-privacidad.html": "PolÃ­tica de privacidad",
            "/p/terminos-y-condiciones.html": "TÃ©rminos y condiciones"
          };

          if(path === "/" || path === "/index.html"){
            var h1home = contenedor.querySelector(".hub-hero h1, h1");
            ruta.push({
              nombre: h1home ? String(h1home.textContent).trim() : "Inicio",
              href: ""
            });
          }else{
            if(mapaPaginas[path] && mapaPaginas[path] !== "Inicio"){
              ruta.push({ nombre: mapaPaginas[path], href: path });
            }else if(path.indexOf("/p/empleos-") === 0){
              ruta.push({ nombre: "Empleos", href: "/p/empleos.html" });
            }

            var h1p = contenedor.querySelector(".buscador-empleos h1, .portal-titulo-seccion h1, h1");
            var nombreH1 = h1p ? String(h1p.textContent).trim().slice(0,64) : "PÃ¡gina";
            var ultima = ruta[ruta.length-1];
            if(!ultima || ultima.nombre !== nombreH1){
              ruta.push({ nombre: nombreH1, href: location.pathname });
            }
          }
        }

        var ol = document.createElement("ol");
        for(var i=0;i<ruta.length;i++){
          var li = document.createElement("li");
          if(i === ruta.length - 1){
            li.className = "actual";
            li.textContent = ruta[i].nombre;
          }else if(ruta[i].href){
            var a = document.createElement("a");
            a.href = ruta[i].href;
            a.textContent = ruta[i].nombre;
            li.appendChild(a);
          }else{
            li.textContent = ruta[i].nombre;
          }
          ol.appendChild(li);
        }

        var nav = document.createElement("nav");
        nav.className = "portal-migas";
        nav.setAttribute("aria-label", "Ruta de navegaciÃ³n");
        nav.appendChild(ol);
        contenedor.insertBefore(nav, contenedor.firstChild);
      }

      /* ---------- COMPARTIR ---------- */

      function construirCompartir(){
        if(document.querySelector(".portal-compartir")){ return; }
        var entrada = document.querySelector(".empleo-individual");
        if(!entrada){ return; }

        var url = encodeURIComponent(location.href);
        var titulo = encodeURIComponent(
          (entrada.querySelector(".empleo-cabecera h1") || {}).textContent || ""
        );
        var texto = titulo + " " + location.href;

        var botones = [
          {
            clases: "portal-c-whatsapp",
            etiqueta: "WhatsApp",
            icono: "<path d=\"M21 11.5a8.5 8.5 0 0 1-12.4 7.6L4 20.5l1.4-4.6A8.5 8.5 0 1 1 21 11.5z\"></path>",
            href: "https://wa.me/?text=" + encodeURIComponent(texto)
          },
          {
            clases: "portal-c-facebook",
            etiqueta: "Facebook",
            icono: "<path d=\"M14 8h3V5h-3a4 4 0 0 0-4 4v3H7v3h3v7h3v-7h3l1-3h-4V9a1 1 0 0 1 1-1z\"></path>",
            href: "https://www.facebook.com/sharer/sharer.php?u=" + url
          },
          {
            clases: "portal-c-x",
            etiqueta: "X",
            icono: "<path d=\"M4 4l7.4 9.6L4.4 20h2.2l5.9-5.2L17.2 20H20l-7.7-10L19.2 4H17l-5.5 4.9L6.8 4H4z\"></path>",
            href: "https://twitter.com/intent/tweet?url=" + url + "&text=" + titulo
          },
          {
            clases: "portal-c-linkedin",
            etiqueta: "LinkedIn",
            icono: "<path d=\"M16 11.5V17h-2v-5.2c0-1.3-.5-2.1-1.6-2.1-.9 0-1.4.6-1.6 1.2V17H8.8V8.5h2v1.2c.3-.5 1-1.2 2.2-1.2 1.6 0 3 1 3 3z\"></path><path d=\"M5 7h.01H5z\"></path><path d=\"M4.5 8.5H7V17H4.5z\"></path>",
            href: "https://www.linkedin.com/sharing/share-offsite/?url=" + url
          }
        ];

        var bloque = document.createElement("div");
        bloque.className = "portal-compartir";

        var tituloBloque = document.createElement("p");
        tituloBloque.className = "portal-compartir-titulo";
        tituloBloque.textContent = "Comparte esta oferta";

        var cajaBotones = document.createElement("div");
        cajaBotones.className = "portal-compartir-botones";

        for(var i=0;i<botones.length;i++){
          var a = document.createElement("a");
          a.className = "portal-compartir-boton " + botones[i].clases;
          a.href = botones[i].href;
          a.target = "_blank";
          a.rel = "noopener noreferrer";
          a.innerHTML = "<svg viewBox=\"0 0 24 24\" aria-hidden=\"true\">" +
            botones[i].icono +
            "</svg><span>" + botones[i].etiqueta + "</span>";
          cajaBotones.appendChild(a);
        }

        var btnCopiar = document.createElement("button");
        btnCopiar.type = "button";
        btnCopiar.className = "portal-compartir-boton portal-c-copiar";
        btnCopiar.innerHTML = "<svg viewBox=\"0 0 24 24\" aria-hidden=\"true\"><rect x=\"9\" y=\"9\" width=\"11\" height=\"11\" rx=\"2\"></rect><path d=\"M5 15V5a2 2 0 0 1 2-2h9\"></path></svg><span>Copiar enlace</span>";
        btnCopiar.addEventListener("click", function(){
          if(navigator.clipboard && navigator.clipboard.writeText){
            navigator.clipboard.writeText(location.href).then(function(){
              btnCopiar.querySelector("span").textContent = "Copiado";
            });
          } else {
            var aux = document.createElement("input");
            aux.value = location.href;
            document.body.appendChild(aux);
            aux.select();
            try{ document.execCommand("copy"); }catch(e){}
            document.body.removeChild(aux);
            btnCopiar.querySelector("span").textContent = "Copiado";
          }
        });
        cajaBotones.appendChild(btnCopiar);

        bloque.appendChild(tituloBloque);
        bloque.appendChild(cajaBotones);

        var referencia = entrada.querySelector(".empleo-info") ||
          entrada.querySelector(".empleo-postular") ||
          entrada.querySelector(".empleo-seccion");
        if(referencia){
          entrada.insertBefore(bloque, referencia);
        } else {
          entrada.appendChild(bloque);
        }
      }

      /* ---------- BOTONES FLOTANTES ---------- */

      function construirFlotantes(){
        if(document.querySelector(".portal-flotantes")){ return; }
        var esEntrada = /^\/\d{4}\/\d{2}\//.test(location.pathname || "");
        if(!document.querySelector(".portal-empleos") && !document.querySelector(".empleo-individual") && location.pathname.indexOf("/p/") !== 0 && !esEntrada && !document.querySelector(".post-body")){ return; }

        var hayWhatsapp =
          CFG.whatsapp &&
          CFG.whatsapp.replace(/\D/g,"").length >= 9;

        var contenedor = document.createElement("div");
        contenedor.className = "portal-flotantes";

        if(hayWhatsapp){
          var wa = document.createElement("a");
          wa.className = "portal-fab portal-fab-whatsapp";
          wa.href = "https://wa.me/" + CFG.whatsapp.replace(/\D/g,"") +
            "?text=" + encodeURIComponent("Hola, quiero informaciÃ³n sobre EMPLEOS PERÅ¡ HOY");
          wa.target = "_blank";
          wa.rel = "noopener noreferrer";
          wa.setAttribute("aria-label", "EscrÃ­benos por WhatsApp");
          wa.innerHTML = "<svg viewBox=\"0 0 24 24\" aria-hidden=\"true\"><path d=\"M12 3a9 9 0 0 0-7.8 13.6L3 21l4.5-1.2A9 9 0 1 0 12 3z\"></path><path d=\"M9 8.5c0 4 2.5 6.5 6.5 6.5l.8-1.6-2-1-.8.5c-1-.5-1.9-1.4-2.4-2.4l.5-.8-1-2z\"></path></svg>";
          contenedor.appendChild(wa);
        }

        var subir = document.createElement("button");
        subir.type = "button";
        subir.className = "portal-fab portal-fab-subir";
        subir.setAttribute("aria-label", "Volver arriba");
        subir.innerHTML = "<svg viewBox=\"0 0 24 24\" aria-hidden=\"true\"><path d=\"M12 19V5\"></path><path d=\"M5 12l7-7 7 7\"></path></svg>";
        subir.addEventListener("click", function(){
          window.scrollTo({ top: 0, behavior: "smooth" });
        });
        contenedor.appendChild(subir);

        document.body.appendChild(contenedor);

        window.addEventListener("scroll", function(){
          var mostrar = (window.pageYOffset || document.documentElement.scrollTop) > 420;
          subir.classList.toggle("visible", mostrar);
        }, { passive: true });
      }

      /* ---------- DATOS ESTRUCTURADOS ---------- */

      function inyectarJsonLd(objeto, clave){
        if(clave){
          var previo = document.querySelector('script[data-jsonld="' + clave + '"]');
          if(previo && previo.parentNode){ previo.parentNode.removeChild(previo); }
        }
        var script = document.createElement("script");
        script.type = "application/ld+json";
        script.setAttribute("defer", "");
        if(clave){ script.setAttribute("data-jsonld", clave); }
        script.textContent = JSON.stringify(objeto);
        (document.head || document.documentElement).appendChild(script);
      }

      function schemaItemListDesdeGrid(idGrid, tipo){
        var grid = document.getElementById(idGrid);
        if(!grid){ return; }
        var nodos = grid.querySelectorAll(".empleo-card, .articulo-card, .curso-card, .beca-card, a[href]");
        var elementos = [];
        var vistos = {};
        for(var i=0;i<nodos.length && elementos.length < 20;i++){
          var nodo = nodos[i];
          var a = (nodo.tagName === "A") ? nodo : nodo.querySelector("a[href]");
          var tit = (nodo.tagName === "A")
            ? nodo
            : (nodo.querySelector("h3, .empleo-titulo, .articulo-titulo, .curso-titulo") || null);
          var nombre = tit ? String(tit.textContent || "").trim() : "";
          var href = a ? a.href : "";
          if(nombre && href && !vistos[href]){
            vistos[href] = true;
            elementos.push({ "@type": tipo, "name": nombre, "url": href });
          }
        }
        if(elementos.length < 2){ return; }
        var raiz = document.querySelector(".portal-empleos");
        var h1 = raiz ? raiz.querySelector("h1") : null;
        inyectarJsonLd({
          "@context": "https://schema.org",
          "@type": "ItemList",
          "name": h1 ? String(h1.textContent || "").trim() : CFG.nombreSitio,
          "url": location.href.split("#")[0],
          "numberOfItems": elementos.length,
          "itemListElement": elementos.map(function(el, idx){
            return { "@type": "ListItem", "position": idx + 1, "item": el };
          })
        }, "ItemList:" + idGrid);
      }

      function refrescarItemListas(){
        schemaItemListDesdeGrid("empleosGrid", "JobPosting");
        schemaItemListDesdeGrid("becasGrid", "EducationalOccupationalProgram");
        schemaItemListDesdeGrid("cursosGrid", "Course");
        schemaItemListDesdeGrid("articulosGrid", "Article");
      }

      function datosEstructurados(){
        var esEntrada = /^\/\d{4}\/\d{2}\//.test(location.pathname || "");
        var esPagina = (location.pathname || "").indexOf("/p/") === 0;
        var tienePortal = !!document.querySelector(".portal-empleos");
        var tieneEntrada = !!document.querySelector(".empleo-individual");
        var tienePost = !!document.querySelector(".post-body");
        if(!tienePortal && !tieneEntrada && !esPagina && !esEntrada && !tienePost){ return; }

        var origen = CFG.dominio || location.origin;

        inyectarJsonLd({
          "@context": "https://schema.org",
          "@type": "WebSite",
          "name": CFG.nombreSitio,
          "url": origen,
          "inLanguage": "es-PE",
          "potentialAction": {
            "@type": "SearchAction",
            "target": origen + "/p/empleos.html?q={search_term_string}",
            "query-input": "required name=search_term_string"
          }
        });

        function nrm(s){
          return String(s || "")
            .toLowerCase()
            .normalize("NFD")
            .replace(/[\u0300-\u036f]/g,"")
            .replace(/\s+/g," ")
            .trim();
        }

        function tituloH1(raiz){
          var h = (raiz || document).querySelector("h1");
          return h ? String(h.textContent || "").trim() : "";
        }

        function descripcionMeta(raiz){
          var p = (raiz || document).querySelector(
            ".buscador-empleos > p, .portal-titulo-seccion > p, .hub-hero > p, .empleo-seccion p"
          );
          return p ? String(p.textContent || "").trim().slice(0, 300) : "";
        }

        function nombreSeccionPorPath(){
          var path = location.pathname || "/";
          if(path === "/" || path === "/index.html") return "Inicio";
          if(path.indexOf("/p/empleos") === 0) return "Empleos";
          if(path.indexOf("/p/becas") === 0) return "Becas";
          if(path.indexOf("/p/cursos") === 0) return "Cursos";
          if(path.indexOf("/p/articulos") === 0) return "ArtÃ­culos";
          if(path.indexOf("/p/politica") === 0) return "PolÃ­tica de privacidad";
          if(path.indexOf("/p/terminos") === 0) return "TÃ©rminos y condiciones";
          return "";
        }

        function inyectarMigasSchema(items){
          if(!items || !items.length){ return; }
          inyectarJsonLd({
            "@context": "https://schema.org",
            "@type": "BreadcrumbList",
            "itemListElement": items.map(function(it, idx){
              return {
                "@type": "ListItem",
                "position": idx + 1,
                "name": it.name,
                "item": it.item
              };
            })
          });
        }

        function detectarTipoContenido(raiz){
          var texto = String((raiz && raiz.textContent) || "");
          var n = nrm(texto);
          if(
            n.indexOf("tipo contratante") !== -1 ||
            (n.indexOf("modalidad") !== -1 && n.indexOf("postular") !== -1 && n.indexOf("fecha de cierre") !== -1)
          ){
            return "empleo";
          }
          if(n.indexOf("certificado") !== -1 && (n.indexOf("institucion") !== -1 || n.indexOf("duracion") !== -1 || n.indexOf("curso") !== -1)){
            return "curso";
          }
          if(n.indexOf("beca") !== -1 || n.indexOf("financiamiento") !== -1 || n.indexOf("convocatoria de beca") !== -1){
            return "beca";
          }
          if(n.indexOf("tema") !== -1 && (n.indexOf("cv") !== -1 || n.indexOf("entrevista") !== -1 || n.indexOf("articulo") !== -1 || esEntrada)){
            return "articulo";
          }
          if(esEntrada || tienePost){
            return "articulo";
          }
          return "pagina";
        }

        function schemaWebPageBasico(titulo, descripcion, seccion){
          var items = [{ name: "Inicio", item: origen + "/" }];
          var sec = seccion || nombreSeccionPorPath();
          if(sec && sec !== "Inicio"){
            var hrefSec = "";
            if(sec === "Empleos") hrefSec = origen + "/p/empleos.html";
            if(sec === "Becas") hrefSec = origen + "/p/becas.html";
            if(sec === "Cursos") hrefSec = origen + "/p/cursos.html";
            if(sec === "ArtÃ­culos") hrefSec = origen + "/p/articulos.html";
            if(sec === "PolÃ­tica de privacidad") hrefSec = origen + "/p/politica-de-privacidad.html";
            if(sec === "TÃ©rminos y condiciones") hrefSec = origen + "/p/terminos-y-condiciones.html";
            items.push({ name: sec, item: hrefSec || (origen + location.pathname) });
          }
          if(titulo && (items.length < 2 || items[items.length-1].name !== titulo)){
            items.push({ name: titulo.slice(0, 60), item: location.href.split("#")[0] });
          }

          inyectarJsonLd({
            "@context": "https://schema.org",
            "@type": "WebPage",
            "@id": location.href.split("#")[0],
            "url": location.href.split("#")[0],
            "name": titulo || CFG.nombreSitio,
            "description": descripcion || "",
            "inLanguage": "es-PE",
            "isPartOf": { "@type": "WebSite", "name": CFG.nombreSitio, "url": origen },
            "breadcrumb": { "@type": "BreadcrumbList", "itemListElement": items.map(function(it, idx){
              return { "@type": "ListItem", "position": idx + 1, "name": it.name, "item": it.item };
            }) }
          });
          inyectarMigasSchema(items);
        }

        /* --- posts individuales (empleo / beca / curso / artÃ­culo) --- */
        var entrada = document.querySelector(".empleo-individual") ||
          (tienePost ? document.querySelector(".post-body") : null);

        if(entrada){
          try{
            var tipoContenido = detectarTipoContenido(entrada);
            var tituloPost = tituloH1(entrada) || tituloH1(document) || document.title;
            var descPost = descripcionMeta(entrada);

            if(tipoContenido === "empleo"){
              // JobPosting se construye abajo con detalle (bloque existente reutilizado vÃ­a helper)
              construirJobPostingDetalle(entrada, tituloPost, descPost);
            }else if(tipoContenido === "curso"){
              inyectarJsonLd({
                "@context": "https://schema.org",
                "@type": "Course",
                "name": tituloPost,
                "description": descPost || tituloPost,
                "url": location.href.split("#")[0],
                "inLanguage": "es-PE",
                "provider": { "@type": "Organization", "name": CFG.nombreSitio, "sameAs": origen }
              });
            }else if(tipoContenido === "beca"){
              inyectarJsonLd({
                "@context": "https://schema.org",
                "@type": "EducationalOccupationalProgram",
                "name": tituloPost,
                "description": descPost || tituloPost,
                "url": location.href.split("#")[0],
                "inLanguage": "es-PE",
                "provider": { "@type": "Organization", "name": CFG.nombreSitio, "sameAs": origen }
              });
            }else{
              inyectarJsonLd({
                "@context": "https://schema.org",
                "@type": "Article",
                "headline": tituloPost.slice(0, 110),
                "description": descPost || tituloPost,
                "url": location.href.split("#")[0],
                "inLanguage": "es-PE",
                "mainEntityOfPage": location.href.split("#")[0],
                "publisher": {
                  "@type": "Organization",
                  "name": CFG.nombreSitio,
                  "sameAs": origen
                }
              });
            }

            schemaWebPageBasico(tituloPost, descPost, tipoContenido === "empleo" ? "Empleos" : nombreSeccionPorPath());
            return;
          }catch(error){
            console.error("Error en datos estructurados (post):", error);
          }
        }

        /* --- pÃ¡ginas de listado / home / estÃ¡ticas --- */
        try{
          var portal = document.querySelector(".portal-empleos");
          var raiz = portal || document.body;
          var tituloPag = tituloH1(raiz) || document.title;
          var descPag = descripcionMeta(raiz);
          schemaWebPageBasico(tituloPag, descPag, nombreSeccionPorPath());

          refrescarItemListas();
        }catch(error){
          console.error("Error en datos estructurados (pÃ¡gina):", error);
        }
      }

      function construirJobPostingDetalle(entrada, titulo, descripcionFallback){
        try{
          function nrm(s){
            return String(s || "")
              .toLowerCase()
              .normalize("NFD")
              .replace(/[\u0300-\u036f]/g,"")
              .replace(/\s+/g," ")
              .trim();
          }

          function leerDestacado(raiz, claves){
            var ps = raiz.querySelectorAll(".empleo-destacado p");
            var buscados = (claves || []).map(nrm);
            for(var p=0;p<ps.length;p++){
              var t = String(ps[p].textContent || "").trim();
              var n = nrm(t);
              for(var c=0;c<buscados.length;c++){
                if(n.indexOf(buscados[c]) !== -1){
                  var partes = t.split(":");
                  if(partes.length > 1){
                    return partes.slice(1).join(":").trim();
                  }
                }
              }
            }
            return "";
          }

          function leerInfoCard(raiz, claves){
            var cards = raiz.querySelectorAll(".empleo-info-card");
            var buscados = (claves || []).map(nrm);
            for(var i=0;i<cards.length;i++){
              var label = String((cards[i].querySelector(".empleo-info-label") || {}).textContent || "");
              var n = nrm(label);
              for(var c=0;c<buscados.length;c++){
                if(n.indexOf(buscados[c]) !== -1){
                  return String((cards[i].querySelector(".empleo-info-value") || {}).textContent || "").trim();
                }
              }
            }
            return "";
          }

          function aISO(texto){
            var s = String(texto || "").trim();
            if(!s || nrm(s).indexOf("no espec") === 0){ return ""; }
            var m = s.match(/(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})/);
            if(m){
              var dia = ("0" + m[1]).slice(-2);
              var mes = ("0" + m[2]).slice(-2);
              return m[3] + "-" + mes + "-" + dia;
            }
            var d = new Date(s);
            if(!isNaN(d.getTime())){
              return d.toISOString().split("T")[0];
            }
            return "";
          }

          function mapearTipoJornada(contrato, jornada){
            var n = nrm(contrato + " " + jornada);
            if(!n || n.indexOf("no espec") === 0){ return "FULL_TIME"; }
            if(n.indexOf("practic") !== -1 || n.indexOf("pasant") !== -1 || n.indexOf("intern") !== -1){ return "INTERN"; }
            if(n.indexOf("part") !== -1 || n.indexOf("medio tiempo") !== -1){ return "PART_TIME"; }
            if(n.indexOf("consultor") !== -1 || n.indexOf("freelance") !== -1 || n.indexOf("contractor") !== -1){ return "CONTRACTOR"; }
            if(n.indexOf("temporad") !== -1 || n.indexOf("temporal") !== -1){ return "TEMPORARY"; }
            if(n.indexOf("voluntar") !== -1){ return "VOLUNTEER"; }
            if(n.indexOf("permanente") !== -1 || n.indexOf("indefinido") !== -1){ return "PERMANENT"; }
            return "FULL_TIME";
          }

          function parseSalario(texto){
            var t = String(texto || "");
            if(!t || nrm(t).indexOf("no espec") === 0 || nrm(t).indexOf("acorde") !== -1){
              return null;
            }
            var nums = t.match(/\d{1,3}(?:[.,]\d{3})+|\d+(?:[.,]\d+)?/g) || [];
            var vals = [];
            for(var i=0;i<nums.length;i++){
              var v = parseInt(nums[i].replace(/[^\d]/g, ""), 10);
              if(!isNaN(v) && v >= 100){ vals.push(v); }
            }
            if(!vals.length){ return null; }
            return { min: vals[0], max: vals.length > 1 ? vals[1] : vals[0] };
          }

          var empresa = String((entrada.querySelector(".empleo-cabecera .empleo-empresa") || {}).textContent || "").trim();
          var categoria = String((entrada.querySelector(".empleo-cabecera .empleo-categoria") || {}).textContent || "").trim();
          var ubicacion = leerInfoCard(entrada, ["ubicaci", "ciudad", "lugar"]);
          var modalidad = leerInfoCard(entrada, ["modalidad"]);
          var contrato = leerInfoCard(entrada, ["contrato"]);
          var salarioTexto = leerInfoCard(entrada, ["salario"]) || leerDestacado(entrada, ["salario", "remuneracion", "sueldo"]);
          var experienciaTexto = leerDestacado(entrada, ["experiencia"]) || leerInfoCard(entrada, ["experiencia"]);
          var fechaPublicacion = leerDestacado(entrada, ["fecha de publicacion", "fecha publicacion"]) || leerDestacado(entrada, ["fecha de publicaci"]);
          var fechaCierre = leerDestacado(entrada, ["fecha de cierre", "fecha cierre", "fecha limite"]);
          var jornada = leerDestacado(entrada, ["jornada", "horario"]);
          var estudios = leerDestacado(entrada, ["estudios", "formacion"]);

          var descripcion = descripcionFallback;
          var parrafo = entrada.querySelector(".empleo-seccion p");
          if(parrafo){
            descripcion = String(parrafo.textContent || "").trim().slice(0, 2000);
          }

          if(!titulo){ return; }

          var datePosted = aISO(fechaPublicacion);
          if(!datePosted){
            var metaPub = document.querySelector('meta[property="article:published_time"], meta[itemprop="datePublished"]');
            if(metaPub && metaPub.content){ datePosted = String(metaPub.content).split("T")[0]; }
          }
          if(!datePosted){ datePosted = new Date().toISOString().split("T")[0]; }

          var job = {
            "@context": "https://schema.org",
            "@type": "JobPosting",
            "title": titulo,
            "datePosted": datePosted,
            "description": descripcion || titulo,
            "url": location.href.split("#")[0],
            "directApply": true,
            "inLanguage": "es-PE",
            "employmentType": mapearTipoJornada(contrato, jornada)
          };

          var validThrough = aISO(fechaCierre);
          if(validThrough){
            job.validThrough = validThrough + "T23:59:59-05:00";
          }

          if(empresa){
            job.hiringOrganization = {
              "@type": "Organization",
              "name": empresa,
              "sameAs": (CFG.dominio || location.origin)
            };
          }

          if(ubicacion){
            var partesUbi = ubicacion.split(",").map(function(x){ return x.trim(); }).filter(Boolean);
            var localidad = partesUbi[0] || ubicacion;
            var region = partesUbi[1] || "";
            var address = {
              "@type": "PostalAddress",
              "addressLocality": localidad,
              "addressCountry": "PE"
            };
            if(region){ address.addressRegion = region; }
            job.jobLocation = {
              "@type": "Place",
              "address": address
            };
            job.applicantLocationRequirements = {
              "@type": "Country",
              "name": "Peru"
            };
          }

          var salario = parseSalario(salarioTexto);
          if(salario){
            job.baseSalary = {
              "@type": "MonetaryAmount",
              "currency": "PEN",
              "value": {
                "@type": "QuantitativeValue",
                "minValue": salario.min,
                "maxValue": salario.max,
                "value": salario.max,
                "unitText": "MONTH"
              }
            };
          }

          if(experienciaTexto && nrm(experienciaTexto).indexOf("no espec") !== 0){
            job.experienceRequirements = {
              "@type": "OccupationalExperienceRequirements",
              "description": experienciaTexto
            };
          }

          if(estudios && nrm(estudios).indexOf("no espec") !== 0){
            job.educationRequirements = {
              "@type": "EducationalOccupationalCredential",
              "credentialCategory": estudios
            };
          }

          if(modalidad && nrm(modalidad).indexOf("no espec") !== 0){
            if(nrm(modalidad).indexOf("remoto") !== -1){
              job.jobLocationType = "TELECOMMUTE";
              job.applicantLocationRequirements = {
                "@type": "Country",
                "name": "Peru"
              };
            }
          }

          inyectarJsonLd(job);

          if(categoria){
            inyectarJsonLd({
              "@context": "https://schema.org",
              "@type": "WebPage",
              "@id": location.href.split("#")[0],
              "name": titulo,
              "isPartOf": { "@type": "WebSite", "name": CFG.nombreSitio, "url": CFG.dominio || location.origin },
              "about": { "@type": "Thing", "name": categoria }
            });
          }
        }catch(error){
          console.error("Error JobPosting:", error);
        }
      }

      /* ---------- CONTADORES REALES ---------- */

      var contadorCallbacks = {};

      function contarSeccion(etiqueta, elemento){
        /* data-fija: la cifra ya viene horneada en la pagina (solo ofertas
           vigentes, escrita por actualizar-contadores.ps1) y NO se pisa con
           openSearch$totalResults (que incluye las vencidas). */
        if(elemento && elemento.getAttribute("data-fija")){
          return;
        }
        var nombre = "contadorPortal" + (etiqueta || "Default") + Math.floor(Math.random()*1e6);
        window[nombre] = function(data){
          try{
            var total = 0;
            if(data && data.feed){
              total = data.feed["openSearch$totalResults"]
                ? parseInt(data.feed["openSearch$totalResults"].$t, 10)
                : 0;
            }
            if(elemento){
              elemento.textContent = total > 0 ? total : "-";
            }
          }catch(e){}
          setTimeout(function(){
            if(window[nombre]){ delete window[nombre]; }
          }, 1000);
        };

        var script = document.createElement("script");
        script.src = "https://empleosperuhoy.blogspot.com/feeds/posts/default" +
          (etiqueta ? "/-/" + encodeURIComponent(etiqueta) : "") +
          "?alt=json-in-script&max-results=1&callback=" + nombre +
          "&_=" + new Date().getTime();
        document.body.appendChild(script);
      }

      var contadoresListos = false;

      function construirContadores(){
        if(contadoresListos){ return; }
        var items = document.querySelectorAll(".portal-stats-item[data-conteo]");
        if(!items.length){ return; }
        contadoresListos = true;
        for(var i=0;i<items.length;i++){
          contarSeccion(items[i].getAttribute("data-conteo"), items[i].querySelector(".portal-stats-numero"));
        }
      }

      /* ---------- CORREO DE CONTACTO ---------- */

      function enlazarCabecera(){
        var enlace = document.querySelector(
          ".header-widget h1 a, #Header1 h1 a, .widget.Header h1 a," +
          " [class*='blog-name'] h1 a, [class*='blogName'] h1 a"
        );
        if(enlace){
          if(!enlace.getAttribute("href") || enlace.getAttribute("href").indexOf("#") === 0 ||
             enlace.getAttribute("href").indexOf(location.pathname) > -1 && location.pathname !== "/"){
            enlace.setAttribute("href", "/");
          }
          enlace.setAttribute("title", "Ir al inicio");
        }
      }

      function enlazarContacto(){
        if(!CFG.correoContacto){ return; }
        var enlaces = document.querySelectorAll("a[data-contacto]");
        for(var i=0;i<enlaces.length;i++){
          enlaces[i].href =
            "https://mail.google.com/mail/?view=cm&fs=1&to=" +
            encodeURIComponent(CFG.correoContacto) +
            "&su=" + encodeURIComponent(enlaces[i].getAttribute("data-asunto") || "Contacto") +
            "&body=" + encodeURIComponent(enlaces[i].textContent || "");
          enlaces[i].target = "_blank";
          enlaces[i].rel = "noopener noreferrer";
        }
      }

      function ocultarCaducadas(ficha){
        return ficha.getAttribute("data-ocultar-caducadas") === "true" || ficha.getAttribute("data-ocultar-caducadas") === "1";
      }

      function esEmpleo(ficha){
        return ficha.querySelector("a[data-aplicar]") !== null ||
               (ficha.getAttribute("data-tipo") || "").indexOf("empleo") !== -1;
      }

      function obtenerFechaBaseFicha(ficha){
        var publicada = ficha.getAttribute("data-publicado") || "";
        if(publicada){ return publicada; }
        try{
          var marca = ficha.querySelector("time[itemprop='datePublished'], time[itemprop='dateCreated'], time[datetime]");
          if(marca && marca.getAttribute("datetime")){
            return String(marca.getAttribute("datetime")).slice(0,10);
          }
        }catch(e){}
        return "";
      }

      function aplicarVigenciaPorDefecto(){
        var contenedores = document.querySelectorAll("[data-vigencia-dias]");
        for(var c=0;c<contenedores.length;c++){
          var contenedor = contenedores[c];
          var vigenciaBase = parseInt(contenedor.getAttribute("data-vigencia-dias"),10);
          if(isNaN(vigenciaBase) || vigenciaBase < 1){ continue; }
          var tarjetas = contenedor.querySelectorAll("article");
          for(var i=0;i<tarjetas.length;i++){
            var tarjeta = tarjetas[i];
            if(tarjeta.getAttribute("data-cierre")){ continue; }
            var vigencia = parseInt(tarjeta.getAttribute("data-vigencia-dias"),10);
            if(isNaN(vigencia) || vigencia < 1){ vigencia = vigenciaBase; }
            var base = obtenerFechaBaseFicha(tarjeta);
            if(!base){ continue; }
            var fin = new Date(base);
            if(isNaN(fin.getTime())){ continue; }
            fin.setDate(fin.getDate() + vigencia);
            var anio = fin.getFullYear();
            var mes  = ("0" + (fin.getMonth()+1)).slice(-2);
            var dia  = ("0" + fin.getDate()).slice(-2);
            tarjeta.setAttribute("data-cierre", anio + "-" + mes + "-" + dia);
          }
        }
      }

      function actualizarEstadosConvocatoria(){
        var hoy = new Date();
        hoy.setHours(0,0,0,0);
        var fichas = document.querySelectorAll("[data-cierre]");
        for(var i=0;i<fichas.length;i++){
          var ficha = fichas[i];
          var fin = new Date(ficha.getAttribute("data-cierre"));
          if(isNaN(fin.getTime())){ continue; }
          fin.setHours(0,0,0,0);
          var dias = Math.round((fin.getTime() - hoy.getTime()) / 86400000);
          var etiqueta = ficha.querySelector("[data-estado]") || ficha;
          var boton = ficha.querySelector("a[data-postular], a[data-aplicar]");
          var empleo = esEmpleo(ficha);

          var textos = {
            abierta: ficha.getAttribute("data-texto-abierta")  || (empleo ? "Vacante vigente"  : "Convocatoria abierta"),
            pronto:  ficha.getAttribute("data-texto-pronto")   || (empleo ? "Ã‚Â¡Cierra pronto!" : "Ã‚Â¡Cierra pronto!"),
            cerrada: ficha.getAttribute("data-texto-cerrada")  || (empleo ? "Vacante cubierta" : "Convocatoria finalizada")
          };
          var plantillaPronto = textos.pronto;
          if(dias === 0){
            plantillaPronto = "Â¡Cierra hoy!";
          }else if(plantillaPronto.indexOf("{dias}") === -1){
            plantillaPronto = plantillaPronto + " (" + dias + " dÃ­a" + (dias === 1 ? "" : "s") + ")";
          }else{
            plantillaPronto = plantillaPronto.replace("{dias}", String(dias));
          }

          var claseVieja = "portal-abierta portal-pronto portal-cerrada";
          etiqueta.className = etiqueta.className.replace(/\bportal-(abierta|pronto|cerrada)\b/g, "").replace(/\s{2,}/g," ").trim();

          if(dias < 0){
            etiqueta.textContent = textos.cerrada;
            etiqueta.classList.add("portal-cerrada");
            if(ocultarCaducadas(ficha)){
              ficha.style.display = "none";
            }
            if(boton){
              boton.classList.add("portal-boton-deshabilitado");
              boton.setAttribute("aria-disabled", "true");
              boton.removeAttribute("href");
            }
          }else if(dias <= 5){
            etiqueta.textContent = plantillaPronto.replace("(", "(");
            etiqueta.classList.add("portal-pronto");
            etiqueta.textContent = plantillaPronto;
          }else{
            etiqueta.textContent = textos.abierta;
            etiqueta.classList.add("portal-abierta");
          }
        }
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

      function coleccionarFiltro(selector){
        var resultados = [];
        var control = document.querySelectorAll(selector + ".activo")[0];
        if(control && control.getAttribute("data-valor")){
          resultados.push(control.getAttribute("data-valor"));
        }
        return resultados;
      }

      function trimTexto(v){
        return (v && v.value !== undefined ? v.value : v || "").toString().toLowerCase().replace(/\s+/g," ").trim();
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
        fin.setHours(0,0,0,0);
        var hoy = new Date(); hoy.setHours(0,0,0,0);
        var dias = Math.round((fin.getTime() - hoy.getTime()) / 86400000);
        if(dias < 0){ return "cerrada"; }
        if(dias <= 5){ return "pronto"; }
        return "abierta";
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
              var hermanos = document.querySelectorAll("[data-familia='" + (grupo.getAttribute("data-familia-grupo") || "") + "'].activo");
              if(exclusivo){
                var mismos = document.querySelectorAll("[data-familia-grupo='" + (grupo.getAttribute("data-familia-grupo") || "") + "']");
                for(var h=0;h<mismos.length;h++){ mismos[h].classList.remove("activo"); }
              }else if(activo){
                grupo.classList.remove("activo");
              }
              if(!activo || exclusivo){ grupo.classList.add("activo"); }
              if(!grupo.getAttribute("data-familia-grupo")){
                document.querySelectorAll("[data-familia]").forEach(function(g){
                  if(g !== grupo && g.getAttribute("data-familia") === familia){ g.classList.remove("activo"); }
                });
              }
              filtrarBecas()();
            });
          })(grupos[i]);
        }

        var buscador = document.querySelectorAll("input[data-buscador-becas]");
        for(var j=0;j<buscador.length;j++){
          buscador[j].addEventListener("input", function(){
            filtrarBecas()();
          });
        }
      }

      /* =========================================================
         BECAS DINÃMICAS - TARJETA Y CARGA
         ========================================================= */

      function parsearFecha(fechaStr){
        if(!fechaStr) return null;
        var s = fechaStr.trim();
        var m = s.match(/^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})$/);
        if(m){
          return new Date(parseInt(m[3],10), parseInt(m[2],10)-1, parseInt(m[1],10));
        }
        var m2 = s.match(/^(\d{4})[\/\-](\d{1,2})[\/\-](\d{1,2})$/);
        if(m2){
          return new Date(parseInt(m2[1],10), parseInt(m2[2],10)-1, parseInt(m2[3],10));
        }
        var d = new Date(s);
        return isNaN(d.getTime()) ? null : d;
      }

      function extraerCampoBeca(html, etiquetas){ return _ext(html, etiquetas); }

      function _textoMeta(s, max){
        max = max || 90;
        if(s === null || s === undefined) return "";
        var t = String(s)
          .replace(/<[^>]+>/g, " ")
          .replace(/&nbsp;/gi, " ")
          .replace(/&[a-z]+;/gi, " ")
          .replace(/\s+/g, " ")
          .trim();
        if(!t) return "";
        if(/^(->|-{2,}|â€”{2,}|n\/?a|none|null|undefined|\?+|\.{3,}|sin dato|no aplica)$/i.test(t)) return "";
        if(/^(nan|false|true)$/i.test(t)) return "";
        t = t.replace(/^[>\-\u2013\u2014\:\s]+/, "").replace(/[\s\.\,\;\:\u2013\u2014]+$/, "").trim();
        if(t.length < 3) return "";
        if(/^[\W_]+$/.test(t)) return "";
        if(!/[\d]/.test(t) && !/[a-zÃ¡Ã©Ã­Ã³ÃºÃ±Ã¼]/i.test(t)) return "";
        if(t.length > max) t = t.slice(0, max).replace(/\s+\S*$/, "").trim() + (t.length > max ? "â€¦" : "");
        return t;
      }

      function _quitaPrefijoFecha(s){
        var t = String(s || "");
        var prev;
        do{
          prev = t;
          t = t.replace(/^(hasta|desde|fin\s+de\s+inscripci[oÃ³]n|inicio\s+de\s+inscripci[oÃ³]n)\s+/i, "").trim();
        }while(t !== prev);
        return t;
      }

      function _textoInscripcion(inicio, cierre){
        var iOrig = _textoMeta(inicio, 40);
        var cOrig = _textoMeta(cierre, 40);
        var i = _quitaPrefijoFecha(iOrig);
        var c = _quitaPrefijoFecha(cOrig);
        if(i && c && i === c) return i;
        if(i && /^(consultar|ver enlace)/i.test(i) && c && /^(consultar|ver enlace)/i.test(c)) return i;
        function _esFecha(t){ return /\d{1,2}[\/\-]\d{1,2}[\/\-]\d{4}/.test(t); }
        var iF = _esFecha(i), cF = _esFecha(c);
        if(iF && cF) return i + " - " + c;
        if(cF) return "hasta " + c;
        if(iF) return "desde " + i;
        return "";
      }

      function _sanearDirigidoA(s){
        var t = _textoMeta(s, 80);
        if(!t) return "";
        if(/^requisitos?$/i.test(t)) return "";
        if(/^[^a-zÃ¡Ã©Ã­Ã³ÃºÃ±Ã¼]{0,4}$/i.test(t)) return "";
        if(/debe estar firmada|coordenador|coordinador|papel oficial|logotipos y sellos/i.test(t)) return "";
        if(t.length > 80){
          t = t.slice(0, 80).replace(/\s+\S*$/, "").trim();
        }
        if(!/[a-zÃ¡Ã©Ã­Ã³ÃºÃ±Ã¼]/i.test(t)) return "";
        return t;
      }

      function _textoApoyo(s){
        var t = _textoMeta(s, 48);
        if(!t) return "";
        if(/debe estar firmada|coordenador|coordinador|papel oficial|solicitante|faculta para optar|sellos correspondien/i.test(t)) return "";
        if(/^(carrera|programa|estudios|grado|titulo|titulo universitario)$/i.test(t)) return "";
        if(!/[a-zÃ¡Ã©Ã­Ã³ÃºÃ±Ã¼0-9]/i.test(t)) return "";
        if(t.length > 48) return "";
        return t;
      }

      function _normalizarDestino(cobertura, zona, pais){
        function _n(s){
          return String(s || "").toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "").trim();
        }
        var z = _n(zona);
        var c = _n(cobertura);
        var p = _n(pais);
        if(/virtual|online/.test(z)) return "virtual";
        if(/peru/.test(z)) return "peru";
        if(/exterior|internacional|extranjero|europa|espana|alemania|italia|francia/.test(z)) return "exterior";
        if(/virtual|online/.test(c)) return "virtual";
        if(/internacional|extranjero/.test(c)) return "exterior";
        if(/(^|[^i])nacional|(^|[^i])local/.test(c)) return "peru";
        if(/peru/.test(p)) return "peru";
        if(p && p !== "-" && p !== "--") return "exterior";
        if(/unir|pronabec/.test(c + " " + p)) return "";
        if(!z && !c && !p) return "";
        return "";
      }

      function _mostrarPaisMeta(cobertura, zona, pais){
        var dest = _normalizarDestino(cobertura, zona, pais);
        var p = _textoMeta(pais, 40);
        var esGenerico = function(s){
          return !s || /^(en el extranjero|extranjero|exterior|internacional|internacional|en el exterior|varios paises|multiples paises|n\/a|-|--)$/i.test(s);
        };
        if(dest === "virtual") return "Virtual";
        if(dest === "peru"){
          if(esGenerico(p) || /peru/i.test(p)) return "PerÃº";
          return p;
        }
        if(dest === "exterior"){
          return esGenerico(p) ? "" : p;
        }
        if(p && !esGenerico(p)) return p;
        var c = _textoMeta(cobertura, 40);
        if(!c) return "";
        if(/(^|[^i])nacional/i.test(c)) return "PerÃº";
        if(/internacional|extranjero/i.test(c)) return "";
        return esGenerico(c) ? "" : c;
      }

      function _normalizarTextoMeta(s){
        return _textoMeta(s, 90);
      }

      function claseVisualBeca(tipo){
        var mapa = {
          "universitaria":"visual-universitaria",
          "no-universitaria":"visual-no-universitaria",
          "movilidad":"visual-movilidad",
          "idiomas":"visual-idiomas",
          "investigacion":"visual-investigacion",
          "excelencia":"visual-excelencia",
          "sociales":"visual-sociales",
          "deportivas":"visual-deportivas"
        };
        var clave = (tipo || "").toLowerCase()
          .replace(/\s+/g,"-")
          .replace(/[^a-z0-9-]/g,"");
        return mapa[clave] || "visual-beca-default";
      }

      function iconoBeca(tipo){
        var mapa = {
          "universitaria":"<svg viewBox='0 0 24 24' width='20' height='20' fill='none' stroke='currentColor' stroke-width='2'><path d='M12 2L2 7l10 5 10-5-10-5z'/><path d='M2 17l10 5 10-5'/><path d='M2 12l10 5 10-5'/></svg>",
          "movilidad":"<svg viewBox='0 0 24 24' width='20' height='20' fill='none' stroke='currentColor' stroke-width='2'><circle cx='12' cy='12' r='10'/><path d='M2 12h20'/><path d='M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z'/></svg>",
          "idiomas":"<svg viewBox='0 0 24 24' width='20' height='20' fill='none' stroke='currentColor' stroke-width='2'><path d='M5 8l6 6'/><path d='M4 14l6-6 2-3'/><path d='M2 5h12'/><path d='M7 2v3'/><path d='M22 22l-5-10-5 10'/><path d='M14 18h6'/></svg>",
          "investigacion":"<svg viewBox='0 0 24 24' width='20' height='20' fill='none' stroke='currentColor' stroke-width='2'><path d='M9 3h6v11l-3 3-3-3V3z'/><path d='M6 21h12'/></svg>",
          "default":"<svg viewBox='0 0 24 24' width='20' height='20' fill='none' stroke='currentColor' stroke-width='2'><path d='M12 2L2 7l10 5 10-5-10-5z'/><path d='M2 17l10 5 10-5'/></svg>"
        };
        var clave = (tipo || "").toLowerCase().replace(/\s+/g,"-");
        return mapa[clave] || mapa["default"];
      }

      function normalizarTipoBeca(tipo){
        var t = (tipo || "").toLowerCase()
          .normalize("NFD").replace(/[\u0300-\u036f]/g,"")
          .replace(/[^a-z0-9\s]/g,"");
        if(/universitari/.test(t)) return "universitaria";
        if(/no\s*universitari|tecnico|tecnolog/.test(t)) return "no-universitaria";
        if(/movilidad|intercambio|estudio.+exterior|extranjero/.test(t)) return "movilidad";
        if(/idioma|lengua|ingles|frances|aleman|espanol|idiomas/.test(t)) return "idiomas";
        if(/investig|ciencia|cientific/.test(t)) return "investigacion";
        if(/excelenc|merito|academica|rendimiento/.test(t)) return "excelencia";
        if(/social|comunitari|voluntari|desarrollo/.test(t)) return "sociales";
        if(/deport|atlet|futbol|basquet/.test(t)) return "deportivas";
        if(/beca/.test(t)) return "universitaria";
        return "otros";
      }

      function crearTarjetaBeca(beca){
        var tarjeta = document.createElement("article");
        tarjeta.className = "empleo-card beca-card";
        var tipoNormalizado = normalizarTipoBeca(beca.tipo);
        tarjeta.setAttribute("data-tipo", tipoNormalizado);
        tarjeta.setAttribute("data-nivel", beca.nivel || "");
        tarjeta.setAttribute("data-rama", beca.rama || "");
        tarjeta.setAttribute("data-cobertura", beca.cobertura || "");
        var destinoAttr = _normalizarDestino(beca.cobertura, beca.zona, beca.pais);
        tarjeta.setAttribute("data-destino", destinoAttr);
        tarjeta.setAttribute("data-convocante", beca.institucion || "");
        if(beca.fechaCierre){
          tarjeta.setAttribute("data-cierre", beca.fechaCierre);
        }

        var esNuevo =
          beca.fechaPublicacion &&
          (new Date().getTime() -
            new Date(beca.fechaPublicacion).getTime()) <
            7*24*60*60*1000;

        var hoy = new Date();
        hoy.setHours(0,0,0,0);
        var fechaInicioDate = parsearFecha(beca.fechaInicio);
        var fechaCierreDate = parsearFecha(beca.fechaCierre);
        var estado = "abierta";
        var textoEstado = "Vigente";

        if(fechaInicioDate && fechaInicioDate > hoy){
          estado = "pronto";
          textoEstado = "PrÃ³ximamente";
        } else if(fechaCierreDate){
          fechaCierreDate.setHours(0,0,0,0);
          var dias = Math.round((fechaCierreDate.getTime() - hoy.getTime()) / 86400000);
          if(dias < 0){
            estado = "cerrada";
            textoEstado = "Cerrada";
            tarjeta.classList.add("beca-cerrada-card");
          } else if(dias <= 5){
            estado = "abierta";
            textoEstado = dias === 0 ? "Cierra hoy" : dias === 1 ? "Cierra maÃ±ana" : "Cierra en " + dias + " dÃ­as";
          }
        }
        var estadoForzado = String(beca.estado || "").toLowerCase();
        if(/finalizad|cerrad|agotad|terminad|concluid|postulaci[oÃ³]n finalizada/.test(estadoForzado)){
          estado = "cerrada";
          textoEstado = "Cerrada";
          tarjeta.classList.add("beca-cerrada-card");
        } else if(estado === "abierta" && /proxim|programad|aun no|pr[oÃ³]xim/.test(estadoForzado)){
          estado = "pronto";
          textoEstado = "PrÃ³ximamente";
        } else if(estado === "abierta" && !fechaCierreDate && !/permanente|continua|sin cierre|sin l[iÃ­]mite|todo el a[nÃ±]o/.test(estadoForzado)){
          var pubBeca = beca.fechaPublicacion ? new Date(beca.fechaPublicacion) : null;
          if(pubBeca && !isNaN(pubBeca.getTime())){
            var diasPub = Math.floor((hoy.getTime() - pubBeca.getTime()) / 86400000);
            if(diasPub > 90){
              estado = "cerrada";
              textoEstado = "Cerrada";
              tarjeta.classList.add("beca-cerrada-card");
            }
          }
        }
        tarjeta.setAttribute("data-estado", estado);

        var media = document.createElement("div");
        media.className = "beca-media";
        var img = document.createElement("img");
        img.loading = "lazy";
        img.decoding = "async";
        img.alt = beca.titulo || "Beca";
        var placeholder = document.createElement("div");
        placeholder.className = "beca-placeholder";
        var phIcono = document.createElement("div");
        phIcono.className = "beca-placeholder-icono";
        phIcono.innerHTML = iconoBeca(tipoNormalizado);
        var phTexto = document.createElement("div");
        phTexto.className = "beca-placeholder-texto";
        phTexto.textContent = beca.institucion || "Beca";
        placeholder.appendChild(phIcono);
        placeholder.appendChild(phTexto);
        media.appendChild(placeholder);

        function mostrarPlaceholder(){
          if(img.parentNode){ img.parentNode.removeChild(img); }
          placeholder.style.display = "flex";
          media.classList.add("beca-media-sin-foto");
        }

        if(beca.imagen){
          media.insertBefore(img, placeholder);
          (function(imgEl, phEl){
            imgEl.addEventListener("error", function(){
              mostrarPlaceholder();
            });
            imgEl.addEventListener("load", function(){
              phEl.style.display = "none";
              media.classList.remove("beca-media-sin-foto");
            });
          })(img, placeholder);
          placeholder.style.display = "none";
          media.classList.remove("beca-media-sin-foto");
          img.src = beca.imagen;
        }else{
          mostrarPlaceholder();
        }

        if(esNuevo){
          var badgeNuevo = document.createElement("span");
          badgeNuevo.className = "beca-badge beca-badge-nuevo";
          badgeNuevo.textContent = "Nuevo";
          media.appendChild(badgeNuevo);
        }
        var badgeEstado = document.createElement("span");
        badgeEstado.className = "beca-badge beca-badge-" + estado;
        badgeEstado.textContent = textoEstado;
        media.appendChild(badgeEstado);

        tarjeta.appendChild(media);

        var contenido = document.createElement("div");
        contenido.className = "empleo-contenido beca-contenido";

        var chips = document.createElement("div");
        chips.className = "beca-chips";
        var chipTipo = document.createElement("span");
        chipTipo.className = "beca-chip beca-chip-tipo";
        chipTipo.textContent = tipoNormalizado.charAt(0).toUpperCase() + tipoNormalizado.slice(1);
        chips.appendChild(chipTipo);
        if(beca.nivel){
          var chipNivel = document.createElement("span");
          chipNivel.className = "beca-chip";
          chipNivel.textContent = _textoMeta(beca.nivel, 24) || beca.nivel;
          chips.appendChild(chipNivel);
        }
        contenido.appendChild(chips);

        var empresa = document.createElement("div");
        empresa.className = "empleo-empresa beca-institucion";
        empresa.textContent = beca.institucion || "InstituciÃ³n no especificada";
        contenido.appendChild(empresa);

        var titulo = document.createElement("h3");
        titulo.className = "empleo-titulo";
        titulo.textContent = beca.titulo || "Beca sin tÃ­tulo";
        contenido.appendChild(titulo);

        var meta = document.createElement("div");
        meta.className = "beca-meta";

        function _agregarLineaMeta(etiqueta, valor){
          var v = _textoMeta(valor, 80);
          if(!v) return;
          var linea = document.createElement("div");
          linea.className = "beca-meta-linea";
          var lab = document.createElement("span");
          lab.className = "beca-meta-etiqueta";
          lab.textContent = etiqueta;
          linea.appendChild(lab);
          linea.appendChild(document.createTextNode(" " + v));
          meta.appendChild(linea);
        }

        var insc = _textoInscripcion(beca.fechaInicio, beca.fechaCierre);
        if(insc) _agregarLineaMeta("ðŸ“… Inscripciones:", insc);

        var dirLimpia = _sanearDirigidoA(beca.dirigidoA);
        if(dirLimpia) _agregarLineaMeta("ðŸŽ“ Dirigido a:", dirLimpia);

        var durLimpia = _textoMeta(beca.duracion, 60) || "SegÃºn el programa";
        _agregarLineaMeta("â± DuraciÃ³n:", durLimpia);

        var paisMostrar = _mostrarPaisMeta(beca.cobertura, beca.zona, beca.pais);
        var apoyoMostrar = _textoApoyo(beca.apoyo || beca.financiamiento);
        if(paisMostrar || apoyoMostrar){
          var lineaDestino = document.createElement("div");
          lineaDestino.className = "beca-meta-linea beca-meta-destino";
          var parts = [];
          if(paisMostrar) parts.push("ðŸŒ " + paisMostrar);
          if(apoyoMostrar) parts.push("ðŸ’° " + apoyoMostrar);
          lineaDestino.textContent = parts.join("   ");
          meta.appendChild(lineaDestino);
        }

        if(meta.childNodes.length){
          contenido.appendChild(meta);
        }

        var boton = document.createElement("a");
        boton.className = "empleo-boton";
        boton.href = beca.url || "#";
        boton.target = "_blank";
        boton.rel = "noopener";
        var fechaCierreBtn = parsearFecha(beca.fechaCierre);
        boton.textContent = (estado === "cerrada" || (fechaCierreBtn && fechaCierreBtn < new Date())) ? "Convocatoria finalizada" : "Ver convocatoria";
        contenido.appendChild(boton);

        tarjeta.appendChild(contenido);

        return tarjeta;
      }

      var _BECAS_IMG_MAP = {
        "becas-unir-territorio-peru.html": "https://files.catbox.moe/2lw428.png",
        "becas-impacto-social-y-cultural-unir.html": "https://files.catbox.moe/ea6lu7.png",
        "becas-unir-joven-peru.html": "https://files.catbox.moe/fzo07r.png",
        "becas-servidor-publico-del-peru-unir.html": "https://files.catbox.moe/gqf0u2.png",
        "becas-poder-judicial-del-peru-unir.html": "https://files.catbox.moe/0r1meh.png",
        "premios-fernando-albi.html": "https://files.catbox.moe/70ht51.png",
        "becas-funiber-de-excelencia-academica.html": "https://www.uneatlantico.es/themes/uneatlantico/logo.png",
        "becas-pronabec-inclusion-carreras.html": "https://files.catbox.moe/o6mhif.jpg",
        "becas-pronabec-master-ucm.html": "https://www.pronabec.gob.pe/wp-content/uploads/2026/01/Banner-Beca-Posgrado-Espana_desktop2.png",
        "beca-generacion-bicentenario.html": "https://www.pronabec.gob.pe/wp-content/uploads/2026/09/becaria_bgb_banner.png"
      };

      function _esUrlImagen(s){
        return !!s && /^https?:\/\//i.test(s) && !/\.css(\?|$)/i.test(s) && !/\.js(\?|$)/i.test(s);
      }

      function _resolverImagenBeca(entry, html, postUrl, institucion){
        var campo = _ext(html, ["Imagen", "Imagen URL", "Foto", "Portada", "Banner"]);
        if(_esUrlImagen(campo)){
          return campo.replace(/^["'\s]+|["'\s]+$/g, "");
        }

        var tmp = document.createElement("div");
        tmp.innerHTML = html || "";
        var imgs = tmp.querySelectorAll("img");
        for(var i = 0; i < imgs.length; i++){
          var src = imgs[i].getAttribute("src") || imgs[i].getAttribute("data-src") || "";
          if(!src || /^(data:|#|javascript:)/i.test(src)) continue;
          if(/avatar|profile|favicon|sprite|logo-16|pixel|tracking/i.test(src)) continue;
          if(src.indexOf("//") === 0) src = "https:" + src;
          if(!_esUrlImagen(src)) continue;
          return _ladoImagenBlogger(src);
        }

        if(entry && entry.media$thumbnail && entry.media$thumbnail.url){
          var t = _ladoImagenBlogger(entry.media$thumbnail.url);
          if(t) return t;
        }

        if(postUrl){
          var slug = String(postUrl).split("?")[0].split("#")[0].replace(/\/$/, "").split("/").pop();
          if(slug && _BECAS_IMG_MAP[slug]) return _BECAS_IMG_MAP[slug];
          if(_BECAS_IMG_MAP[postUrl]) return _BECAS_IMG_MAP[postUrl];
        }

        if(institucion){
          var keyInst = institucion.toLowerCase();
          if(keyInst.indexOf("unir") !== -1 || keyInst.indexOf("rioja") !== -1){
            return _BECAS_IMG_MAP["becas-unir-territorio-peru.html"];
          }
          if(keyInst.indexOf("pronabec") !== -1 || keyInst.indexOf("auip") !== -1){
            if(keyInst.indexOf("auip") !== -1) return _BECAS_IMG_MAP["becas-pronabec-inclusion-carreras.html"];
            return _BECAS_IMG_MAP["beca-generacion-bicentenario.html"];
          }
          if(keyInst.indexOf("funiber") !== -1 || keyInst.indexOf("uneatlantico") !== -1 || keyInst.indexOf("atlÃ¡ntico") !== -1){
            return _BECAS_IMG_MAP["becas-funiber-de-excelencia-academica.html"];
          }
          if(keyInst.indexOf("auip") !== -1){
            return _BECAS_IMG_MAP["becas-pronabec-inclusion-carreras.html"];
          }
        }

        return "";
      }

        window._becasUtils = {
        parsearFecha: parsearFecha,
        extraerCampoBeca: extraerCampoBeca,
        claseVisualBeca: claseVisualBeca,
        iconoBeca: iconoBeca,
        normalizarTipoBeca: normalizarTipoBeca,
        crearTarjetaBeca: crearTarjetaBeca,
        textoMeta: _textoMeta,
        textoInscripcion: _textoInscripcion,
        sanearDirigidoA: _sanearDirigidoA,
        textoApoyo: _textoApoyo,
        normalizarDestino: _normalizarDestino,
        mostrarPaisMeta: _mostrarPaisMeta
      };

      function cargarBecasDinamicas(){
        var grid = document.getElementById("becasGrid");
        if(!grid) return;

        var buscarInput = document.getElementById("becaBusqueda");
        var buscarBtn = document.getElementById("becaBuscar");
        var carrusel = document.getElementById("categoriasCarrusel");
        var contadorEl = document.getElementById("contadorResultados");
        var cargarMasBtn = document.getElementById("cargarMasBecas");
        var cargarMasEstado = document.getElementById("cargarMasEstado");

        var indice = 0;
        var porPagina = 9;
        var cargando = false;
        var fin = false;
        var todasLasBecas = [];

        var blogUrl = window.location.hostname;
        var feedUrl = "/feeds/posts/default/-/Beca?alt=json&start-index=1&max-results=50";

        function cargarPagina(){
          if(cargando || fin) return;
          cargando = true;
          if(cargarMasBtn) cargarMasBtn.style.display = "none";
          if(cargarMasEstado) cargarMasEstado.textContent = "Cargando becas...";

          var url = "/feeds/posts/default/-/Beca?alt=json&start-index=" + (indice + 1) + "&max-results=" + porPagina;

          fetch(url)
            .then(function(r){
              if(!r.ok){ throw new Error("HTTP " + r.status); }
              return r.json();
            })
            .then(function(data){
              var entries = (data && data.feed && data.feed.entry) || [];
              if(entries.length < porPagina) fin = true;

              for(var i = 0; i < entries.length; i++){
                try{
                  var entry = entries[i];
                  var titulo = entry.title ? entry.title.$t : "";
                  var html = "";
                  if(entry.content){
                    html = entry.content.$t || "";
                  }

                  var tipo = extraerCampoBeca(html, ["Tipo", "Tipo de beca", "TipologÃ­a"]);
                  var rama = extraerCampoBeca(html, ["Rama", "Rama de estudio", "Campo"]);
                  var nivel = extraerCampoBeca(html, ["Nivel", "Nivel de estudios", "Grado"]);
                  var zona = extraerCampoBeca(html, ["Zona", "Ãmbito", "Ambito"]);
                  var pais = extraerCampoBeca(html, ["PaÃ­s", "Pais", "Destino paÃ­s"]);
                  var cobertura = extraerCampoBeca(html, ["Cobertura", "Destino", "UbicaciÃ³n", "PaÃ­s", "Pais"]);
                  var institucion = extraerCampoBeca(html, ["InstituciÃ³n", "Organismo", "Convocante", "Entidad", "Institucion"]);
                  var fechaInicio = extraerCampoBeca(html, ["Fecha de inicio", "Inicio de inscripciÃ³n", "Desde", "Inicio", "INICIO"]);
                  var fechaFin = extraerCampoBeca(html, ["Fecha de cierre", "Fecha cierre", "Fin de inscripciÃ³n", "Hasta", "Cierre", "CIERRE", "Fecha lÃ­mite"]);
                  var estadoConv = extraerCampoBeca(html, ["Estado de la convocatoria", "Estado convocatoria", "Estado"]);
                  fechaInicio = _quitaPrefijoFecha(fechaInicio);
                  fechaFin = _quitaPrefijoFecha(fechaFin);
                  var fechaPub = entry.published ? entry.published.$t : "";

                  var link = "";
                  if(entry.link){
                    for(var j = 0; j < entry.link.length; j++){
                      if(entry.link[j].rel === "alternate"){
                        link = entry.link[j].href;
                        break;
                      }
                    }
                  }

                  var dirigidoA = _sanearDirigidoA(extraerCampoBeca(html, ["Dirigido a", "Dirigido", "PÃºblico objetivo", "Publico objetivo", "Perfil"]));
                  var duracion = _textoMeta(extraerCampoBeca(html, ["DuraciÃ³n", "Duracion", "Periodo", "Plazo de beca"]), 60);
                  var apoyo = _textoApoyo(extraerCampoBeca(html, ["Apoyo", "Apoyo econÃ³mico", "Apoyo economico", "Financiamiento", "Beneficio econÃ³mico", "Beneficio economico", "Monto"]));
                  var financiamiento = apoyo;
                  var imagen = _resolverImagenBeca(entry, html, link, institucion);
                  var destino = _normalizarDestino(cobertura, zona, pais);

                  var beca = {
                    titulo: titulo,
                    tipo: tipo,
                    rama: rama,
                    nivel: nivel,
                    cobertura: cobertura,
                    zona: zona,
                    pais: pais,
                    destino: destino,
                    institucion: institucion,
                    fechaInicio: fechaInicio,
                    fechaFin: fechaFin,
                    fechaCierre: fechaFin,
                    fechaPublicacion: fechaPub,
                    estado: estadoConv,
                    url: link,
                    imagen: imagen,
                    dirigidoA: dirigidoA,
                    duracion: duracion,
                    apoyo: apoyo,
                    financiamiento: financiamiento,
                    tags: [tipo, nivel].filter(function(t){ return t; })
                  };

                  todasLasBecas.push(beca);
                  var tarjeta = crearTarjetaBeca(beca);
                  grid.appendChild(tarjeta);
                }catch(entryErr){
                  console.warn("Beca omitida:", entryErr);
                }
              }

              if(typeof window.insertarAnuncioEnGrid === "function"){
                try{ window.insertarAnuncioEnGrid(grid, ".empleo-card"); }catch(eAd){}
              }

              indice += entries.length;
              cargando = false;
              if(cargarMasEstado) cargarMasEstado.textContent = "";
              if(cargarMasBtn) cargarMasBtn.style.display = "none";
              actualizarContador();
              revisarScrollInfinito();
            })
            .catch(function(e){
              cargando = false;
              if(cargarMasEstado) cargarMasEstado.textContent = "Error al cargar. Intenta de nuevo.";
              console.error("Error cargando becas:", e);
            });
        }

        function actualizarContador(){
          var visibles = grid.querySelectorAll(".empleo-card:not([style*='display: none'])").length;
          if(contadorEl){
            contadorEl.textContent = "(" + visibles + " beca" + (visibles !== 1 ? "s" : "") + ")";
          }
        }

        if(cargarMasBtn){
          cargarMasBtn.style.display = "none";
          cargarMasBtn.addEventListener("click", function(){
            cargarPagina();
          });
        }

        function revisarScrollInfinito(){
          if(cargando || fin) return;
          if(!grid) return;
          var rect = grid.getBoundingClientRect();
          if(rect.bottom < window.innerHeight + 500){
            cargarPagina();
          }
        }

        window.addEventListener("scroll", revisarScrollInfinito, { passive: true });

        function filtrarBecasDinamicas(){
          var termino = buscarInput ? buscarInput.value.toLowerCase().trim() : "";
          var tipoActivo = [];
          var ramaActiva = [];
          var nivelActivo = [];
          var destinoActivo = [];
          var estadoActivo = [];

          document.querySelectorAll("[data-familia='tipo']:checked, [data-familia='tipo'].activo").forEach(function(el){
            var v = el.getAttribute("data-valor") || el.value;
            if(v) tipoActivo.push(v.toLowerCase().replace(/\s+/g,"-").replace(/[^a-z0-9-]/g,""));
          });
          document.querySelectorAll("[data-familia='rama']:checked, [data-familia='rama'].activo").forEach(function(el){
            var v = el.getAttribute("data-valor") || el.value;
            if(v) ramaActiva.push(v.toLowerCase().replace(/\s+/g,"-").replace(/[^a-z0-9-]/g,""));
          });
          document.querySelectorAll("[data-familia='nivel']:checked, [data-familia='nivel'].activo").forEach(function(el){
            var v = el.getAttribute("data-valor") || el.value;
            if(v) nivelActivo.push(v.toLowerCase().replace(/\s+/g,"-").replace(/[^a-z0-9-]/g,""));
          });
          document.querySelectorAll("[data-familia='destino']:checked, [data-familia='destino'].activo").forEach(function(el){
            var v = el.getAttribute("data-valor") || el.value;
            if(v) destinoActivo.push(v.toLowerCase().replace(/\s+/g,"-").replace(/[^a-z0-9-]/g,""));
          });
          document.querySelectorAll("[data-familia='cobertura']:checked, [data-familia='cobertura'].activo").forEach(function(el){
            var v = el.getAttribute("data-valor") || el.value;
            if(v){
              var mapCob = { "nacional":"peru", "internacional":"exterior", "extranjero":"exterior", "peru":"peru", "exterior":"exterior", "virtual":"virtual" };
              destinoActivo.push(mapCob[v.toLowerCase()] || v.toLowerCase().replace(/\s+/g,"-"));
            }
          });
          document.querySelectorAll("[data-familia='estado']:checked, [data-familia='estado'].activo").forEach(function(el){
            var v = el.getAttribute("data-valor") || el.value;
            if(v) estadoActivo.push(v.toLowerCase().replace(/\s+/g,"-").replace(/[^a-z0-9-]/g,""));
          });

          var tarjetas = grid.querySelectorAll(".empleo-card");
          var visibles = 0;

          for(var i = 0; i < tarjetas.length; i++){
            var tarjeta = tarjetas[i];
            var ok = true;

            if(termino){
              var texto = (
                (tarjeta.getAttribute("data-tipo") || "") + " " +
                (tarjeta.getAttribute("data-rama") || "") + " " +
                (tarjeta.getAttribute("data-nivel") || "") + " " +
                (tarjeta.getAttribute("data-destino") || "") + " " +
                (tarjeta.getAttribute("data-cobertura") || "") + " " +
                (tarjeta.getAttribute("data-convocante") || "") + " " +
                tarjeta.textContent
              ).toLowerCase();
              var partes = termino.split(" ");
              for(var p = 0; p < partes.length; p++){
                if(partes[p] && texto.indexOf(partes[p]) === -1){ ok = false; break; }
              }
            }

            if(ok && tipoActivo.length){
              var t = (tarjeta.getAttribute("data-tipo") || "").toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g,"").replace(/\s+/g,"-").replace(/[^a-z0-9-]/g,"");
              var textoTipo = tarjeta.textContent.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g,"");
              var matchTipo = false;
              for(var ti = 0; ti < tipoActivo.length; ti++){
                if(t === tipoActivo[ti] || textoTipo.indexOf(tipoActivo[ti]) !== -1){ matchTipo = true; break; }
              }
              if(!matchTipo) ok = false;
            }
            if(ok && ramaActiva.length){
              var r = (tarjeta.getAttribute("data-rama") || "").toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g,"").replace(/\s+/g,"-").replace(/[^a-z0-9-]/g,"");
              var textoRama = tarjeta.textContent.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g,"");
              var matchRama = false;
              for(var ri = 0; ri < ramaActiva.length; ri++){
                if(r === ramaActiva[ri] || textoRama.indexOf(ramaActiva[ri]) !== -1){ matchRama = true; break; }
              }
              if(!matchRama) ok = false;
            }
            if(ok && nivelActivo.length){
              var n = (tarjeta.getAttribute("data-nivel") || "").toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g,"").replace(/\s+/g,"-").replace(/[^a-z0-9-]/g,"");
              var textoNivel = tarjeta.textContent.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g,"");
              var matchNivel = false;
              for(var ni = 0; ni < nivelActivo.length; ni++){
                if(n === nivelActivo[ni] || textoNivel.indexOf(nivelActivo[ni]) !== -1){ matchNivel = true; break; }
              }
              if(!matchNivel) ok = false;
            }
            if(ok && destinoActivo.length){
              var dAttr = (tarjeta.getAttribute("data-destino") || "").toLowerCase().trim();
              var cOld = (tarjeta.getAttribute("data-cobertura") || "").toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g,"").trim();
              var matchDest = false;
              if(dAttr){
                matchDest = destinoActivo.indexOf(dAttr) !== -1;
              }else{
                var destCob = "";
                if(/virtual|online/.test(cOld)) destCob = "virtual";
                else if(/internacional|extranjero|extranjer/.test(cOld)) destCob = "exterior";
                else if(/(^|[^i])nacional|(^|[^i])local/.test(cOld)) destCob = "peru";
                if(destCob) matchDest = destinoActivo.indexOf(destCob) !== -1;
              }
              if(!matchDest) ok = false;
            }
            if(ok && estadoActivo.length){
              var estadoActual = tarjeta.getAttribute("data-estado") || "abierta";
              if(estadoActivo.indexOf(estadoActual) === -1) ok = false;
            }

            tarjeta.style.display = ok ? "" : "none";
            if(ok) visibles++;
          }

          if(contadorEl){
            contadorEl.textContent = "(" + visibles + " beca" + (visibles !== 1 ? "s" : "") + ")";
          }

          var tituloRes = document.getElementById("tituloResultados");
          if(tituloRes){
            tituloRes.textContent = visibles === 0 ? "Sin becas con esos filtros" : "Becas disponibles";
          }

          if(typeof window.insertarAnuncioEnGrid === "function"){
            try{ window.insertarAnuncioEnGrid(grid, ".empleo-card"); }catch(eAd){}
          }
        }

        if(buscarInput){
          buscarInput.addEventListener("input", filtrarBecasDinamicas);
        }
        if(buscarBtn){
          buscarBtn.addEventListener("click", filtrarBecasDinamicas);
        }

        document.querySelectorAll(".filtro-grupo[data-familia]").forEach(function(grupo){
          var checks = grupo.querySelectorAll('input[type="checkbox"]');
          for(var ci = 0; ci < checks.length; ci++){
            checks[ci].addEventListener("change", function(){
              var marcados = grupo.querySelectorAll('input[type="checkbox"]:checked');
              if(marcados.length > 0){
                grupo.classList.add("tiene-seleccion");
              }else{
                grupo.classList.remove("tiene-seleccion");
              }
              filtrarBecasDinamicas();
            });
          }
          grupo.addEventListener("click", function(){
            setTimeout(function(){
              var marcados = grupo.querySelectorAll('input[type="checkbox"]:checked');
              if(marcados.length > 0){
                grupo.classList.add("tiene-seleccion");
              }else{
                grupo.classList.remove("tiene-seleccion");
              }
            }, 10);
          });
        });

        var catBotones = carrusel ? carrusel.querySelectorAll(".categoria-card") : [];
        for(var c = 0; c < catBotones.length; c++){
          catBotones[c].addEventListener("click", function(){
            var cat = this.getAttribute("data-categoria");
            var chipFamilia = this.getAttribute("data-familia");
            var chipValor = this.getAttribute("data-valor");
            for(var j = 0; j < catBotones.length; j++){
              catBotones[j].classList.remove("activa");
            }
            this.classList.add("activa");

            function limpiarFamilia(familia){
              document.querySelectorAll("[data-familia='" + familia + "']").forEach(function(el){
                if(el.type === "checkbox"){ el.checked = false; }
                else{ el.classList.remove("activo"); }
              });
              var grupo = document.querySelector(".filtro-grupo[data-familia='" + familia + "']");
              if(grupo){ grupo.classList.remove("tiene-seleccion"); }
            }

            function marcarValor(familia, valor){
              if(!valor) return;
              document.querySelectorAll("[data-familia='" + familia + "']").forEach(function(el){
                var v = (el.getAttribute("data-valor") || el.value || "").toLowerCase().replace(/\s+/g,"-");
                if(v === valor){
                  if(el.type === "checkbox"){ el.checked = true; }
                  else{ el.classList.add("activo"); }
                }
              });
              var grupo = document.querySelector(".filtro-grupo[data-familia='" + familia + "']");
              if(grupo){
                var marcados = grupo.querySelectorAll('input[type="checkbox"]:checked');
                if(marcados.length > 0){ grupo.classList.add("tiene-seleccion"); }
              }
            }

            var fam = chipFamilia;
            var val = chipValor;
            if(!fam){
              var mapa = {
                "Universitaria":"universitaria",
                "No universitaria":"no-universitaria",
                "Movilidad":"movilidad",
                "Idiomas":"idiomas",
                "InvestigaciÃ³n":"investigacion",
                "Excelencia":"excelencia",
                "Sociales":"sociales",
                "Deportivas":"deportivas",
                "Otros":"otros",
                "Artes":"artes",
                "Ciencias":"ciencias"
              };
              val = mapa[cat] || "";
              if(val){ fam = "tipo"; }
            }

            if(!cat || cat === "Todos" || cat === "Todas" || (fam && !val)){
              limpiarFamilia("tipo");
              if(fam && val){ marcarValor(fam, val); }
            }else if(fam && val){
              limpiarFamilia(fam);
              marcarValor(fam, val);
            }

            filtrarBecasDinamicas();
          });
        }

        var antBtn = document.getElementById("categoriaAnterior");
        var sigBtn = document.getElementById("categoriaSiguiente");
        if(antBtn && carrusel){
          antBtn.addEventListener("click", function(){
            carrusel.scrollBy({left:-200,behavior:"smooth"});
          });
        }
        if(sigBtn && carrusel){
          sigBtn.addEventListener("click", function(){
            carrusel.scrollBy({left:200,behavior:"smooth"});
          });
        }

        cargarPagina();
      }

      function crearTarjetaArticulo(articulo){
        var card = document.createElement("a");
        card.className = "articulo-card";
        card.href = articulo.url || "#";
        card.target = "_self";
        card.setAttribute("data-tema", articulo.temaNorm || _normTemaArticulo(articulo.tema) || "");
        card.setAttribute("data-titulo", articulo.title || "");
        card.setAttribute("data-fecha", articulo.fechaISO || "");
        card.setAttribute("data-url", articulo.url || "");

        var media = document.createElement("div");
        media.className = "articulo-card-media";

        var img = document.createElement("img");
        img.loading = "lazy";
        img.decoding = "async";
        img.alt = articulo.title || "";
        var temaN = articulo.temaNorm || _normTemaArticulo(articulo.tema);
        img.src = articulo.imagen || _imagenArticuloFallback(temaN);
        (function(imgEl, temaImg){
          imgEl.addEventListener("error", function(){
            var fb = _imagenArticuloFallback(temaImg);
            if(imgEl.src !== fb) imgEl.src = fb;
          });
        })(img, temaN);
        media.appendChild(img);

        var categoria = document.createElement("span");
        categoria.className = "articulo-categoria";
        categoria.textContent = articulo.tema || "ArtÃ­culo";
        media.appendChild(categoria);

        var cuerpo = document.createElement("div");
        cuerpo.className = "articulo-card-cuerpo";

        var titulo = document.createElement("h3");
        titulo.className = "articulo-titulo";
        titulo.textContent = articulo.title;

        var resumen = document.createElement("p");
        resumen.className = "articulo-resumen";
        resumen.textContent = articulo.descripcion;

        var meta = document.createElement("div");
        meta.className = "articulo-meta";

        var fecha = document.createElement("span");
        fecha.textContent = articulo.fecha;

        var leer = document.createElement("span");
        leer.className = "articulo-leer";
        leer.textContent = "LEER â†’";

        meta.appendChild(fecha);
        meta.appendChild(leer);

        cuerpo.appendChild(titulo);
        cuerpo.appendChild(resumen);
        cuerpo.appendChild(meta);

        card.appendChild(media);
        card.appendChild(cuerpo);

        card.addEventListener("click", function(){
          if(articulo.url) _registrarVistaArticulo(articulo.url);
        });

        return card;
      }

      function _ladoImagenBlogger(url){
        if(!url) return "";
        var u = String(url);
        if(u.indexOf("blogger.googleusercontent.com") === -1) return u;
        return u
          .replace(/\/s\d+(-c)?\//i, "/w600/")
          .replace(/\/s\d+-w\d+\//i, "/w600/")
          .replace(/[?&]s72-c/, "")
          .replace(/[?&]s\d+/, "");
      }

      function _extraerImagenArticulo(entry, html, temaNorm){
        if(entry && entry.media$thumbnail && entry.media$thumbnail.url){
          var t = _ladoImagenBlogger(entry.media$thumbnail.url);
          if(t) return t;
        }
        var div = document.createElement("div");
        div.innerHTML = html || "";
        var imgs = div.querySelectorAll("img");
        for(var i=0;i<imgs.length;i++){
          var src = imgs[i].getAttribute("src") || "";
          if(!src || /^(data:|#|javascript:)/i.test(src)) continue;
          if(/avatar|profile|favicon|sprite|logo-16/i.test(src)) continue;
          if(src.indexOf("blogger.googleusercontent.com") !== -1) return _ladoImagenBlogger(src);
          if(/^https?:\/\//i.test(src)) return src;
        }
        return _imagenArticuloFallback(temaNorm);
      }

      function _imagenArticuloFallback(temaNorm){
        var mapa = {
          "cv":"https://images.unsplash.com/photo-1586281380349-632531db7ed4?auto=format&fit=crop&w=600&q=70",
          "consejos":"https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=600&q=70",
          "entrevistas":"https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&w=600&q=70",
          "carrera":"https://images.unsplash.com/photo-1521737604893-d14cc237f11d?auto=format&fit=crop&w=600&q=70",
          "mercado laboral":"https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?auto=format&fit=crop&w=600&q=70",
          "emprendimiento":"https://images.unsplash.com/photo-1556761175-5973dc0f32e7?auto=format&fit=crop&w=600&q=70",
          "otros":"https://images.unsplash.com/photo-1499750310107-5fef28a66643?auto=format&fit=crop&w=600&q=70"
        };
        return mapa[temaNorm] || mapa["otros"];
      }

      function _leerVistasArticulo(){
        try{
          var raw = localStorage.getItem("ephy_art_views");
          return raw ? (JSON.parse(raw) || {}) : {};
        }catch(e){ return {}; }
      }

      function _registrarVistaArticulo(url){
        if(!url) return;
        try{
          var vistas = _leerVistasArticulo();
          vistas[url] = (vistas[url] || 0) + 1;
          localStorage.setItem("ephy_art_views", JSON.stringify(vistas));
        }catch(e){}
      }

      function _normTemaArticulo(s){
        var t = _normHtml(s);
        if(!t) return "otros";
        if(/^(cv|curriculum|curriculo|hoja de vida|hoja vida|resume|vitae)/.test(t) || /\bcv\b/.test(t) || /hoja de vida/.test(t) || /curricul/.test(t)) return "cv";
        if(/entrevist/.test(t)) return "entrevistas";
        if(/consej|tips?\b|guia|sugerenc|recomendacion/.test(t)) return "consejos";
        if(/mercado|trabajo|empleo|laboral|vacante|puesto|oferta/.test(t) && !/emprend/.test(t)) return "mercado laboral";
        if(/carrera|crecimiento|profesional|desarrollo profesional|promocion|ascenso/.test(t)) return "carrera";
        if(/emprend|negocio|freelance|independient|emprender|startup/.test(t)) return "emprendimiento";
        return "otros";
      }

      function cargarArticulosDinamicas(){
        var grid = document.getElementById("articulosGrid");
        if(!grid) return;

        var buscarInput = document.getElementById("articuloBusqueda");
        var buscarBtn = document.getElementById("articuloBuscar");
        var carrusel = document.getElementById("categoriasCarrusel");
        var contadorEl = document.getElementById("contadorResultados");
        var cargarMasBtn = document.getElementById("cargarMasArticulos");
        var cargarMasEstado = document.getElementById("cargarMasEstado");

        var indice = 0;
        var porPagina = 9;
        var cargando = false;
        var fin = false;
        var categoriaActual = "Todos";
        var ordenActual = "recientes";
        var todosLosArticulos = [];

        function fechaCorta(iso){
          if(!iso) return "";
          var d = new Date(iso);
          if(isNaN(d.getTime())) return "";
          var dd = String(d.getDate()).length < 2 ? "0" + d.getDate() : String(d.getDate());
          var mm = String(d.getMonth() + 1).length < 2 ? "0" + (d.getMonth() + 1) : String(d.getMonth() + 1);
          return dd + "/" + mm + "/" + d.getFullYear();
        }

        function extraerDescripcion(html, max){
          var cont = document.createElement("div");
          cont.innerHTML = html || "";
          var basura = cont.querySelectorAll("script,style,noscript,iframe");
          for(var b=0;b<basura.length;b++) basura[b].remove();
          var ocultos = cont.querySelectorAll("div[style*='display:none'],div[style*='display: none']");
          for(var h=0;h<ocultos.length;h++) ocultos[h].remove();
          var p = cont.querySelector(".empleo-seccion p") || cont.querySelector("p");
          var t = String((p && p.textContent) || "").replace(/\s+/g," ").trim();
          if(t && max && t.length > max) t = t.substring(0, max - 1) + "â€¦";
          return t;
        }

        function cargarPagina(){
          if(cargando || fin) return;
          cargando = true;
          if(cargarMasBtn) cargarMasBtn.style.display = "none";
          if(cargarMasEstado) cargarMasEstado.textContent = "Cargando artÃ­culos...";

          var url = "/feeds/posts/default/-/Articulo?alt=json&start-index=" + (indice + 1) + "&max-results=" + porPagina;

          fetch(url)
            .then(function(r){
              if(!r.ok){ throw new Error("HTTP " + r.status); }
              return r.json();
            })
            .then(function(data){
              var entries = (data && data.feed && data.feed.entry) || [];
              if(entries.length < porPagina) fin = true;

              for(var i=0;i<entries.length;i++){
                try{
                  var entry = entries[i];
                  var html = (entry.content && entry.content.$t) || "";
                  var link = "";
                  if(entry.link){
                    for(var j=0;j<entry.link.length;j++){
                      if(entry.link[j].rel === "alternate"){ link = entry.link[j].href; break; }
                    }
                  }
                  var tema = extraerCampo(html, ["Tema", "CategorÃ­a", "Categoria", "Tipo de artÃ­culo", "Tipo de articulo"]);
                  if(!tema){
                    var nodoTema = html.match(/class=["'][^"']*empleo-categoria[^"']*["'][^>]*>([^<]+)</i);
                    if(nodoTema) tema = nodoTema[1];
                  }
                  if(!tema) tema = "Otros";
                  var temaNorm = _normTemaArticulo(tema);
                  var fechaISO = (entry.published && entry.published.$t) || "";

                  var articulo = {
                    title: (entry.title && entry.title.$t) || "",
                    url: link,
                    tema: tema,
                    temaNorm: temaNorm,
                    descripcion: extraerDescripcion(html, 220),
                    fecha: fechaCorta(fechaISO),
                    fechaISO: fechaISO,
                    imagen: _extraerImagenArticulo(entry, html, temaNorm)
                  };

                  todosLosArticulos.push(articulo);
                  grid.appendChild(crearTarjetaArticulo(articulo));
                }catch(entryErr){
                  console.warn("ArtÃ­culo omitido:", entryErr);
                }
              }

              indice += entries.length;
              cargando = false;
              if(cargarMasEstado) cargarMasEstado.textContent = "";
              if(cargarMasBtn) cargarMasBtn.style.display = "none";
              aplicarOrdenYFiltro();
              revisarScrollInfinito();
            })
            .catch(function(e){
              cargando = false;
              if(cargarMasEstado) cargarMasEstado.textContent = "Error al cargar artÃ­culos";
              console.error("Error cargando artÃ­culos:", e);
            });
        }

        function aplicarOrdenYFiltro(){
          var termino = _normHtml(buscarInput ? buscarInput.value : "");
          var catFiltro = "";
          if(categoriaActual && categoriaActual !== "Todos"){
            catFiltro = _normTemaArticulo(categoriaActual);
          }

          var tarjetas = Array.prototype.slice.call(grid.querySelectorAll(".articulo-card"));
          var vistas = _leerVistasArticulo();

          tarjetas.sort(function(a,b){
            if(ordenActual === "titulo"){
              var ta = _normHtml(a.getAttribute("data-titulo") || "");
              var tb = _normHtml(b.getAttribute("data-titulo") || "");
              return ta.localeCompare(tb, "es");
            }
            if(ordenActual === "antiguos"){
              var fa = a.getAttribute("data-fecha") || "";
              var fb = b.getAttribute("data-fecha") || "";
              return fa.localeCompare(fb);
            }
            if(ordenActual === "vistos"){
              var ua = a.getAttribute("data-url") || a.getAttribute("href") || "";
              var ub = b.getAttribute("data-url") || b.getAttribute("href") || "";
              var va = vistas[ua] || 0;
              var vb = vistas[ub] || 0;
              if(vb !== va) return vb - va;
              var fa2 = a.getAttribute("data-fecha") || "";
              var fb2 = b.getAttribute("data-fecha") || "";
              return fb2.localeCompare(fa2);
            }
            var fa3 = a.getAttribute("data-fecha") || "";
            var fb3 = b.getAttribute("data-fecha") || "";
            return fb3.localeCompare(fa3);
          });

          for(var s=0;s<tarjetas.length;s++) grid.appendChild(tarjetas[s]);

          var visibles = 0;
          for(var i=0;i<tarjetas.length;i++){
            var tarjeta = tarjetas[i];
            var ok = true;
            var temaCard = _normTemaArticulo(tarjeta.getAttribute("data-tema") || "");
            var textoCard = _normHtml(tarjeta.textContent || "");

            if(termino){
              var partes = termino.split(" ");
              for(var p=0;p<partes.length;p++){
                if(partes[p] && textoCard.indexOf(partes[p]) === -1){ ok = false; break; }
              }
            }

            if(ok && catFiltro && catFiltro !== "todos" && temaCard !== catFiltro){
              ok = false;
            }

            tarjeta.style.display = ok ? "" : "none";
            if(ok) visibles++;
          }

          if(contadorEl){
            contadorEl.textContent = "(" + visibles + " artÃ­culo" + (visibles !== 1 ? "s" : "") + ")";
          }

          var tituloEl = document.getElementById("tituloResultados");
          if(tituloEl){
            if(ordenActual === "vistos") tituloEl.textContent = "ArtÃ­culos mÃ¡s leÃ­dos";
            else if(ordenActual === "titulo") tituloEl.textContent = "ArtÃ­culos Aâ†’Z";
            else if(ordenActual === "antiguos") tituloEl.textContent = "ArtÃ­culos antiguos";
            else tituloEl.textContent = "ArtÃ­culos recientes";
          }

          if(typeof window.insertarAnuncioEnGrid === "function"){
            try{ window.insertarAnuncioEnGrid(grid, ".articulo-card"); }catch(eAd){}
          }
        }

        if(buscarInput){
          buscarInput.addEventListener("input", aplicarOrdenYFiltro);
        }
        if(buscarBtn){
          buscarBtn.addEventListener("click", function(e){
            e.preventDefault();
            aplicarOrdenYFiltro();
          });
        }

        var ordenBtns = document.querySelectorAll(".orden-articulos-barra .orden-btn");
        for(var o=0;o<ordenBtns.length;o++){
          ordenBtns[o].addEventListener("click", function(){
            for(var j=0;j<ordenBtns.length;j++) ordenBtns[j].classList.remove("activo");
            this.classList.add("activo");
            ordenActual = this.getAttribute("data-orden") || "recientes";
            aplicarOrdenYFiltro();
          });
        }

        var catBotones = carrusel ? carrusel.querySelectorAll(".categoria-card") : [];
        for(var c=0;c<catBotones.length;c++){
          catBotones[c].addEventListener("click", function(){
            var cat = this.getAttribute("data-categoria");
            for(var j=0;j<catBotones.length;j++) catBotones[j].classList.remove("activa");
            this.classList.add("activa");
            categoriaActual = cat;
            aplicarOrdenYFiltro();
          });
        }

        var antBtn = document.getElementById("categoriaAnterior");
        var sigBtn = document.getElementById("categoriaSiguiente");
        if(antBtn && carrusel){
          antBtn.addEventListener("click", function(){
            carrusel.scrollBy({left:-200,behavior:"smooth"});
          });
        }
        if(sigBtn && carrusel){
          sigBtn.addEventListener("click", function(){
            carrusel.scrollBy({left:200,behavior:"smooth"});
          });
        }

        if(cargarMasBtn){
          cargarMasBtn.style.display = "none";
          cargarMasBtn.addEventListener("click", function(){
            cargarPagina();
          });
        }

        function revisarScrollInfinito(){
          if(cargando || fin) return;
          if(!grid) return;
          var rect = grid.getBoundingClientRect();
          if(rect.bottom < window.innerHeight + 500){
            cargarPagina();
          }
        }

        window.addEventListener("scroll", revisarScrollInfinito, { passive: true });

        if(/^\/\d{4}\/\d{2}\//.test(location.pathname)){
          _registrarVistaArticulo(location.href.split("#")[0]);
        }

        cargarPagina();
      }

      function cargarArticulosRecomendados(){
        var pathname = location.pathname || "";
        if(!/^\/\d{4}\/\d{2}\//.test(pathname)) return;
        var contenedor = document.querySelector(".post-body") || document.querySelector(".entry-content") || document.querySelector(".post-outer") || document.querySelector(".post") || document.querySelector("article");
        if(!contenedor) return;
        if(contenedor.querySelector("#articulosGrid, .portal-empleos, .buscador-empleos, #categoriasCarrusel")) return;
        var html = contenedor.innerHTML || "";
        var tipoEntradaLocal = _tipoEntradaActual();
        if(tipoEntradaLocal === "empleos" && /Salario:\s*|Sueldo:\s*/i.test(html) && !/\bTema\s*[:=]/i.test(html)) return;

        var temaActual = extraerCampo(html, ["Tema", "CategorÃ­a", "Categoria", "Tipo de artÃ­culo", "Tipo de articulo"]);
        if(!temaActual){
          var m = html.match(/class=["'][^"']*empleo-categoria[^"']*["'][^>]*>([^<]+)</i);
          if(m) temaActual = m[1];
        }
        var temaNorm = _normTemaArticulo(temaActual || "");
        var urlActual = location.href.split("#")[0];
        var tituloEl = contenedor.querySelector("h1") || contenedor.querySelector("h2");
        var tituloActual = tituloEl ? tituloEl.textContent.trim() : "";
        var palabrasClave = _normHtml(tituloActual).split(/\s+/).filter(function(w){ return w.length > 3; });

        fetch("/feeds/posts/default/-/Articulo?alt=json&start-index=1&max-results=50")
          .then(function(r){ return r.json(); })
          .then(function(data){
            var entries = (data && data.feed && data.feed.entry) || [];
            var similares = [];
            for(var i=0;i<entries.length;i++){
              var entry = entries[i];
              var link = "";
              if(entry.link){
                for(var j=0;j<entry.link.length;j++){
                  if(entry.link[j].rel === "alternate"){ link = entry.link[j].href; break; }
                }
              }
              if(!link || _mismaUrlRel(link, urlActual)) continue;
              var entryHtml = (entry.content && entry.content.$t) || "";
              var entryTitulo = entry.title ? entry.title.$t : "";
              if(_normHtml(entryTitulo) === _normHtml(tituloActual)) continue;
              var entryTema = extraerCampo(entryHtml, ["Tema", "CategorÃ­a", "Categoria", "Tipo de artÃ­culo", "Tipo de articulo"]);
              if(!entryTema){
                var em = entryHtml.match(/class=["'][^"']*empleo-categoria[^"']*["'][^>]*>([^<]+)</i);
                if(em) entryTema = em[1];
              }
              if(!entryTema) entryTema = "Otros";
              var entryTemaNorm = _normTemaArticulo(entryTema);
              var score = 0;
              if(temaNorm && entryTemaNorm === temaNorm && temaNorm !== "otros") score += 3;
              if(temaNorm && entryTemaNorm === temaNorm) score += 1;
              var entryNorm = _normHtml(entryHtml + " " + entryTitulo);
              for(var p=0;p<palabrasClave.length;p++){
                if(entryNorm.indexOf(palabrasClave[p]) !== -1){ score += 1; break; }
              }
              if(score === 0) score = 1;
              {
                var fechaISO = (entry.published && entry.published.$t) || "";
                var fecha = "";
                if(fechaISO){
                  var fd = new Date(fechaISO);
                  if(!isNaN(fd.getTime())){
                    var dd = String(fd.getDate()).length < 2 ? "0" + fd.getDate() : String(fd.getDate());
                    var mm = String(fd.getMonth() + 1).length < 2 ? "0" + (fd.getMonth() + 1) : String(fd.getMonth() + 1);
                    fecha = dd + "/" + mm + "/" + fd.getFullYear();
                  }
                }
                var desc = "";
                var cont = document.createElement("div");
                cont.innerHTML = entryHtml;
                var oc = cont.querySelectorAll("div[style*='display:none'],div[style*='display: none'],script,style");
                for(var h=0;h<oc.length;h++) oc[h].remove();
                var pr = cont.querySelector(".empleo-seccion p") || cont.querySelector("p");
                desc = String((pr && pr.textContent) || "").replace(/\s+/g," ").trim();
                if(desc.length > 220) desc = desc.substring(0,219) + "â€¦";
                var temaNormR = _normTemaArticulo(entryTema);
                similares.push({
                  title: entryTitulo,
                  url: link,
                  tema: entryTema,
                  temaNorm: temaNormR,
                  descripcion: desc,
                  fecha: fecha,
                  fechaISO: fechaISO,
                  imagen: _extraerImagenArticulo(entry, entryHtml, temaNormR),
                  score: score,
                  _r: Math.random()
                });
              }
            }
            similares.sort(function(a,b){
              if(b.score !== a.score) return b.score - a.score;
              return a._r - b._r;
            });
            similares = similares.slice(0,12);
            if(similares.length === 0) return;

            var seccion = document.createElement("div");
            seccion.className = "seccion-relacionada seccion-articulos-rel";
            seccion.setAttribute("data-rel", "articulos");
            seccion.style.cssText = "margin-top:40px;padding-top:24px;border-top:2px solid #e5e7eb;";
            seccion.innerHTML = '<h3 style="margin:0 0 16px;font-size:16px;color:#0f4c81;font-weight:800;">ArtÃ­culos relacionados</h3>';

            var gridR = document.createElement("div");
            gridR.className = "articulos-grid rel-scroll";

            var pasoRelArt = (window.pasoAnuncio ? window.pasoAnuncio(gridR) : 6);
            for(var k=0;k<similares.length;k++){
              gridR.appendChild(crearTarjetaArticulo(similares[k]));
              if(k > 0 && (k + 1) % pasoRelArt === 0 && k < similares.length - 1){
                var adA = document.createElement("div");
                adA.className = "empleo-anuncio empleo-anuncio-feed rel-ad";
                adA.innerHTML = '<div class="empleo-anuncio-inner">Espacio publicitario</div>';
                gridR.appendChild(adA);
              }
            }
            seccion.appendChild(gridR);
            _insertarRelacionada(contenedor, seccion, "articulos");
          })
          .catch(function(){});
      }

      function marcarSectorEntrada(){
        var entrada = document.querySelector(".empleo-individual");
        if(!entrada){ return; }
        var cab = entrada.querySelector(".empleo-cabecera");
        if(!cab || cab.querySelector(".empleo-sector-chip")){ return; }
        var texto = entrada.textContent || "";
        var m = texto.match(/Tipo\s+(?:de\s+)?contratante:\s*(Estado|Privado)/i);
        if(!m){ return; }
        var sector = m[1].toLowerCase();
        if(sector !== "estado" && sector !== "privado"){ return; }
        var chip = document.createElement("span");
        chip.className = "empleo-sector-chip empleo-sector-" + sector;
        chip.textContent = sector === "estado" ? "Estado" : "Privado";
        var h1 = cab.querySelector("h1");
        if(h1){
          cab.insertBefore(chip, h1);
        }else{
          cab.appendChild(chip);
        }
      }

      try{ cargarBecasDinamicas(); }catch(eB){ console.error("[Becas] Error:", eB); }
      try{ cargarArticulosDinamicas(); }catch(eA){ console.error("[Articulos] Error:", eA); }
      try{ cargarArticulosRecomendados(); }catch(eR){ console.error("[Recomendados] Error:", eR); }

      try{ construirMigas(); }catch(eM){ console.error("[Mejoras] migas:", eM); }
      try{ construirCompartir(); }catch(eM){ console.error("[Mejoras] compartir:", eM); }
      try{ construirFlotantes(); }catch(eM){ console.error("[Mejoras] flotantes:", eM); }
      try{ marcarSectorEntrada(); }catch(eM){ console.error("[Mejoras] sector:", eM); }
      try{ datosEstructurados(); }catch(eM){ console.error("[Mejoras] schema:", eM); }
      setTimeout(function(){
        try{ refrescarItemListas(); }catch(e){}
      }, 2500);
      setTimeout(function(){
        try{ refrescarItemListas(); }catch(e){}
      }, 6000);
      try{ construirContadores(); }catch(eM){ console.error("[Mejoras] contadores:", eM); }
      try{ enlazarContacto(); }catch(eM){ console.error("[Mejoras] contacto:", eM); }
      try{ enlazarCabecera(); }catch(eM){ console.error("[Mejoras] cabecera:", eM); }
      try{ aplicarVigenciaPorDefecto(); }catch(eM){ console.error("[Mejoras] vigencia:", eM); }
      try{ actualizarEstadosConvocatoria(); }catch(eM){ console.error("[Mejoras] estados:", eM); }
      try{ enlazarFiltros(); }catch(eM){ console.error("[Mejoras] filtros:", eM); }
      try{ filtrarBecas()(); }catch(eM){ console.error("[Mejoras] filtrarBecas:", eM); }

  } catch(e) { console.error("[Mejoras UX/SEO] Error:", e); }
    })();

  }
  _cuandoListo();
})();
