---

### **Functional Requirements Document (FRD): Bstock**

*   **Document Version:** 1.0
*   **Project Title:** Bstock - Functional Requirements
*   **Date:** November 5, 2025
*   **Reference:** Master Project Brief v1.0

#### **1.0 User & Account Management (FUN-100)**

*   **FUN-101: Organization Registration**
    *   **101.1:** The system shall allow a new user to register a new Organization by providing a unique Organization Name, their primary phone number, and a password.
    *   **101.2:** The user who creates the Organization shall be automatically assigned the 'Owner' role for that Organization.
    *   **101.3:** Organization names must be unique within the system to act as an identifier for login.

*   **FUN-102: User Login**
    *   **102.1:** The system shall provide a login interface where a user can enter their Organization Name, their phone number, and their password to authenticate.
    *   **102.2:** Upon successful authentication, the system shall direct the user to the appropriate interface based on their assigned role ('Owner' or 'Cashier').

*   **FUN-103: User Management (Owner Role Only)**
    *   **103.1:** The system shall allow an 'Owner' to invite new users to their Organization by providing a phone number.
    *   **103.2:** The 'Owner' must assign a role ('Owner' or 'Cashier') to the invited user.
    *   **103.3:** The 'Owner' shall be able to view a list of all users within their Organization.
    *   **103.4:** The 'Owner' shall be able to remove users from their Organization.

*   **FUN-104: Onboarding**
    *   **104.1:** Upon the first successful login after registration, the system must launch a mandatory, interactive onboarding wizard.
    *   **104.2:** This wizard must guide the user through the process of adding their first product.

#### **2.0 Subscription & Billing (FUN-200)**

*   **FUN-201: Plan Selection**
    *   **201.1:** After completing the onboarding wizard, the user must be presented with a screen displaying the available subscription plans (Free, Growth, Pro).
    *   **201.2:** The screen must clearly display the features and resource limits (product count, user count) associated with each plan.

*   **FUN-202: Plan Enforcement**
    *   **202.1:** The system must strictly enforce the resource limits of the user's current subscription plan.
    *   **202.2:** If a user attempts to perform an action that exceeds their plan's limits (e.g., adding a 16th product on the Free plan), the system must prevent the action and display an informative message prompting them to upgrade.
    *   **202.3:** The system must gate access to features based on the plan. Users on the Free plan must not be able to access the Analytics section.

*   **FUN-203: Payment (Stubbed for Development)**
    *   **203.1:** The system shall include a UI for processing payments.
    *   **203.2:** For development and testing purposes, this payment flow shall be stubbed. A developer-accessible option (e.g., a debug menu, a seed script) must exist to assign any plan to any organization without requiring actual payment.

#### **3.0 Inventory Management (FUN-300)**

*   **FUN-301: Product Creation & Management**
    *   **301.1:** The system shall allow users with the 'Owner' role to create, view, update, and delete products.
    *   **301.2:** A product must have at a minimum: a Name, a primary Sale Price, and a stock Quantity.
    *   **301.3:** The product creation form must provide optional fields for: Product Image, Category, and Vendor.
    *   **301.4:** The system shall support the concept of **Variants**. Users must be able to define options (e.g., "Size," "Color") and values for those options (e.g., "Small," "Medium," "Red," "Blue").
    *   **301.5:** Each unique combination of variants for a product must be treated as a distinct, trackable item with its own SKU, Sale Price, Purchase Price, and Quantity.
    *   **301.6:** The system shall support defining a unit of measurement for each product/variant (e.g., pcs, kg, L, pack).

*   **FUN-302: Stock Control**
    *   **302.1:** The system shall allow an 'Owner' to manually adjust the stock quantity of any variant to account for new deliveries, recounts, or damages.
    *   **302.2:** The system must automatically decrement the stock quantity of a variant when it is sold via the POS.
    *   **302.3:** The system shall allow an 'Owner' to define a minimum stock level ("reorder point") for each variant.
    *   **302.4:** The system should generate a notification (visible within the app) when a variant's quantity drops below its defined minimum stock level.

*   **FUN-303: Supplier (Vendor) Management**
    *   **303.1:** The system shall provide a simple directory for 'Owners' to save, view, and manage information about their suppliers (Name, Contact Info).

#### **4.0 Point of Sale (POS) (FUN-400)**

*   **FUN-401: Interface & Cart Management**
    *   **401.1:** The POS interface must be accessible to both 'Owner' and 'Cashier' roles.
    *   **401.2:** The interface shall display sellable products/variants in a clear, touch-friendly grid or list format.
    *   **401.3:** The system must provide a search function to quickly find products by name or SKU.
    *   **401.4:** The system shall allow the user to use the device's camera to scan a product's barcode to add it to the sales cart instantly.
    *   **401.5:** Users must be able to easily adjust the quantity of items in the cart and remove items from the cart.

*   **FUN-402: Checkout & Payment**
    *   **402.1:** The system shall calculate the total amount for all items in the cart.
    *   **402.2:** The user must be able to select from a predefined list of payment methods (e.g., "Cash," "Mobile Money," "Bank Transfer").
    *   **402.3:** When a digital payment method is selected, the system must provide an optional feature to capture a photo from the camera or gallery as proof of payment. This photo must be associated with the sale record.

*   **FUN-403: Receipt Generation**
    *   **403.1:** Upon successful completion of a sale, the system must generate a record of the transaction.
    *   **403.2:** The system must provide a "Share Receipt" option.
    *   **403.3:** This option shall generate a simple, clean PDF receipt of the transaction and open the device's native Share Sheet to allow the user to send or save it.

*   **FUN-404: Offline Mode**
    *   **404.1:** The system must be able to perform all core sales functions (adding items to cart, completing a sale) without an active internet connection.
    *   **404.2:** Sales completed offline must be securely stored on the local device.
    *   **404.3:** The local inventory count must be updated immediately after an offline sale.
    *   **404.4:** The system must automatically synchronize any pending offline sales with the server once an internet connection is re-established.

#### **5.0 Analytics & Reporting (FUN-500)**

*   **FUN-501: Sales Dashboard (Owner Role, Non-Free Plans Only)**
    *   **501.1:** The system shall provide a dashboard that displays key business metrics.
    *   **501.2:** Users must be able to filter the dashboard data by a date range (e.g., Today, Last 7 Days, Last Month, Custom).
    *   **501.3:** The dashboard must display at a minimum: Total Revenue, Total Cost of Goods Sold, and Gross Profit for the selected period.

*   **FUN-502: Product Performance Report (Owner Role, Non-Free Plans Only)**
    *   **502.1:** The system shall provide a report that ranks products/variants based on their sales performance within a selected date range.
    *   **502.2:** The report must be sortable by "Top Selling" (by quantity) and "Most Profitable" (by total profit generated).