tableextension 50301 "GFL Vendor Ext" extends Vendor
{
    fields
    {
        field(50300; "GFL Send Remittance"; Boolean)
        {
            Caption = 'Enviar aviso de pago';
            DataClassification = CustomerContent;
        }
    }
}
