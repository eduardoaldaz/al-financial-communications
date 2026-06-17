table 50300 "GFL Fin. Comm. Setup"
{
    Caption = 'Config. Comunicaciones Financieras GFL';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Clave primaria';
            DataClassification = CustomerContent;
        }
        // === REQ 2 — Deuda pendiente a clientes ===
        field(10; "Customer Overdue Report ID"; Integer)
        {
            Caption = 'ID Informe Deuda Pendiente Cliente';
            DataClassification = CustomerContent;
            InitValue = 106;
        }
        field(11; "Overdue Days Threshold"; Integer)
        {
            Caption = 'Días mínimos de vencimiento';
            DataClassification = CustomerContent;
            InitValue = 7;
            MinValue = 0;
        }
        field(12; "Customer Email From Address"; Text[250])
        {
            Caption = 'Email remitente (clientes)';
            DataClassification = CustomerContent;
        }
        field(13; "Customer Email From Name"; Text[100])
        {
            Caption = 'Nombre remitente (clientes)';
            DataClassification = CustomerContent;
            InitValue = 'Global Food Link - Administración';
        }
        field(14; "Customer Email Subject"; Text[250])
        {
            Caption = 'Asunto email (clientes)';
            DataClassification = CustomerContent;
            ObsoleteState = Pending;
            ObsoleteReason = 'El asunto se genera automáticamente según el idioma del cliente.';
        }
        field(15; "Customer Overdue Enabled"; Boolean)
        {
            Caption = 'Envío deuda pendiente activo';
            DataClassification = CustomerContent;
        }
        field(16; "Company Logo"; Media)
        {
            Caption = 'Logo empresa';
            DataClassification = CustomerContent;
            ObsoleteState = Pending;
            ObsoleteReason = 'El banner ya incluye el logo de empresa.';
        }
        field(17; "Email Banner"; Media)
        {
            Caption = 'Banner email';
            DataClassification = CustomerContent;
        }
        field(18; "LinkedIn URL"; Text[250])
        {
            Caption = 'URL LinkedIn';
            DataClassification = CustomerContent;
            InitValue = 'https://www.linkedin.com/company/global-food-link-sl/';
        }
        // === REQ 3 — Aviso de pago a proveedores ===
        field(20; "Remittance Report ID"; Integer)
        {
            Caption = 'ID Informe Aviso de Pago';
            DataClassification = CustomerContent;
            InitValue = 400;
        }
        field(21; "Vendor Email From Address"; Text[250])
        {
            Caption = 'Email remitente (proveedores)';
            DataClassification = CustomerContent;
        }
        field(22; "Vendor Email From Name"; Text[100])
        {
            Caption = 'Nombre remitente (proveedores)';
            DataClassification = CustomerContent;
            InitValue = 'Global Food Link - Pagos';
        }
        field(23; "Vendor Email Subject"; Text[250])
        {
            Caption = 'Asunto email (proveedores)';
            DataClassification = CustomerContent;
            InitValue = 'Aviso de pago - Global Food Link S.L.';
            ObsoleteState = Pending;
            ObsoleteReason = 'El asunto se genera automáticamente según el idioma del proveedor.';
        }
        field(24; "Auto Send Remittance"; Boolean)
        {
            Caption = 'Envío automático aviso de pago';
            DataClassification = CustomerContent;
        }
        // === General / Firma ===
        field(30; "Contact Phone"; Text[30])
        {
            Caption = 'Teléfono de contacto';
            DataClassification = CustomerContent;
            InitValue = '+34 948 820 865';
        }
        field(31; "Company Address"; Text[250])
        {
            Caption = 'Dirección empresa';
            DataClassification = CustomerContent;
        }
        field(32; "Company Website"; Text[250])
        {
            Caption = 'Sitio web empresa';
            DataClassification = CustomerContent;
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }

    procedure GetSetup()
    begin
        if not Get() then begin
            Init();
            "Customer Overdue Report ID" := 106;
            "Overdue Days Threshold" := 7;
            "Remittance Report ID" := 400;
            "LinkedIn URL" := 'https://www.linkedin.com/company/global-food-link-sl/';
            Insert();
        end;
    end;
}
