codeunit 50302 "GFL Fin. Comm. Install"
{
    // Al instalar por primera vez, marca todos los pagos existentes
    // como "Aviso enviado" para evitar envíos masivos de pagos históricos.

    Subtype = Install;

    trigger OnInstallAppPerCompany()
    var
        VendLedgerEntry: Record "Vendor Ledger Entry";
    begin
        // Solo en primera instalación, no en actualizaciones
        if GetCurrentVersion() > Version.Create(0, 0, 0, 0) then
            exit;

        // Marcar todos los pagos existentes como enviados
        VendLedgerEntry.SetRange("Document Type", VendLedgerEntry."Document Type"::Payment);
        VendLedgerEntry.SetRange("GFL Remittance Sent", false);
        if not VendLedgerEntry.IsEmpty() then
            VendLedgerEntry.ModifyAll("GFL Remittance Sent", true);
    end;

    local procedure GetCurrentVersion(): Version
    var
        AppInfo: ModuleInfo;
    begin
        NavApp.GetCurrentModuleInfo(AppInfo);
        exit(AppInfo.DataVersion());
    end;
}
