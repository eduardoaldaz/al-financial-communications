permissionset 50300 "GFL Fin. Comm. - All"
{
    Assignable = true;
    Caption = 'GFL Financial Communications';
    Permissions =
        tabledata "GFL Fin. Comm. Setup" = RIMD,
        tabledata "GFL Cust. Statement Log" = RIMD,
        codeunit "GFL Cust. Overdue Notifier" = X,
        codeunit "GFL Vendor Remittance Sender" = X,
        codeunit "GFL Fin. Comm. Install" = X,
        page "GFL Fin. Comm. Setup" = X,
        page "GFL Cust. Statement Log" = X;
}
