
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

/* =========================================================
   CONFIGURACIÃ“N DEL PORTAL
   Cambia estas dos lÃ­neas con tus datos reales:
   - whatsapp: tu nÃºmero con cÃ³digo de paÃ­s SIN el signo +
     (ejemplo "51950123456" para PerÃº)
   - correoContacto: el correo para recibir mensajes
   ========================================================= */
window.PORTAL_CONFIG = {
  whatsapp: "",
  correoContacto: "empleosperuhoy@gmail.com",
  nombreSitio: "EMPLEOS PERÃš HOY",
  dominio: "https://empleosperuhoy.blogspot.com"
};

var FEED_URL =
"https://empleosperuhoy.blogspot.com/feeds/posts/default/-/Empleo?alt=json-in-script&max-results=50&orderby=published&callback=empleosPeruHoyCallback";

var empleos = [];
var categoriaActiva = "Todos";

var filtrosAplicados = {
  modalidad:[],
  experiencia:[],
  ciudad:[],
  salario:[]
};

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
   EXTRACCIÃ“N ROBUSTA DE CAMPOS
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
   CATEGORIZACIÃ“N INTELIGENTE
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
     ADMINISTRACIÃ“N Y FINANZAS
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
     EDUCACIÃ“N
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
     EVALUACIÃ“N SECUNDARIA DEL TEXTO
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
   CIUDADES DEL PERÃš
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

function detectarCiudad(ubicacion){

  var texto =
    normalizar(ubicacion);

  for(var i=0;i<ciudadesPeru.length;i++){

    if(
      texto.indexOf(
        normalizar(
          ciudadesPeru[i]
        )
      ) !== -1
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
    t.indexOf("mas de") !== -1 ||
    t.indexOf("mÃ¡s de") !== -1 ||
    t.indexOf("+") !== -1 ||
    t.indexOf("minimo") !== -1 ||
    t.indexOf("mÃ­nimo") !== -1
  ){
    max = 99;
  }

  return {
    texto:texto,
    min:min,
    max:max,
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

    return experiencia.max >= 5 ||
           experiencia.min >= 5;

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

/* =========================================================
   CONSTRUCCIÃ“N DEL OBJETO ESTRUCTURADO
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
    ) ||
    detectarCiudad(
      ubicacion
    );

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

    workday:jornada,

    vacancies:vacantes,

    publicationDate:
      fechaPublicacion,

    closingDate:
      fechaCierre,

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
   TARJETA MAESTRA
   ========================================================= */

function crearTarjeta(
  empleo
){

  var tarjeta =
    document.createElement("article");

  tarjeta.className =
    "empleo-card";

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

  var contenido =
    document.createElement("div");

  contenido.className =
    "empleo-contenido";

  var titulo =
    document.createElement("h3");

  titulo.className =
    "empleo-titulo";

  titulo.textContent =
    empleo.title;

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
    "VER OFERTA";

  if(empleo.url){

    boton.target =
      "_self";

  }

  pie.appendChild(
    fecha
  );

  pie.appendChild(
    boton
  );

  contenido.appendChild(
    titulo
  );

  contenido.appendChild(
    empresa
  );

  contenido.appendChild(
    datos
  );

  contenido.appendChild(
    salario
  );

  contenido.appendChild(
    descripcion
  );

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

/* =========================================================
   TEXTO DE BÃšSQUEDA
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
    empleo.jobLevel

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
    filtrosAplicados.ciudad.length &&
    filtrosAplicados.ciudad.indexOf(
      empleo.city
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

  return true;

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

  grid.innerHTML = "";

  var visibles =
    empleos.filter(
      ofertaVisible
    );

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

    titulo.textContent =
      busquedaActual ||
      Object.keys(
        filtrosAplicados
      ).some(function(k){

        return filtrosAplicados[k]
          .length;

      })
        ? "Resultados de bÃºsqueda"
        : "Empleos recientes";

  }else{

    titulo.textContent =
      categoriaActiva;

  }

  contador.textContent =
    visibles.length +
    (
      visibles.length === 1
        ? " oferta"
        : " ofertas"
    );

  if(!visibles.length){

    var vacio =
      document.createElement(
        "div"
      );

    vacio.className =
      "empleo-vacio";

    vacio.textContent =
      "No encontramos ofertas que coincidan con tu bÃºsqueda.";

    grid.appendChild(
      vacio
    );

    return;

  }

  visibles.forEach(
    function(empleo){

      grid.appendChild(
        crearTarjeta(
          empleo
        )
      );

    }
  );

}

/* =========================================================
   CIUDADES DINÃMICAS
   ========================================================= */

function actualizarCiudades(){

  var contenedor =
    document.getElementById(
      "opcionesCiudades"
    );

  if(!contenedor){
    return;
  }

  contenedor.innerHTML =
    "";

  var ciudades = {};

  empleos.forEach(
    function(empleo){

      var ciudad =
        limpiarTexto(
          empleo.city
        );

      if(
        ciudad &&
        ciudad !==
        "No especificado"
      ){

        ciudades[ciudad] =
          (
            ciudades[ciudad] ||
            0
          ) + 1;

      }

    }
  );

  var lista =
    Object.keys(
      ciudades
    ).sort(
      function(a,b){

        if(
          ciudades[b] !==
          ciudades[a]
        ){

          return
            ciudades[b] -
            ciudades[a];

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
      "No hay ciudades disponibles";

    contenedor.appendChild(
      sin
    );

    return;

  }

  lista.forEach(
    function(ciudad){

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
        ciudad;

      var span =
        document.createElement(
          "span"
        );

      span.textContent =
        ciudad;

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

  document.querySelectorAll(
    ".filtro-grupo"
  ).forEach(
    function(grupo){

      var tipo =
        grupo.getAttribute(
          "data-filtro"
        );

      var activo =
        filtrosAplicados[tipo] &&
        filtrosAplicados[tipo]
          .length > 0;

      if(activo){

        grupo.classList.add(
          "tiene-seleccion"
        );

      }else{

        grupo.classList.remove(
          "tiene-seleccion"
        );

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
   BÃšSQUEDA
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

    if(
      !data ||
      !data.feed ||
      !data.feed.entry
    ){

      empleos = [];

      actualizarCiudades();
      render();
      paginacionActualizar(false);

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

    if(window.__portalCargarMas){

      var claves = {};
      empleos.forEach(function(e){
        claves[e.url] = true;
      });
      var agregados = 0;
      nuevos.forEach(function(e){
        if(!claves[e.url]){
          claves[e.url] = true;
          empleos.push(e);
          agregados++;
        }
      });
      window.__portalCargarMas = false;
      paginacionActualizar(agregados > 0);

    }else{

      empleos = nuevos;

    }

    actualizarCiudades();
    actualizarEstadoFiltros();
    render();
    paginacionActualizarEstado();

  }catch(error){

    console.error(
      "Error procesando ofertas:",
      error
    );

    empleos = [];

    render();
    paginacionActualizar(false);

  }

};

/* =========================================================
   CARGAR FEED
   ========================================================= */

function cargarOfertas(){
  cargarOfertasDesde(0);
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

  script.src =
    FEED_URL.replace(
      "callback=",
      "start-index=" + (desde || 1) + "&callback="
    ) +
    "&_=" +
    new Date().getTime();

  script.async =
    true;

  script.onerror =
    function(){

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

  if(estado){
    estado.textContent =
      empleos.length +
      " ofertas publicadas y cargadas";
  }

  var hayFiltros =
    categoriaActiva !== "Todos" ||
    busquedaActual ||
    Object.keys(filtrosAplicados).some(function(k){
      return filtrosAplicados[k].length;
    });

  var total =
    window.__portalTotalEmpleos || 0;

  if(!hayFiltros && total > empleos.length){
    contenedor.removeAttribute("hidden");
  }else{
    contenedor.setAttribute("hidden", "");
  }

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

      window.__portalCargarMas =
        true;

      var estado =
        document.getElementById(
          "cargarMasEstado"
        );

      if(estado){
        estado.textContent =
          "Cargando mÃ¡s ofertas...";
      }

      boton.disabled =
        true;

      cargarOfertasDesde(
        empleos.length + 1
      );

    }
  );

})();

cargarOfertas();

    })();

    /* =========================================================
       PORTALES SECUNDARIOS (Becas y ArtÃ­culos)
       Se activan solo si existe #becasGrid o #articulosGrid
       ========================================================= */
    (function(){

      "use strict";

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
          if(elemento.matches && elemento.matches(".empleo-destacado p")){
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

      cargarPortal(SECCIONES.becas);
      cargarPortal(SECCIONES.articulos);

    })();

    /* =========================================================
       OFERTAS RELACIONADAS (solo si existe .empleo-individual)
       ========================================================= */
    (function(){

  
var contenedorOferta =
        document.querySelector(
          ".empleo-individual"
        );

      if(!contenedorOferta){
        return;
      }
  "use strict";

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
      TITULO_ACTUAL
    );

  if(
    CATEGORIA_ACTUAL === "Otros"
  ){

    CATEGORIA_ACTUAL =
      normalizarCategoria(
        obtenerTextoPagina(".empleo-cabecera .empleo-categoria")
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
      ".empleo-info-card,.empleo-destacado p,.empleo-info-card div"
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

    var categoria = (
      categoriaDesdeTitulo !== "Otros"
        ? categoriaDesdeTitulo
        : normalizarCategoria(
            categoriaOriginal
          )
    );

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
      ["Salario"]
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
      empresa:empresa || "Empresa no especificada",
      categoria:categoria,
      ubicacion:ubicacion || "No especificada",
      modalidad:modalidad || "No especificada",
      contrato:contrato || "No especificado",
      salario:salario || "No especificado",
      experiencia:experiencia || "",
      descripcion:descripcion || "",
      fecha:fecha,
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

    ofertas =
      ofertas.slice(0,6);

    if(!ofertas.length){

      contenedor.innerHTML =
        '<div style="padding:15px;color:#6b7280;font-size:13px;">No hay ofertas recomendadas disponibles.</div>';

      return;

    }

    var html = "";

    for(var j=0;j<ofertas.length;j++){

      html += crearTarjeta(
        ofertas[j]
      );

    }

    contenedor.innerHTML = html;

  }

  window.ofertasRelacionadasCallback =
    mostrarOfertas;

  var script =
    document.createElement("script");

  script.src =
    "https://empleosperuhoy.blogspot.com/feeds/posts/default/-/Empleo?alt=json-in-script&max-results=50&orderby=published&callback=ofertasRelacionadasCallback";

  script.async = true;

document.body.appendChild(script);

    })();

    /* =========================================================
       CORRECTOR UNIVERSAL DE TARJETAS RELACIONADAS
       Los posts viejos llevan su propio JS incrustado que
       clasifica categorias SIN quitar tildes, por lo que
       "Educacion"/"Administracion y Finanzas" caen a "Otros".
       Este corrector reclasifica cada tarjeta por su titulo
       usando el normalizador sin tildes.
       ========================================================= */
    (function(){

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
          var regla = clasificarCategoria(titulo.textContent);
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
          var etiqueta = tarjeta.querySelector(".relacionado-etiqueta");
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
        var reglaActual = clasificarCategoria(tituloEntrada.textContent);
        if(!reglaActual || reglaActual.c === "Otros"){ return; }
        var grid = contenedor.querySelector(".relacionados-grid") || contenedor;
        var tarjetas = grid.querySelectorAll(".relacionado-card");
        if(tarjetas.length < 2){ return; }
        var mismas = [];
        var resto = [];
        for(var i=0;i<tarjetas.length;i++){
          var tituloTarjeta = tarjetas[i].querySelector(".relacionado-titulo");
          var regla = tituloTarjeta ? clasificarCategoria(tituloTarjeta.textContent) : null;
          if(regla && regla.c === reglaActual.c){
            mismas.push(tarjetas[i]);
          } else {
            resto.push(tarjetas[i]);
          }
        }
        if(!mismas.length){ return; }
        var orden = mismas.concat(resto);
        var igual = true;
        for(var j=0;j<orden.length;j++){
          if(grid.children[j] !== orden[j]){
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
        var regla = clasificarCategoria(tituloEntrada.textContent);
        if(regla && etiquetaCategoria.textContent !== regla.c){
          etiquetaCategoria.textContent = regla.c;
        }
        etiquetaCategoria.setAttribute("data-corregida", "1");
      }

      function ejecutarCorreccion(){
        corregirCabeceraEntrada();
        corregirTarjetas();
      }

      ejecutarCorreccion();
      if(window.MutationObserver){
        var objetivo = document.getElementById("ofertasRelacionadas");
        if(objetivo){
          new MutationObserver(ejecutarCorreccion).observe(
            objetivo,
            { childList: true, subtree: true, characterData: false, attributes: false }
          );
        }
      }

})();

    /* =========================================================
       GADGET NAVEGACIÃ“N FLOTANTE (Inicio/Empleos/Becas/ArtÃ­culos)
       Inyecta una barra inferior fija en pÃ¡ginas y entradas del
       portal para poder cambiar de secciÃ³n con un toque.
       ========================================================= */
    (function(){

      "use strict";

      function esPortal(){
        return !!(
          document.querySelector(".portal-empleos") ||
          document.querySelector(".portal-navport") ||
          document.querySelector(".empleo-individual")
        );
      }

      var ICONOS = {
        inicio:"<path d=\"M3 11l9-8 9 8\"></path><path d=\"M5 10v10h14V10\"></path><path d=\"M9 20v-6h6v6\"></path>",
        empleos:"<rect x=\"4\" y=\"7\" width=\"16\" height=\"13\" rx=\"2\"></rect><path d=\"M9 7V5h6v2\"></path><path d=\"M4 12h16\"></path>",
        becas:"<path d=\"M3 9l9-5 9 5-9 5z\"></path><path d=\"M7 11.5V16c3 2 7 2 10 0v-4.5\"></path><path d=\"M21 9v6\"></path>",
        articulos:"<path d=\"M4 5h16\"></path><path d=\"M4 12h16\"></path><path d=\"M8 19h12\"></path><path d=\"M4 12h4\"></path><path d=\"M8 19l-4-7\"></path>"
      };

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
          { etiqueta: "ArtÃ­culos", icono: ICONOS.articulos, url: "/p/articulos.html" }
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

      "use strict";

      var CFG =
        window.PORTAL_CONFIG ||
        {
          whatsapp: "",
          correoContacto: "",
          nombreSitio: "EMPLEOS PERÃš HOY",
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
        if(!contenedor){ return; }

        var ol = document.createElement("ol");
        var liInicio = document.createElement("li");
        var aInicio = document.createElement("a");
        aInicio.href = "/";
        aInicio.textContent = "Inicio";
        liInicio.appendChild(aInicio);

        var liSeccion = document.createElement("li");
        var aSeccion = document.createElement("a");
        aSeccion.href = "/p/empleos.html";
        aSeccion.textContent = "Empleos";
        liSeccion.appendChild(aSeccion);

        var categoria = contenedor.querySelector(".empleo-cabecera .empleo-categoria");
        var liCategoria = null;
        if(categoria){
          var textoCat = String(categoria.textContent || "").trim();
          if(textoCat && textoCat !== "Otros"){
            liCategoria = document.createElement("li");
            liCategoria.textContent = textoCat;
          }
        }

        var liActual = document.createElement("li");
        liActual.className = "actual";
        var titulo = contenedor.querySelector(".empleo-cabecera h1");
        liActual.textContent = titulo
          ? String(titulo.textContent).trim().slice(0,54)
          : "Entrada";

        ol.appendChild(liInicio);
        ol.appendChild(liSeccion);
        if(liCategoria){
          ol.appendChild(liCategoria);
        }
        ol.appendChild(liActual);

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
        if(!document.querySelector(".portal-empleos") && !document.querySelector(".empleo-individual")){ return; }

        var hayWhatsapp =
          CFG.whatsapp &&
          CFG.whatsapp.replace(/\D/g,"").length >= 9;

        var contenedor = document.createElement("div");
        contenedor.className = "portal-flotantes";

        if(hayWhatsapp){
          var wa = document.createElement("a");
          wa.className = "portal-fab portal-fab-whatsapp";
          wa.href = "https://wa.me/" + CFG.whatsapp.replace(/\D/g,"") +
            "?text=" + encodeURIComponent("Hola, quiero informaciÃ³n sobre EMPLEOS PERÃš HOY");
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

      function inyectarJsonLd(objeto){
        var script = document.createElement("script");
        script.type = "application/ld+json";
        script.setAttribute("defer", "");
        script.textContent = JSON.stringify(objeto);
        (document.head || document.documentElement).appendChild(script);
      }

      function datosEstructurados(){
        if(!document.querySelector(".portal-empleos") && !document.querySelector(".empleo-individual")){ return; }

        inyectarJsonLd({
          "@context": "https://schema.org",
          "@type": "WebSite",
          "name": CFG.nombreSitio,
          "url": CFG.dominio
        });

        var entrada = document.querySelector(".empleo-individual");
        if(!entrada){ return; }

        try{
          var titulo = (entrada.querySelector(".empleo-cabecera h1") || {}).textContent || "";
          var empresa = (entrada.querySelector(".empleo-cabecera .empleo-empresa") || {}).textContent || "";
          var categoria = (entrada.querySelector(".empleo-cabecera .empleo-categoria") || {}).textContent || "";

          var ubicacion = "";
          var infoCards = entrada.querySelectorAll(".empleo-info-card");
          for(var i=0;i<infoCards.length;i++){
            var label = (infoCards[i].querySelector(".empleo-info-label") || {}).textContent || "";
            if(/ubicaci|ciudad|lugar/i.test(label)){
              ubicacion = (infoCards[i].querySelector(".empleo-info-value") || {}).textContent || "";
            }
          }

          var descripcion = "";
          var parrafo = entrada.querySelector(".empleo-seccion p");
          if(parrafo){
            descripcion = String(parrafo.textContent || "").trim().slice(0,420);
          }

          if(!titulo){ return; }

          var job = {
            "@context": "https://schema.org",
            "@type": "JobPosting",
            "title": titulo,
            "datePosted": new Date().toISOString().split("T")[0],
            "description": descripcion || titulo
          };
          if(empresa){
            job.hiringOrganization = { "@type": "Organization", "name": empresa };
          }
          if(ubicacion){
            job.jobLocation = {
              "@type": "Place",
              "address": { "@type": "PostalAddress", "addressLocality": ubicacion, "addressCountry": "PE" }
            };
          }
          if(categoria){
            job.employmentType = categoria;
          }
          inyectarJsonLd(job);
        }catch(error){
          console.error("Error en datos estructurados:", error);
        }
      }

      /* ---------- CONTADORES REALES ---------- */

      var contadorCallbacks = {};

      function contarSeccion(etiqueta, elemento){
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

      function construirContadores(){
        if(document.querySelector(".portal-migas")){ return; }
        var items = document.querySelectorAll(".portal-stats-item[data-conteo]");
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

      construirMigas();
      construirCompartir();
      construirFlotantes();
      datosEstructurados();
      construirContadores();
      enlazarContacto();
      enlazarCabecera();

    })();

  }
  _cuandoListo();
})();
