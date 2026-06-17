tableextension 50300 "GFL Vendor Ledger Entry Ext" extends "Vendor Ledger Entry"
{
    fields
    {
        field(50300; "GFL Remittance Sent"; Boolean)
        {
            Caption = 'Aviso de pago enviado';
            DataClassification = CustomerContent;
            Editable = false;
        }
        field(50301; "GFL Remittance Sent Date"; DateTime)
        {
            Caption = 'Fecha envío aviso de pago';
            DataClassification = CustomerContent;
            Editable = false;
        }
    }
}
