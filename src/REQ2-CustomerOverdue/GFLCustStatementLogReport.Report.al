report 50300 "GFL Statement Log"
{
    Caption = 'Registro envíos extracto clientes';
    DefaultRenderingLayout = RDLCLayout;
    ApplicationArea = All;
    UsageCategory = ReportsAndAnalysis;

    dataset
    {
        dataitem(LogEntry; "GFL Cust. Statement Log")
        {
            RequestFilterFields = "Notification Date", "Customer No.", "Result";

            column(CustomerNo; "Customer No.") { }
            column(CustomerName; "Customer Name") { }
            column(NotificationDate; "Notification Date") { }
            column(NotificationTime; "Notification Time") { }
            column(EmailTo; "Email To") { }
            column(OverdueAmount; "Overdue Amount") { }
            column(NoOfDocuments; "No. of Documents") { }
            column(Result; Format(Result)) { }
            column(ErrorMessage; "Error Message") { }
            column(SentBy; "Sent By") { }
            column(ReportID; "Report ID") { }
            column(CompanyName; CompanyName()) { }
        }
    }

    rendering
    {
        layout(RDLCLayout)
        {
            Type = RDLC;
            LayoutFile = 'report/GFLCustStatementLog.rdlc';
        }
    }
}
