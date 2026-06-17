tableextension 50302 "GFL Customer Ext" extends Customer
{
    fields
    {
        field(50300; "GFL Last Statement Sent Date"; Date)
        {
            Caption = 'Fecha último extracto enviado';
            DataClassification = CustomerContent;
        }
    }
}
