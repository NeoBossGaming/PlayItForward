**PLAY IT FORWARD**

A Public Arcade Machine for Charitable Fundraising

Created By By: Neo Maxwell Tartan

Started on: August 2026

A standalone arcade cabinet houses a small computer running one or more games, a control panel (joystick and buttons), a QRIS-based cashless payment flow, and a logging layer that records how much has been collected. A partner venue (e.g., a shopping mall or school event) hosts the cabinet under an agreement, and funds are periodically withdrawn and donated, with amounts reported publicly for transparency.

**Technical Planning**


**System Overview**
The machine can be thought of as four subsystems that need to work together:
Cabinet/frame: the physical wooden housing, control panel, and mounting for all electronics.
The cabinet will be using a wooden plywood housing, and manufacturing will be performed with the help of a local carpenter. 3D model will be sent to the carpenter and will be made.

Compute: the device that actually runs the game and drives the screen.
All games and computation will be run on a Raspberry Pi 4/5. To ensure compatibility, the game will be built on Godot, as it is a lightweight engine.

Payment & logging: software for payment through QRIS and automatically logs payment.
Paid not through physical currency such as cash or coins, but rather through QRIS with the help of an API such as Midtrans.


**Timeline**
Phase 1: Prove the software works (3 months, September 2026 - December 2026)
Build one representative minigame in Godot, running on a normal laptop or desktop.
Build the Idle, Payment Wait, Gameplay, Results state machine (2.4.1, 2.4.3), with the payment step mocked out for now.
Done when: the full loop plays start to finish on ordinary hardware and feels good, without needing real money to test it.

Phase 2: Prove the payment integration works (2 months, January 2027 - March 2027) 
Register an individual Midtrans account with a KTP and get sandbox access.
Build a small standalone script or app that creates a dynamic QRIS charge, shows the QR, and polls status until paid (2.4.2), kept separate from the game for now.
Test it with a few real, small transactions.
Done when: you can generate a QR, pay it with own phone, and reliably see the status flip to paid within a few seconds.

Phase 3: Merge software and payment on the real hardware (2 months, April 2027 - May 2027)
Buy the Pi 4/5 (2.3).
Wire the payment flow from Phase 2 into the state machine from Phase 1, replacing the mocked step.
Add the arcade controls (USB encoder, joystick, buttons).
Done when: the full loop, idle, pay with a real QR, play with real controls, results, runs sitting on a table, no cabinet yet.

Phase 4: Build the cabinet (1.5 months, June 2027 - July 2027)
Finalize dimensions around the chosen screen and the parts from Phase 3 (2.2).
Work with a carpenter on the frame, including the access panel and ventilation.
Mount and wire everything inside once the frame is ready.
Done when: the same working loop from Phase 3 runs inside the finished cabinet, powered from a single outlet.

Phase 5: Pilot deployment (2 months, August 2027 - September 2027)
Pick one venue for a trial run, ideally one you can check on often.
Agree with the venue and the chosen cause on how funds are split, handled, and reported.
Watch it under real public use and fix whatever people find that testing did not.
Done when: it has run for a couple of weeks of real public use without needing constant intervention.

Phase 6: Formalize and consider scaling (1 month, October 2027)
Set up the recurring public report, pulling from the payment gateway's ledger.
Decide whether to keep it at one venue or add a second, and what should change the second time around.
Done when: a donation report has actually been published at least once, and the scaling decision has been made deliberately rather than by default.
