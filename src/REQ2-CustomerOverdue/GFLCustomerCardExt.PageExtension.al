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

                action(GFLPreviewOverdueStatement)
                {
                    ApplicationArea = All;
                    Caption = 'Vista previa extracto';
                    ToolTip = 'Genera una vista previa del extracto de deuda pendiente que recibiría este cliente, sin enviar ningún email.';
                    Image = PrintReport;
                    Promoted = true;
                    PromotedCategory = Report;
                    PromotedIsBig = true;

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
