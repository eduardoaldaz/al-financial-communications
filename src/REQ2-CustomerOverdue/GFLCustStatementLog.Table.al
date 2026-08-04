table 50301 "GFL Cust. Statement Log"
{
    Caption = 'Registro envíos extracto clientes';
    DataClassification = CustomerContent;
    LookupPageId = "GFL Cust. Statement Log";
    DrillDownPageId = "GFL Cust. Statement Log";

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Nº entrada';
            AutoIncrement = true;
        }
        field(2; "Customer No."; Code[20])
        {
            Caption = 'Nº cliente';
            TableRelation = Customer;
        }
        field(3; "Customer Name"; Text[100])
        {
            Caption = 'Nombre cliente';
        }
        field(4; "Notification Date"; Date)
        {
            Caption = 'Fecha notificación';
        }
        field(5; "Notification Time"; Time)
        {
            Caption = 'Hora notificación';
        }
        field(6; "Email To"; Text[250])
        {
            Caption = 'Email destinatario';
        }
        field(7; "Overdue Amount"; Decimal)
        {
            Caption = 'Importe vencido';
            DecimalPlaces = 2 : 2;
        }
        field(8; "No. of Documents"; Integer)
        {
            Caption = 'Nº documentos';
        }
        field(9; "Result"; Option)
        {
            Caption = 'Resultado';
            OptionCaption = 'Enviado,Error';
            OptionMembers = Sent,Error;
        }
        field(10; "Error Message"; Text[250])
        {
            Caption = 'Mensaje de error';
        }
        field(11; "Sent By"; Code[50])
        {
            Caption = 'Enviado por';
        }
        field(12; "Report ID"; Integer)
        {
            Caption = 'ID informe';
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(K1; "Notification Date", "Customer No.") { }
        key(K2; "Customer No.", "Notification Date") { }
    }
}
