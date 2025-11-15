---

### **UI/UX Guidelines & Simplicity Manifesto: Bstock**

*   **Document Version:** 1.0
*   **Project Title:** Bstock - Design & User Experience
*   **Date:** November 5, 2025
*   **Reference:** Master Project Brief v1.0, Functional Requirements Document v1.0

#### **1.0 Core Philosophy: The Simplicity Manifesto**

This manifesto is the unbreakable foundation of our design. If a design choice conflicts with these principles, the choice is wrong.

*   **Clarity Over Cleverness:** The interface must be immediately understandable. We will use standard patterns and explicit labels over clever but ambiguous icons or novel interactions. A new user should never have to guess what a button does.
*   **Fewer Taps are Better Taps:** Every tap is a point of friction. Workflows for common tasks, especially making a sale, must be optimized to require the absolute minimum number of interactions.
*   **Guide, Don't Assume:** The app should guide the user through complex processes (like setup or adding a first product) step-by-step. We will use helper text, clear instructions, and a gentle onboarding process to build user confidence.
*   **Consistency is Key:** A button, a color, or a layout pattern should mean the same thing on every screen. This predictability makes the app feel reliable and easy to master.
*   **Progressive Disclosure:** Show only what's necessary. Advanced features and optional details should be gracefully hidden behind clear "More Options" or "Add Details" toggles. Protect the user from information overload.

---

#### **2.0 Universal Design Principles (The "Look")**

These are the global styles that define the application's visual identity.

*   **2.1 Color Palette:** The palette will be simple, clean, and high-contrast.
    *   **Primary Action:** `#007AFF` (A clear, accessible blue) - Used for primary buttons ("Charge," "Save"), active tabs, and key interactive elements.
    *   **Success:** `#34C759` (A friendly green) - Used for confirmation messages, success indicators.
    *   **Error/Destructive:** `#FF3B30` (A clear red) - Used for error messages, delete buttons, and warnings.
    *   **Neutrals:**
        *   `#FFFFFF` (White) - Primary background color.
        *   `#F2F2F7` (Light Gray) - Secondary backgrounds, cards.
        *   `#8A8A8E` (Medium Gray) - Sub-text, helper text.
        *   `#1C1C1E` (Near Black) - Main body text.

*   **2.2 Typography:** We will use one highly legible, sans-serif font family across the entire application.
    *   **Font Family:** Roboto (or platform equivalent like San Francisco for iOS).
    *   **Hierarchy:**
        *   **Screen Title:** 24sp, Bold
        *   **Card/Section Title:** 18sp, Medium
        *   **Body Text / Input Field:** 16sp, Regular
        *   **Button Text:** 16sp, Medium
        *   **Helper/Caption Text:** 14sp, Regular

*   **2.3 Layout & Spacing:** All layouts will be built on an 8dp grid system to ensure consistent spacing and rhythm.
    *   **Standard Padding:** 16dp inside all screen edges and containers.
    *   **Gaps between elements:** 8dp, 16dp, or 24dp.
    *   **White Space:** Layouts must be uncluttered. Generous use of white space is mandatory to improve readability and reduce cognitive load.

*   **2.4 Iconography:** Icons must always be accompanied by a text label.
    *   **Icon Set:** Material Symbols (Outlined style) for consistency.
    *   **Usage:** An icon's purpose is to reinforce the meaning of the text label, not to replace it.

---

#### **3.0 Component-Specific Guidelines (The "Feel")**

These rules define the behavior of our core interactive elements.

*   **3.1 Buttons:**
    *   **Primary Button:** Solid fill with the Primary Action color. Used for the single most important action on a screen (e.g., "Save," "Charge").
    *   **Secondary Button:** Outlined with the Primary Action color, transparent fill. Used for less important, non-destructive actions.
    *   **Destructive Button:** Solid fill with the Error/Destructive color (e.g., "Delete"). Must always trigger a confirmation dialog.
    *   **Touch Targets:** All buttons and interactive elements must have a minimum touch target size of 48x48dp.

*   **3.2 Input Fields:**
    *   **Label:** Must have a clear, persistent label that sits above the input area. Do not rely on placeholder text, which disappears on focus.
    *   **State:** Must have visually distinct states for default, focused, and error.
    *   **Feedback:** Helper text should appear below the field to provide guidance. Error messages should appear below the field in the Error color.

*   **3.3 Dialogs & Modals:**
    *   **Usage:** Use sparingly, only for critical confirmations (e.g., "Are you sure you want to delete this product?") or to block the UI for a crucial choice.
    *   **Structure:** Must contain a clear Title, a short descriptive message, and no more than two simple action buttons (e.g., "Confirm" and "Cancel").

---

#### **4.0 Key Screen Blueprints**

This section applies the principles to the most critical screens.

*   **4.1 Login / Registration:**
    *   **Initial Screen:** A single, centered text input field with the label "Shop Name" and a large "Continue" button below it.
    *   **Logic:** The system checks if the shop exists. If yes, it proceeds to the password screen. If no, it proceeds to the registration flow. This single entry point simplifies the user's first decision.

*   **4.2 The POS Screen (The Most Important Screen):**
    *   **Layout:** A two-panel layout. The main area (left/top) is a scrollable, visual grid of product cards. A sidebar (right/bottom) shows the current cart summary.
    *   **Product Cards:** Large, tappable cards showing the product image, name, and price. Tapping a card adds it to the cart with a quantity of 1.
    *   **Cart Summary:** An itemized list with simple "+" and "-" steppers to adjust quantity. The total is displayed prominently at the bottom.
    *   **Primary Action:** A full-width, unmissable "Charge" button is anchored to the bottom of the screen at all times.

*   **4.3 The Add Product Screen (Progressive Disclosure in Action):**
    *   **Initial View:** The screen presents only the most essential fields:
        1.  Product Name (Input)
        2.  Sale Price (Input)
        3.  Quantity in Stock (Input)
        4.  "Save Product" (Primary Button)
    *   **Advanced Options:** Below these fields, there is a clear, secondary button or link titled "+ Add More Details (Size, Cost, etc.)".
    *   **Expanded View:** Tapping this link reveals the advanced fields: Product Image, Variants, Purchase Price, Vendor, Minimum Stock Level, etc., without cluttering the initial, simple workflow.

---

#### **5.0 Accessibility & Language**

*   **5.1 Language:** All text strings (UI labels, messages, etc.) must be externalized from the code base into language files to allow for easy translation. The default language should be Amharic or the most appropriate local language.
*   **5.2 Accessibility:**
    *   **Contrast:** All text and icon colors must meet WCAG AA contrast ratios against their backgrounds.
    *   **Labels:** All interactive elements must have proper content labels for screen reader support.