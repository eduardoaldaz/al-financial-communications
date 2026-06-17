page 50300 "GFL Fin. Comm. Setup"
{
    Caption = 'Config. Comunicaciones Financieras GFL';
    PageType = Card;
    SourceTable = "GFL Fin. Comm. Setup";
    ApplicationArea = All;
    UsageCategory = Administration;
    DeleteAllowed = false;
    InsertAllowed = false;

    layout
    {
        area(Content)
        {
            group(REQ2)
            {
                Caption = 'Deuda Pendiente a Clientes';

                field("Customer Overdue Enabled"; Rec."Customer Overdue Enabled")
                {
                    ApplicationArea = All;
                    ToolTip = 'Activa o desactiva el envío programado de deuda pendiente a clientes (días 1 y 15 del mes).';
                }
                field("Customer Overdue Report ID"; Rec."Customer Overdue Report ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'ID del informe de deuda pendiente usado como fallback si no hay Custom Report Selection configurada para el cliente.';
                }
                field("Overdue Days Threshold"; Rec."Overdue Days Threshold")
                {
                    ApplicationArea = All;
                    ToolTip = 'Número mínimo de días de vencimiento para incluir una factura en el envío. Ej: 7 = solo facturas vencidas hace 7+ días.';
                }
                field("Customer Email From Address"; Rec."Customer Email From Address")
                {
                    ApplicationArea = All;
                    ToolTip = 'Dirección de email desde la que se envían los extractos a clientes.';
                }
                field("Customer Email From Name"; Rec."Customer Email From Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Nombre que aparece como remitente del email.';
                }
            }
            group(Signature)
            {
                Caption = 'Firma y plantilla email';

                field("Email Banner"; Rec."Email Banner")
                {
                    ApplicationArea = All;
                    ToolTip = 'Banner que aparece en la cabecera del email.';
                }
                field("LinkedIn URL"; Rec."LinkedIn URL")
                {
                    ApplicationArea = All;
                    ToolTip = 'URL del perfil de LinkedIn que aparece en el pie del email.';
                }
                field("Contact Phone"; Rec."Contact Phone")
                {
                    ApplicationArea = All;
                    ToolTip = 'Teléfono de contacto que aparece en el pie del email.';
                }
                field("Company Address"; Rec."Company Address")
                {
                    ApplicationArea = All;
                    ToolTip = 'Dirección de la empresa que aparece en el pie del email.';
                }
                field("Company Website"; Rec."Company Website")
                {
                    ApplicationArea = All;
                    ToolTip = 'Sitio web de la empresa que aparece en el pie del email.';
                }
            }
            group(REQ3)
            {
                Caption = 'Aviso de Pago a Proveedores';

                field("Auto Send Remittance"; Rec."Auto Send Remittance")
                {
                    ApplicationArea = All;
                    ToolTip = 'Activa o desactiva el envío automático del aviso de pago al registrar pagos a proveedores.';
                }
                field("Remittance Report ID"; Rec."Remittance Report ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'ID del informe de aviso de pago. Valor por defecto: 400.';
                }
                field("Vendor Email From Address"; Rec."Vendor Email From Address")
                {
                    ApplicationArea = All;
                    ToolTip = 'Dirección de email desde la que se envían los avisos de pago a proveedores.';
                }
                field("Vendor Email From Name"; Rec."Vendor Email From Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Nombre que aparece como remitente del email a proveedores.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            group(BannerActions)
            {
                Caption = 'Banner email';

                action(ImportBanner)
                {
                    Caption = 'Importar banner';
                    ApplicationArea = All;
                    Image = Import;
                    ToolTip = 'Carga un archivo de imagen como banner del email.';

                    trigger OnAction()
                    var
                        InStr: InStream;
                        FileName: Text;
                    begin
                        if UploadIntoStream('Seleccionar banner', '', 'Imágenes (*.png;*.jpg;*.jpeg)|*.png;*.jpg;*.jpeg|Todos (*.*)|*.*', FileName, InStr) then begin
                            Rec."Email Banner".ImportStream(InStr, FileName);
                            Rec.Modify();
                        end;
                    end;
                }
                action(DeleteBanner)
                {
                    Caption = 'Eliminar banner';
                    ApplicationArea = All;
                    Image = Delete;
                    ToolTip = 'Elimina el banner actual.';

                    trigger OnAction()
                    begin
                        Clear(Rec."Email Banner");
                        Rec.Modify();
                    end;
                }
            }
            action("Enviar extractos ahora")
            {
                Caption = 'Enviar extractos ahora';
                ApplicationArea = All;
                Image = SendEmailPDF;
                ToolTip = 'TEST: Ejecuta el envío de extractos a todos los clientes con "Imprimir extractos" activo, saltándose la validación de fecha (día 1/15) y el flag "Habilitado".';

                trigger OnAction()
                var
                    Notifier: Codeunit "GFL Cust. Overdue Notifier";
                begin
                    Notifier.SendOverdueNotificationsForced();
                end;
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.GetSetup();
    end;
}
