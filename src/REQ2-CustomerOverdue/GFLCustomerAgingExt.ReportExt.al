reportextension 50300 "GFL Customer Aging Ext." extends "Customer Detailed Aging"
{
    dataset
    {
        add("Cust. Ledger Entry")
        {
            column(GFLDocumentType; "Document Type")
            {
            }
            column(YourReference; "Your Reference")
            {
            }
        }
        modify("Cust. Ledger Entry")
        {
            trigger OnBeforeAfterGetRecord()
            begin
                if not ("Document Type" in ["Document Type"::Invoice, "Document Type"::"Credit Memo"]) then
                    CurrReport.Skip();
            end;
        }
    }
}
