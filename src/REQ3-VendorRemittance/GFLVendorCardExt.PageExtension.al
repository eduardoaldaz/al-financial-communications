pageextension 50301 "GFL Vendor Card Ext" extends "Vendor Card"
{
    layout
    {
        addafter(Blocked)
        {
            field("GFL Send Remittance"; Rec."GFL Send Remittance")
            {
                ApplicationArea = All;
                Caption = 'Enviar aviso de pago';
                ToolTip = 'Activa el envío automático del aviso de pago al registrar pagos para este proveedor.';
            }
        }
    }
}
