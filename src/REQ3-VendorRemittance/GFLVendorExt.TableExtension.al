tableextension 50301 "GFL Vendor Ext" extends Vendor
{
    fields
    {
        field(50300; "GFL Send Remittance"; Boolean)
        {
            Caption = 'Enviar aviso de pago';
            DataClassification = CustomerContent;

            trigger OnValidate()
            var
                VendLedgerEntry: Record "Vendor Ledger Entry";
            begin
                // Al activar el flag, marcar como excluidos todos los pagos anteriores
                // sin aviso enviado, para que el sweep del Job Queue no los procese
                // retroactivamente. GFL Remittance Sent Date queda en 0DT como
                // distinción respecto a un envío real.
                if Rec."GFL Send Remittance" and not xRec."GFL Send Remittance" then begin
                    VendLedgerEntry.SetRange("Vendor No.", Rec."No.");
                    VendLedgerEntry.SetRange("Document Type", VendLedgerEntry."Document Type"::Payment);
                    VendLedgerEntry.SetRange("GFL Remittance Sent", false);
                    if VendLedgerEntry.FindSet(true) then
                        repeat
                            VendLedgerEntry."GFL Remittance Sent" := true;
                            VendLedgerEntry.Modify();
                        until VendLedgerEntry.Next() = 0;
                end;
            end;
        }
    }
}
