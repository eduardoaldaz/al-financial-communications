pageextension 50300 "GFL Vendor Ledger Entries Ext" extends "Vendor Ledger Entries"
{
    layout
    {
        addafter("Remaining Amount")
        {
            field("GFL Remittance Sent"; Rec."GFL Remittance Sent")
            {
                ApplicationArea = All;
                Caption = 'Aviso enviado';
                ToolTip = 'Indica si el aviso de pago ha sido enviado al proveedor.';
                Editable = false;
            }
            field("GFL Remittance Sent Date"; Rec."GFL Remittance Sent Date")
            {
                ApplicationArea = All;
                Caption = 'Fecha envío aviso';
                ToolTip = 'Fecha y hora en que se envió el aviso de pago.';
                Editable = false;
                Visible = false;
            }
        }
    }

    actions
    {
        addafter("&Navigate")
        {
            group(GFLRemittanceGroup)
            {
                Caption = 'Aviso de Pago';
                Image = SendEmailPDF;

                action(GFLSendRemittanceAdvice)
                {
                    ApplicationArea = All;
                    Caption = 'Enviar aviso de pago';
                    ToolTip = 'Genera y envía el aviso de pago al proveedor con el detalle de las facturas liquidadas.';
                    Image = SendEmailPDF;
                    Promoted = true;
                    PromotedCategory = Process;
                    PromotedIsBig = true;

                    trigger OnAction()
                    var
                        RemittanceSender: Codeunit "GFL Vendor Remittance Sender";
                    begin
                        RemittanceSender.SendRemittanceManual(Rec);
                        CurrPage.Update(false);
                    end;
                }
                action(GFLPreviewRemittanceAdvice)
                {
                    ApplicationArea = All;
                    Caption = 'Vista previa aviso de pago';
                    ToolTip = 'Genera una vista previa del aviso de pago sin enviarlo.';
                    Image = Report;
                    Promoted = true;
                    PromotedCategory = Process;

                    trigger OnAction()
                    var
                        RemittanceSender: Codeunit "GFL Vendor Remittance Sender";
                    begin
                        RemittanceSender.PreviewRemittance(Rec);
                    end;
                }
            }
        }
    }
}
