using { smartpay as db } from '../db/schema';

@requires: 'Supplier'
service SupplierService @(path:'/supplier') {

  @readonly
  entity MyPurchaseOrders as projection on db.POHeader;

  @readonly
  entity MyPOLines as projection on db.POLine;

  entity MyInvoices as projection on db.InvoiceHeader actions {
    action submitInvoice() returns MyInvoices;
    action resubmitInvoice(justification: String(1000)) returns MyInvoices;
  };

  entity MyInvoiceLines as projection on db.InvoiceLine;

  entity MyInvoiceDocuments as projection on db.InvoiceDocument;
}