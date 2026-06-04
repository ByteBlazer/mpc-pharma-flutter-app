# Delivery Report — requirements (React parity + Flutter performance)

## Behavior (from old ui)

- Filters: dates (both or neither, max 30 days), doc ID, dropdowns via `WebPortalFilterDropdown` (single + multi city), route, trip ID, etc.
- Search applies filters; Clear resets filters and results.
- Loading spinner only while fetching/parsing — not while painting rows.
- Results header: record count, optional 30-day note, Download Excel (.xlsx, browser download).
- Table: **all rows at once** in a scroll container (`max-height: viewport - 475px`), not virtualized.
- Columns: Doc ID, Doc Date, Customer (+ address), City, Status (+ View Signature / View Comment), Comment, Trip ID, Route, Trip Creator, Driver, Vehicle, Origin Warehouse.
- Status `UNDELIVERED` displays as **DELIVERY FAILED**.
- Signature and comment modals on demand.

## Flutter implementation

| Concern               | Approach                                                               |
| --------------------- | ---------------------------------------------------------------------- |
| Filter UI rebuilds    | Local `StatefulWidget`; never watches report state                     |
| API + JSON parse      | `DeliveryReportController.search()` + `compute()` isolate              |
| Table (web)           | HTML `<table>` via `HtmlElementView` (DOM, like React)                 |
| Table (non-web)       | Simple list fallback                                                   |
| Loading state         | Ends when isolate returns; DOM paint is separate                       |
| Date filters (web)    | Native `<input type="date">` + `showPicker()` via `WebPortalDateField` |
| Date filters (mobile) | Material `showDatePicker` fallback                                     |
