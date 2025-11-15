---



\### \*\*Master Project Brief: Bstock\*\*



\*   \*\*Document Version:\*\* 1.0

\*   \*\*Project Title:\*\* Bstock - The Small Business Operating System

\*   \*\*Date:\*\* November 5, 2025



\#### \*\*1.0 Executive Summary \& Vision\*\*



\*\*1.1 Vision Statement:\*\* To become the central nervous system for small and medium-sized retail businesses in Ethiopia and beyond, by providing a powerful, integrated, and radically simple platform for managing sales, inventory, and business growth.



\*\*1.2 The Problem:\*\* Small business owners are often forced to rely on a disjointed set of tools: manual notebooks for inventory, calculators for sales, separate banking apps for payments, and guesswork for business analysis. Existing digital solutions are often too complex, too expensive, or not designed for their specific market needs, leading to inefficiency, lost sales, and missed growth opportunities.



\*\*1.3 The Solution (Bstock):\*\* Bstock is a mobile-first, cloud-based platform that unifies a Point of Sale (POS), a smart Inventory Management System, and essential Business Analytics into one cohesive and intuitive application. Our non-negotiable competitive advantage is our relentless focus on simplicity, making powerful technology accessible to entrepreneurs of any digital literacy level.



---



\#### \*\*2.0 Core Pillars (Guiding Principles)\*\*



Every feature, design choice, and technical decision must be in service of these four pillars:



1\.  \*\*Simplicity as the Ultimate Feature:\*\* The platform must be intuitive from the first tap. Complexity will be handled by the system, not pushed onto the user. If a feature is powerful but difficult to use, it is a failure.

2\.  \*\*Robust Multi-Tenancy \& Security:\*\* The architecture must be built from the ground up to securely and efficiently serve thousands of independent businesses, with ironclad data isolation between them.

3\.  \*\*Integrated Subscription \& Monetization:\*\* Bstock is a commercial product. The architecture for plans, payments, and feature-gating is a core, non-negotiable part of the system from day one, enabling the business to scale.

4\.  \*\*Resilience \& Reliability (Offline First):\*\* The platform must be a dependable partner, even with unstable internet. The POS must function and securely record sales while offline, syncing automatically when a connection is restored.



---



\#### \*\*3.0 Target Audience (User Personas)\*\*



\*   \*\*Persona 1: Selam, The Boutique Owner ("Growth" / "Pro" Tier)\*\*

&nbsp;   \*   \*\*Background:\*\* Owns a small but established clothing boutique. Manages a small team of 1-2 cashiers.

&nbsp;   \*   \*\*Goals:\*\* Increase profitability, understand which items sell best to make smarter purchasing decisions, and reduce time spent on manual inventory counts.

&nbsp;   \*   \*\*Pain Points:\*\* Doesn't know her exact profit margin, loses sales when popular sizes run out unexpectedly, and finds it difficult to delegate sales tasks without losing oversight.

&nbsp;   \*   \*\*Bstock's Value:\*\* The Analytics Dashboard gives her the insights she needs. Role-based user accounts allow her to empower her staff securely. Low-stock alerts prevent stock-outs.



\*   \*\*Persona 2: Daniel, The Kiosk Operator ("Free" / "Growth" Tier)\*\*

&nbsp;   \*   \*\*Background:\*\* Runs a busy kiosk selling drinks, snacks, and mobile cards. He is the sole operator.

&nbsp;   \*   \*\*Goals:\*\* Speed up the checkout process, eliminate calculation errors, and know exactly what he needs to re-stock at the end of the day.

&nbsp;   \*   \*\*Pain Points:\*\* Loses money due to miscalculations, customers get frustrated by long waits, and he sometimes runs out of popular items during peak hours.

&nbsp;   \*   \*\*Bstock's Value:\*\* The "One-Thumb Checkout" POS is fast and accurate. The simple inventory list and low-stock alerts tell him exactly what to buy.



---



\#### \*\*4.0 Monetization Strategy (Subscription Tiers)\*\*



Bstock will operate on a freemium model designed to allow users to experience the core value proposition for free, and upgrade as their business grows.



| Plan Name | Target User | Key Limits | Key Features |

| :--- | :--- | :--- | :--- |

| \*\*Bstock Free\*\* | New / Micro Businesses | • 15 Active Products<br>• 2 Users<br>• 1 Business Location | • Core POS \& Inventory<br>• \*\*Analytics Disabled\*\* |

| \*\*Bstock Growth\*\* | Small, Growing Businesses | • 500 Active Products<br>• 10 Users<br>• 3 Business Locations | • Full POS \& Inventory<br>• \*\*Full Analytics Enabled\*\* |

| \*\*Bstock Pro\*\* | Established Businesses | • Unlimited Products<br>• Unlimited Users<br>• Unlimited Locations | • All Features<br>• Priority Support |



---



\#### \*\*5.0 Scope of Features (High-Level Functional Areas)\*\*



This section outlines the major capabilities of the Bstock platform.



\*   \*\*5.1 Onboarding \& Account Management:\*\*

&nbsp;   \*   Organization-based registration and login flow.

&nbsp;   \*   Interactive onboarding wizard for new organizations.

&nbsp;   \*   Multi-user management with distinct roles (Owner, Cashier).



\*   \*\*5.2 Subscription \& Billing Management:\*\*

&nbsp;   \*   Clear plan selection screen.

&nbsp;   \*   Stubbed payment integration module for development and testing.

&nbsp;   \*   Backend logic to enforce plan-based feature gates and resource limits.



\*   \*\*5.3 Inventory Management:\*\*

&nbsp;   \*   Product creation with support for variants (e.g., size, color), units (e.g., pcs, kg), and images.

&nbsp;   \*   Tracking of both Purchase Price and Sale Price for profit calculation.

&nbsp;   \*   Simple stock adjustment tools (additions, recounts).

&nbsp;   \*   Low-stock level definitions and automated alerts.

&nbsp;   \*   Vendor information management.



\*   \*\*5.4 Point of Sale (POS):\*\*

&nbsp;   \*   Intuitive, grid-based interface for adding items to a cart.

&nbsp;   \*   Integrated barcode scanning via the device camera.

&nbsp;   \*   Processing of sales with multiple payment types (Cash, Mobile Money, etc.).

&nbsp;   \*   Ability to attach a photo as proof of digital payment.

&nbsp;   \*   Generation of a PDF receipt with a native "Share" option.

&nbsp;   \*   Full offline sales capability with automatic background synchronization.



\*   \*\*5.5 Analytics \& Reporting (Feature-Gated):\*\*

&nbsp;   \*   Dashboard displaying key metrics (Revenue, Profit) for selectable date ranges.

&nbsp;   \*   Reports on best-selling products by quantity and profitability.



\*   \*\*5.6 CI/CD \& Deployment:\*\*

&nbsp;   \*   The entire system will be containerized using Docker.

&nbsp;   \*   A complete CI/CD pipeline will be established using GitHub Actions, targeting a self-hosted runner for automated builds and deployments.

