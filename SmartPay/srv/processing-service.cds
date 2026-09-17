using { smartpay as db } from '../db/schema';

@requires: 'system-service'
@protocol: 'rest'
service ProcessingService @(path:'/processing') {

  action pollMailbox() returns { messagesFound: Integer; documentsQueued: Integer; };
  action runExtraction(documentId: UUID) returns db.InvoiceHeader;
  action runValidation(invoiceId: UUID) returns db.ValidationRun;
  action postToLedgerOrErp(invoiceId: UUID) returns { posted: Boolean; integrationEventId: UUID; };

  @readonly
  entity PendingExtractions as projection on db.InvoiceDocument
    where rawExtractionJson = null;

  @readonly
  entity ReadyToPayQueue as projection on db.InvoiceHeader
    where readyToPayFlag = true and processingStatus <> 'PAID';
}