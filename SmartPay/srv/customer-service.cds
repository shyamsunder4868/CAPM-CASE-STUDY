using { smartpay as db } from '../db/schema';

@requires: 'authenticated-user'
service CustomerService @(path:'/customer') {

  @requires: ['Buyer','AP_Lead','Admin']
  entity PurchaseOrders as projection on db.POHeader actions {
    action sendToSupplier() returns PurchaseOrders;
  };

  @readonly
  entity POLines as projection on db.POLine;

  @readonly
  entity Invoices as projection on db.InvoiceHeader;

  @readonly
  entity InvoiceLines as projection on db.InvoiceLine;

  @readonly
  entity InvoiceDocuments as projection on db.InvoiceDocument;

  @requires: ['AP_Lead','Buyer','Admin']
  entity InvoiceExceptions as projection on db.InvoiceException actions {
    action approveOverride(justification: String(1000)) returns InvoiceExceptions;
    action requestSupplierCorrection(justification: String(1000)) returns InvoiceExceptions;
    action rejectInvoice(justification: String(1000)) returns InvoiceExceptions;
  };

  @readonly
  entity ExceptionActions as projection on db.ExceptionAction;

  @requires: ['AP_Lead','Admin']
  entity InvoiceReviewQueue as projection on db.InvoiceHeader
    where extractionConfidence < 100
    actions {
      action confirmAndRunValidation() returns InvoiceReviewQueue;
    };

  @readonly
  entity ValidationRuns as projection on db.ValidationRun;

  @readonly
  entity ValidationResults as projection on db.ValidationResult;

  @readonly
  entity AuditHistory as projection on db.AuditEvent order by performedAt desc;

  @readonly
  entity Suppliers as projection on db.SupplierMaster;

  @readonly
  entity SESHeaders as projection on db.SESHeader;
}

@requires: 'Admin'
service AdminService @(path:'/admin') {

  entity ValidationRules as projection on db.ValidationRule actions {
    action publish() returns ValidationRules;
  };

  @readonly
  entity IntegrationEvents as projection on db.IntegrationEvent order by occurredAt desc;

  @readonly
  entity ValidationRunsAdmin as projection on db.ValidationRun;

  @readonly
  entity Companies as projection on db.CompanyMaster;
}