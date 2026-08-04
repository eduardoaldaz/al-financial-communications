page 50301 "GFL Cust. Statement Log"
{
    Caption = 'Registro envíos extracto clientes';
    PageType = List;
    SourceTable = "GFL Cust. Statement Log";
    Editable = false;
    ApplicationArea = All;
    UsageCategory = Lists;

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field("Customer No."; Rec."Customer No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Número del cliente al que se envió el extracto.';
                }
                field("Customer Name"; Rec."Customer Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Nombre del cliente.';
                }
                field("Notification Date"; Rec."Notification Date")
                {
                    ApplicationArea = All;
                    ToolTip = 'Fecha en que se realizó el envío.';
                }
                field("Notification Time"; Rec."Notification Time")
                {
                    ApplicationArea = All;
                    ToolTip = 'Hora en que se realizó el envío.';
                }
                field("Email To"; Rec."Email To")
                {
                    ApplicationArea = All;
                    ToolTip = 'Dirección de email a la que se envió el extracto.';
                }
                field("Overdue Amount"; Rec."Overdue Amount")
                {
                    ApplicationArea = All;
                    ToolTip = 'Importe total de facturas vencidas incluidas en el extracto.';
                }
                field("No. of Documents"; Rec."No. of Documents")
                {
                    ApplicationArea = All;
                    ToolTip = 'Número de documentos vencidos incluidos en el extracto.';
                }
                field(Result; Rec.Result)
                {
                    ApplicationArea = All;
                    ToolTip = 'Resultado del envío: Enviado o Error.';
                    StyleExpr = ResultStyle;
                }
                field("Error Message"; Rec."Error Message")
                {
                    ApplicationArea = All;
                    ToolTip = 'Mensaje de error en caso de fallo.';
                }
                field("Sent By"; Rec."Sent By")
                {
                    ApplicationArea = All;
                    ToolTip = 'Usuario o proceso que realizó el envío (JOB QUEUE para automático).';
                }
                field("Report ID"; Rec."Report ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'ID del informe utilizado para generar el PDF.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(Print)
            {
                Caption = 'Imprimir';
                ApplicationArea = All;
                Image = Print;
                ToolTip = 'Imprime el registro de envíos aplicando los filtros actuales de la vista.';
                trigger OnAction()
                var
                    LogEntry: Record "GFL Cust. Statement Log";
                    StatReport: Report "GFL Statement Log";
                begin
                    LogEntry.Copy(Rec);
                    LogEntry.SetView(Rec.GetView());
                    StatReport.SetTableView(LogEntry);
                    StatReport.Run();
                end;
            }
        }
    }

    var
        ResultStyle: Text;

    trigger OnAfterGetRecord()
    begin
        if Rec.Result = Rec.Result::Error then
            ResultStyle := 'Unfavorable'
        else
            ResultStyle := 'Favorable';
    end;
}
