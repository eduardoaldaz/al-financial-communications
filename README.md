# GFL Financial Communications - Extensión AL para Business Central

## Descripción
Automatización de comunicaciones financieras para Global Food Link S.L.
- **REQ 2**: Envío programado de deuda pendiente a clientes (días 1 y 15 de cada mes)
- **REQ 3**: Envío automático de aviso de pago a proveedores al registrar pagos

## Rango de IDs: 50300 - 50399
(Alertas Certificados: 50100-50199, Protección Precios: 50200-50299)

## Estructura del Proyecto
```
src/
├── Setup/
│   ├── GFLFinCommSetup.Table.al          → Table 50300 - Configuración
│   ├── GFLFinCommSetupPage.Page.al       → Page 50300 - Página configuración
│   └── GFLFinCommInstall.Codeunit.al     → Codeunit 50302 - Instalación
├── REQ2-CustomerOverdue/
│   └── GFLCustOverdueNotifier.Codeunit.al → Codeunit 50300 - Envío deuda pendiente
└── REQ3-VendorRemittance/
    ├── GFLVendorRemittanceSender.Codeunit.al       → Codeunit 50301 - Envío aviso pago
    ├── GFLVendorLedgerEntryExt.TableExtension.al   → TableExt 50300 - Campo "Aviso enviado"
    └── GFLVendorLedgerEntriesPageExt.PageExtension.al → PageExt 50300 - Botones en Movs. proveedor
```

## Reports utilizados
- **Report 106**: Deuda pendiente cliente (REQ 2)
- **Report 400**: Aviso pago - Entradas (REQ 3)

## Instalación en Sandbox

### Paso 1: Configurar entorno
1. Abrir el proyecto en VS Code
2. En `launch.json`, configurar `environmentName` con el nombre del sandbox
3. Pulsar F5 para desplegar

### Paso 2: Configuración inicial en BC
1. Buscar "Config. Comunicaciones Financieras GFL"
2. REQ 2: Activar, verificar Report ID = 106, email = administracion@globalfoodlink.eu, días = 7
3. REQ 3: Activar envío automático, verificar Report ID = 400, configurar email

### Paso 3: Job Queue - REQ 2 (Deuda pendiente)
- Tipo objeto: Codeunit
- ID objeto: 50300
- Recurrencia: Día 1 y 15 de cada mes
- Hora: 08:00

### Paso 4: Job Queue - REQ 3 (Aviso de pago)
- Tipo objeto: Codeunit
- ID objeto: 50301
- Recurrencia: Cada 5 minutos
- Horario: 07:00 - 20:00

## PENDIENTE antes de producción
1. Capturar XML real del RequestPage del Report 106 (ejecutar manualmente y capturar)
2. Probar envío completo en sandbox con clientes y proveedores de prueba
3. Verificar que los emails se reciben correctamente
4. Validar formatos de PDF generados
