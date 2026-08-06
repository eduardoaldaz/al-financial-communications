pageextension 50302 "GFL Customer Card Ext" extends "Customer Card"
{
    actions
    {
        addlast(processing)
        {
            group(GFLCustomerStatements)
            {
                Caption = 'Extracto GFL';
                Image = Report;

                action(GFLSendOverdueStatement)
                {
                    ApplicationArea = All;
                    Caption = 'Enviar extracto';
                    ToolTip = 'Envía el extracto de deuda pendiente por correo al cliente y lo registra en el histórico de envíos.';
                    Image = SendEmailPDF;
                    Promoted = true;
                    PromotedCategory = Report;
                    PromotedIsBig = true;

                    trigger OnAction()
                    var
                        Notifier: Codeunit "GFL Cust. Overdue Notifier";
                    begin
                        Notifier.SendOverdueStatementManual(Rec);
                        CurrPage.Update(false);
                    end;
                }
                action(GFLPreviewOverdueStatement)
                {
                    ApplicationArea = All;
                    Caption = 'Vista previa extracto';
                    ToolTip = 'Genera una vista previa del extracto de deuda pendiente que recibiría este cliente, sin enviar ningún email.';
                    Image = PrintReport;
                    Promoted = true;
                    PromotedCategory = Report;

                    trigger OnAction()
                    var
                        Notifier: Codeunit "GFL Cust. Overdue Notifier";
                    begin
                        Notifier.PreviewOverdueStatement(Rec);
                    end;
                }
            }
        }
    }
}
