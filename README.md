**PLAY IT FORWARD**
*A Public Arcade Machine for Charitable Fundraising*


**Created By:** Neo Maxwell Tartan  

**Started:** August 2026  


Play It Forward is a student-led engineering initiative that turns casual arcade gameplay into gamified micro-donations for underserved communities in East Nusa Tenggara (NTT). Installed in high-traffic public venues like shopping malls, the arcade cabinet lets passersby play custom games by making small charitable contributions via dynamic QRIS payments.

Instead of traditional cash-handling mechanisms, the machine leverages real-time digital payment APIs and edge computing to verify donations instantly, launching gameplay sessions upon transaction confirmation.


**Project Originality**
The concept originated during a trip to Japan, where I observed an emulated retro arcade machine inside an MRT station designed to collect public donations for charity. Recognizing the massive potential of gamified crowdfunding in densely populated public spaces, I sought to re-engineer this concept for Indonesia using local digital payment systems (QRIS).

The gameplay design, storyline, and aesthetic are entirely original, inspired by the mechanics of Google’s *Doodle Champion Island Games* to blend short, accessible athletic mini-games with dynamic scoring systems. System architecture and game design were directed by the author, with Claude Code utilized as an AI assistant for boilerplate implementation and engineering troubleshooting.

**System Architecture**
* **Game Engine:** Custom 2D game built in Godot Engine using GDScript.
* **Hardware & IO:** Custom-mapped arcade controls bridged via a microcontroller to an onboard single-board computer (SBC).
* **Payment Pipeline:** Real-time webhooks connecting Godot's HTTP nodes directly to a dynamic QRIS API gateway for seamless transaction processing.


**Credits**
1. **Family:** For supporting the initial hardware concept and inspiring the journey to build technology for social good.
2. **Friends:** For being a constant source of inspiration, and for introducing me to *Doodle Champion Island Games*, a key aesthetic reference.
