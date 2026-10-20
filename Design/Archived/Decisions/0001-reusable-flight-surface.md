# ADR-0001: Reusable flight surface

Free Flight and future Mission flight screens use one reusable baseline flight surface and each owns a per-flight session object. This costs a focused extraction now, but prevents mission-only route-planning and rules from becoming conditional behavior throughout the common cockpit; keeping one all-purpose screen was rejected for that reason.
