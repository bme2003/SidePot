# SidePot

SidePot is a private, trust-based social wagering app for friends.  
It allows small groups to create custom bets, track outcomes transparently, and settle up socially without real money, odds engines, or public gambling mechanics.

SidePot is designed to feel closer to a shared agreement than a sportsbook.  
Money is virtual. Accountability is social.

---

## Core Principles

- **Private by default**  
  All bets live inside invite-only groups.

- **Trust-based money**  
  No payments are processed. Winnings create virtual debts that must be resolved socially.

- **Participation gating**  
  Users with unresolved debts cannot place new pledges or create bets.

- **No house advantage**  
  No rake, no odds modeling, no discovery feeds.

- **Transparency over enforcement**  
  All actions, pledges, and outcomes are visible to the group.

---

## Key Features

### Groups
- Create private groups
- Add members by username
- Invite people from contacts (local-only MVP)
- View group members, ownership, and activity

### Bets
- Custom bet creation with:
  - Title and description
  - Lock date (when pledging closes)
  - Resolve date (when outcome is decided)
  - Resolution rule:
    - Unanimous vote
    - Owner decides
    - Group vote
- Two or more outcomes per bet

### Pledges
- Virtual pledges from $1–$50
- Pot size tracked per outcome
- Pledges close automatically after lock time

### Settlement and Debts
- Bets resolve to a winning outcome
- Winners and losers are calculated proportionally
- Losers incur **virtual debts** to winners
- Debts must be marked resolved by the creditor or group owner
- Users with open debts are blocked from further participation

### Social Layer
- Text-based comments on bets
- Group-level visibility into outcomes and debts
- Personal ledger showing bet history and net results

---

## What SidePot Is Not

- No real money handling
- No public betting or discovery
- No odds calculation or optimization
- No gambling addiction mechanics
- No automated arbitration

SidePot is intentionally constrained to remain social, low-stakes, and private.

---

## Tech Stack

### Client
- Swift
- SwiftUI
- iOS 17+
- MVVM-style architecture

### Data Layer
- Local persistence using JSON
- Mock API abstraction (`MockAPI`)
- Designed for backend replacement later

### System Integrations
- Contacts framework (for invite selection only)
- No network calls in MVP

---

## App Architecture

