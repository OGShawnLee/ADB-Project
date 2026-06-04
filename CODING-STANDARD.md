# Estándar de Codificación: Proyecto Final - Administración de Bases de Datos (AdventureWorks API)

Este documento define el estándar de codificación y las buenas prácticas para el desarrollo del proyecto final de la materia **Administración de Bases de Datos** (específicamente para la base de datos AdventureWorks y la API REST en ASP.NET Core). Todos los desarrolladores deben adherirse a estas directrices para asegurar la consistencia, legibilidad y mantenibilidad del código.

---

## 1. Reglas Generales

1. **Idioma:** Todo el código fuente (nombres de variables, clases, métodos, comentarios) y la documentación técnica deben escribirse en **español** o siguiendo las convenciones de dominio del proyecto (como entidades de AdventureWorks, DTOs y parámetros de base de datos).
2. **Estilo de Llaves/Corchetes:** Se utilizará estrictamente el estilo **Same-Line** (la llave de apertura `{` en la misma línea que la declaración o la estructura de control, también conocido como estilo K&R/OTBS).
3. **Indentación:** Se utilizará estrictamente **2 espacios** para la indentación (no usar tabuladores `\t`).

---

## 2. Convenciones de Nomenclatura

### 2.1 Controladores (API REST)
* **Regla:** Todos los controladores de la API deben terminar con el sufijo `Controller.cs`.
* **Ejemplos:**
  - `ProductsController.cs`
  - `EmployeesController.cs`
  - `CustomersController.cs`

### 2.2 Modelos y DTOs (Data Transfer Objects)
* **Modelos de Entidad (EF Core):** Deben representar las tablas de la base de datos y estar en PascalCase.
  - Ejemplo: `Product.cs`, `Employee.cs`, `Customer.cs`.
* **DTOs:** Objetos utilizados para transferir datos entre peticiones HTTP y controladores. Deben terminar con el sufijo `DTO`.
  - Ejemplo: `ProductDTO.cs`, `CreateProductDTO.cs`.

### 2.3 Contexto de Datos
* **DbContext:** La clase de contexto de base de datos de EF Core debe terminar con el sufijo `Context` o `DbContext`.
  - Ejemplo: `AdventureWorksContext.cs` o `AppDbContext.cs`.

### 2.4 Variables, Parámetros y Miembros de Clase
* **Clases, Interfaces y Métodos:** PascalCase.
  - Ejemplo: `CalcularImpuesto()`, `ProductsController`.
* **Propiedades de Clase:** PascalCase.
  - Ejemplo: `ListPrice`, `ProductNumber`.
* **Parámetros y Variables Locales:** camelCase.
  - Ejemplo: `productID`, `connectionString`, `statusParam`.
* **Constantes:** SCREAMING_SNAKE_CASE (letras mayúsculas separadas por guion bajo).
  - Ejemplo: `DEFAULT_IVA`, `MAX_RETRY_COUNT`.

### 2.5 Manejo de Acrónimos (DTO, ID, DB, API, REST, SQL)
* **Regla:** Los acrónimos deben escribirse completamente en mayúsculas, incluso cuando forman parte de nombres compuestos en PascalCase o camelCase.
* **Ejemplos:**
  - En clases/propiedades (PascalCase): `ProductDTO`, `ProductID`, `ConexionDB`, `APIController`, `SQLCommand`.
  - En variables/parámetros (camelCase): `productDTO`, `productID`, `conexionDB`, `apiController`, `sqlCommand`.

---

## 3. Formato y Estilo de Código (C#)

### 3.1 Estilo de Llaves (Same-Line Braces)
Las llaves de apertura `{` deben colocarse en la misma línea que la declaración de la clase, método, propiedad o estructura de control (`if`, `for`, `while`, `switch`). Las llaves de cierre `}` deben colocarse en su propia línea alineadas con el inicio de la declaración.

#### Ejemplo de Clase, Propiedades y Métodos:
```csharp
namespace AdventureWorks.API.Controllers {
  public class ProductsController {
    private readonly AppDbContext dbContext;

    public ProductsController(AppDbContext dbContext) {
      this.dbContext = dbContext;
    }

    public void ValidarPrecio(decimal precio) {
      if (precio <= 0) {
        throw new ArgumentException("El precio debe ser mayor a cero.");
      }
    }
  }
}
```

#### Ejemplo de Estructuras de Control:
```csharp
// Estructura IF-ELSE
if (statusCode == 200) {
  return Ok(response);
} else {
  return BadRequest(response);
}

// Estructura FOR / FOREACH
foreach (var product in products) {
  AplicarImpuesto(product);
}

// Estructura SWITCH
switch (statusCode) {
  case 200: {
    return Ok(response);
  }
  case 400: {
    return BadRequest(response);
  }
  default: {
    return StatusCode(500, response);
  }
}
```

### 3.2 Espaciado e Indentación
* Utilizar **2 espacios** para la indentación.
* Colocar un espacio después de palabras clave de control (`if`, `for`, `while`, `switch`).
* Colocar un espacio alrededor de operadores binarios (por ejemplo, `x + y`, `a == b`, `c = d`).

---

## 4. Arquitectura y Buenas Prácticas

### 4.1 Controladores de la API REST
* **Decoración:** Los controladores deben estar decorados con `[ApiController]` y `[Route("api/[controller]")]`.
* **Verbos HTTP:** Utilizar los verbos correspondientes de forma adecuada:
  - `GET`: Para consultar uno o todos los registros (sin modificar estado).
  - `POST`: Para inserciones de nuevos registros.
  - `PUT`: Para actualizaciones completas.
  - `DELETE`: Para eliminación lógica o física.
* Toda respuesta de la API debe devolver códigos HTTP representativos que se alineen con los devueltos por los procedimientos almacenados (200, 400, 404, 500).

### 4.2 Acceso a Datos y Procedimientos Almacenados
* **Inyección SQL:** Bajo ninguna circunstancia se debe concatenar texto para formar consultas SQL. Se debe usar estrictamente `SqlParameter` para pasar valores a los procedimientos almacenados.
* **Uso de EF Core:** Se utilizarán las funcionalidades de EF Core (`FromSqlRaw` y `ExecuteSqlRawAsync`) para invocar los objetos programados en SQL Server:
  - Las consultas deben mapearse a colecciones de objetos.
  - Las operaciones transaccionales (CRUD) deben pasar parámetros de salida `OUTPUT` para capturar el estado y el mensaje generado en la base de datos.

### 4.3 Gestión de Credenciales y Configuración
* La cadena de conexión de la base de datos debe almacenarse en `appsettings.json` o mediante variables de entorno en sistemas de desarrollo. Nunca se deben colocar credenciales en duro (hardcoded) en el código C#.

---

## 5. Manejo de Excepciones y Errores

* **No silenciar excepciones:** Evitar bloques `catch` vacíos. Toda excepción capturada debe ser registrada o manejada adecuadamente.
* **Manejo de Errores Transaccionales:** Asegurarse de que los controladores capturen errores de base de datos (`SqlException`) y devuelvan códigos de estado HTTP correctos al cliente.
* **Mensajes amigables:** En las respuestas HTTP de error, ocultar detalles internos de la base de datos (como contraseñas, nombres de servidores o trazas de la pila) para evitar vulnerabilidades de seguridad.

---

## 6. Control de Versiones (Conventional Commits)

Para mantener un historial de Git ordenado, estructurado y fácil de leer por todo el equipo, se adoptará la especificación de **Conventional Commits** y los mensajes de commit **se escribirán en inglés**. Cada mensaje de commit debe seguir la siguiente estructura:

```text
<type>(<scope>): <short description in lowercase>

[optional body]
```

### Tipos de Commit Permitidos (Cased in lowercase):
* **`feat`**: Implementación de una nueva funcionalidad o requerimiento (ej. `feat(api): add CRUD endpoints for products`).
* **`fix`**: Corrección de un error o comportamiento incorrecto (ej. `fix(db): correct age calculation in scalar function`).
* **`docs`**: Cambios exclusivamente en la documentación del proyecto (ej. `docs(standard): include conventional commits section`).
* **`style`**: Formateo, espacios, puntos y comas, o estilos de código sin cambios de lógica (ej. `style(api): format code using editorconfig`).
* **`refactor`**: Reorganización o mejora de código sin cambiar su funcionalidad (ej. `refactor(api): simplify dependency injection`).
* **`chore`**: Configuración de compilación, gitignore, dependencias o herramientas (ej. `chore(git): ignore SQL Server backups in gitignore`).
* **`perf`**: Cambios que mejoran el rendimiento (ej. `perf(api): optimize query for better performance`).
* **`test`**: Adición o modificación de tests (ej. `test(api): add unit tests for authentication`).
* **`db`**: Cambios exclusivamente en la base de datos (ej. `db(sqlserver): add new scalar function`).

### Reglas para los Mensajes:
1. **Idioma:** Todos los mensajes deben estar redactados en **inglés**.
2. **Imperativo:** Usar el tiempo presente y modo imperativo (ej. "add", "fix", "format" en lugar de "added" o "fixes").
3. **Minúsculas:** Escribir la descripción corta completamente en minúsculas y sin punto final.
4. **Alcance:** El `<scope>` (alcance) es opcional, pero se recomienda usar términos descriptivos de las capas (ej. `api`, `db`, `git`, `standard`).
