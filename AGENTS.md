# Working rules

- Never have more than one Simulator device open or booted at once. This is an explicit user constraint, reiterated on 2026-09-06.
- Reuse the existing AgePad G5 iPad Simulator (`574671AD-6F61-4558-9528-BF946DDB760A`). Do not boot a separate engineering Simulator while it is running.
- Check the actual booted-device inventory before Simulator work. Keep the visible installed game aligned with the current demonstrated candidate; clearly state when an app update restarts an unsaved scenario.
- Validate UI changes with actual Simulator screenshots and classic/HD reference images. Custom controls should use the game’s visual style; the user explicitly rejected the flat dark control buttons.
