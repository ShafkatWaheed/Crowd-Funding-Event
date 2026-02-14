/// Static Terms and Conditions text for organizers and customers.
/// These are platform-wide legal terms displayed during signup and
/// accessible from the user's profile.
class TermsContent {
  TermsContent._();

  static const String lastUpdated = 'February 2026';

  static const String organizerTerms = '''
CROWDFUND EVENTS — ORGANIZER TERMS AND CONDITIONS

Last updated: February 2026

By creating an account as an Event Organizer on CrowdFund Events ("the Platform"), you agree to the following terms and conditions. Please read them carefully.

1. PLATFORM FEES AND COMMISSIONS

1.1 Ticket Commission
The Platform charges a 5% commission on every ticket sale. This fee is deducted automatically from the ticket price before funds are credited to your account.

1.2 Funding Commission
The Platform charges a 3% commission on all pledges and funding contributions received for your events. This fee is deducted at the time the pledge is made.

1.3 Community Event Listing Fee
Events published with Community Event Rules enabled are subject to a \$10 listing fee, charged at the time of publication.

1.4 Fee Adjustments
Commission rates are set by the Platform and may be updated from time to time. You will be notified of any changes before they take effect. The rates applicable at the time of each transaction will apply.

2. FUNDING AND PLEDGES

2.1 Funding Goals
When a funding deadline is set for your event, a funding goal is required. You are responsible for setting a realistic and achievable goal.

2.2 Minimum Pledge
You may set a minimum pledge amount for your event. Each reserved spot requires the pledger to contribute at least the minimum pledge amount per spot.

2.3 Spot Reservations
You may configure a maximum number of spots each pledger can reserve (max_reserved_spots_per_user). Reserved spots count toward your event's maximum capacity. Unredeemed reserved spots are automatically released when the event transitions to live status.

3. REFUND POLICY

3.1 Refund Deadline
A refund deadline is automatically calculated as up to 20% of the funding duration. You may customize this within the allowed range. Pledgers who request a refund before the deadline will receive a full refund of their pledge amount.

3.2 Refund After Deadline
No refunds are issued to pledgers after the refund deadline has passed, unless the event is cancelled.

3.3 Event Cancellation Refunds
If your event is cancelled, all pledgers are entitled to a full refund of their pledge amounts. The Platform absorbs the commission loss.

3.4 Platform Fee on Refunds
When a pledger unpledges before the deadline, the Platform absorbs the commission previously deducted. No additional fees are charged to you for refunds.

4. ESCROW POLICY

4.1 Fund Holding
All pledged funds are held in Platform escrow. Funds are NOT released to you as a lump sum. Instead, they are released in three stages tied to verifiable milestones.

4.2 Three-Stage Release Schedule
  Stage 1 — Planning Confirmed (30% released): Triggered when your funding goal is met, an event date is confirmed, and a venue is confirmed. Organizers with a trust score above 80% receive 40% at this stage.
  Stage 2 — Event Imminent (40% released): Triggered automatically 48 hours before your event start time, or manually by a Platform administrator.
  Stage 3 — Event Completed (30% released): Triggered when your event is marked as completed and at least 25% of tickets have been scanned at the door, proving actual attendance.

4.3 Stage 3 Review Period
If the scan threshold is not met, Stage 3 funds are held for a 14-day review period during which a Platform administrator will investigate and may release or refund the funds.

5. FAILURE SCENARIOS

5.1 No Event Date Set
If your funding goal is met but you fail to set an event date within the configured grace period (default: 7 days), the Platform will notify you. If no event date is set, all backers will be auto-refunded and your account will be flagged.

5.2 Cancellation Before Stage 2
If your event is cancelled before Stage 2 funds are released, all unreleased escrow funds are returned to backers. Any funds already released at Stage 1 are not automatically recovered.

5.3 Cancellation After Stage 2
If your event is cancelled after Stage 2 funds have been released, the Platform will conduct an administrative review. You may be required to cooperate in arranging partial refunds from Stage 1 and Stage 2 funds.

5.4 Event Does Not Complete
If your event's end time passes and the event is not marked as completed within 7 days, the Platform administrator will be notified to investigate.

5.5 Cancellation Approval
Events that have reached 80% or more of their funding goal, or events in the selling_tickets phase, cannot be cancelled without Platform administrator approval. You may submit a cancellation request with a reason, which will be reviewed.

6. CLAWBACK

6.1 Right to Claw Back
The Platform reserves the right to claw back funds previously released to you if:
  (a) The event does not deliver the experience as described and promised to backers.
  (b) Fraudulent activity is detected in connection with your event.
  (c) You materially misrepresent the event details, capacity, or deliverables.

6.2 Stage 3 Hold
Stage 3 funds (final 30%) are held for 14 days after event completion specifically to allow investigation of complaints or irregularities before final release.

7. ACCOUNT SUSPENSION

7.1 Grounds for Suspension
Your organizer account may be suspended if:
  (a) You repeatedly fail to deliver events after receiving pledged funds.
  (b) Fraudulent activity or misrepresentation is detected.
  (c) You fail to cooperate with Platform administrators during investigations.
  (d) You receive multiple complaints from attendees about unfulfilled promises.

7.2 Payout Freeze
The Platform may freeze all pending payouts on your account at any time if fraud is suspected or under investigation.

7.3 Deposit Forfeiture
First-time organizers are required to place a refundable deposit before publishing a funded event. This deposit is returned after your first successful event (Stage 3 completed). If your account is suspended, the deposit may be forfeited.

7.4 Reinstatement
Account reinstatement after suspension is at the sole discretion of the Platform.

8. TRUST SCORE

8.1 Your trust score is calculated as the ratio of completed events to total published events. A higher trust score unlocks benefits such as a higher Stage 1 escrow release (40% instead of 30% for scores above 80%).

8.2 Repeated failures, cancellations, or complaints will lower your trust score and may result in the consequences described in Sections 6 and 7.

9. GENERAL

9.1 By creating your account, you acknowledge that you have read, understood, and agree to these terms.

9.2 The Platform reserves the right to update these terms. Continued use of the Platform after changes constitutes acceptance.

9.3 These terms are governed by the applicable laws of the jurisdiction in which the Platform operates.
''';

  static const String customerTerms = '''
CROWDFUND EVENTS — CUSTOMER TERMS AND CONDITIONS

Last updated: February 2026

By creating an account as a Customer on CrowdFund Events ("the Platform"), you agree to the following terms and conditions. Please read them carefully.

1. PLATFORM FEES

1.1 Ticket Fees
A 5% platform fee is included in the price of every ticket you purchase. This fee supports the operation and maintenance of the Platform.

1.2 Pledge Fees
A 3% platform fee is applied to all pledges you make toward event funding. This fee is deducted from your pledge amount before it is credited to the event's escrow.

1.3 No Hidden Fees
All applicable fees are displayed clearly on your ticket receipt and pledge receipt at the time of transaction. There are no additional hidden charges.

2. PLEDGING AND FUNDING

2.1 How Pledging Works
When you pledge to an event, your funds are held securely in Platform escrow. Your money is NOT given directly to the organizer. It is released to them only when specific milestones are met (event date confirmed, venue confirmed, event completed).

2.2 Spot Reservations
When pledging, you may reserve ticket spots (if the organizer has enabled this). Each reserved spot requires a minimum pledge amount. Reserved spots give you priority access when tickets go on sale. If you do not purchase tickets for your reserved spots before the event goes live, those spots are released back to the general pool.

2.3 Pledge Discount
Pledgers may receive a discount on ticket purchases. If you reserved spots during pledging, the discount is calculated per ticket based on your pledge amount divided by the number of spots reserved.

2.4 Guest Pledges
If you pledge as a guest (without registering for the event), your pledge is non-refundable. Guest users cannot reserve spots.

3. REFUND POLICY

3.1 Refund Before Deadline
Each event has a refund deadline (set by the organizer, capped at 20% of the funding duration). If you unpledge before this deadline, you will receive a full refund of your pledge amount.

3.2 No Refund After Deadline
Once the refund deadline has passed, your pledge is non-refundable unless the event is cancelled.

3.3 Event Cancellation
If an event you have pledged to or purchased tickets for is cancelled, you are entitled to a full refund.

3.4 Ticket Refunds
Ticket purchases are non-refundable except in the case of event cancellation.

4. ESCROW PROTECTION

4.1 Your Funds Are Protected
All pledged funds are held in Platform escrow and released to organizers only in stages as they meet real milestones:
  Stage 1: Funding goal met + event date and venue confirmed.
  Stage 2: 48 hours before the event starts.
  Stage 3: Event completed with verified attendance.

4.2 Organizer Trust Score
Each organizer has a trust score based on their track record of completed events. You can view this score on any event page to help you make informed pledging decisions.

4.3 If an Event Fails
If an organizer fails to deliver an event, the Platform will work to recover unreleased funds and issue refunds to affected backers. The Platform may also suspend the organizer's account.

5. TICKETS

5.1 Ticket Purchases
Tickets are available during the selling_tickets and live phases of an event. Prices include any applicable discounts and the platform fee.

5.2 Free Tickets
Some events or ticket tiers may be free. No fees or commissions apply to free tickets.

5.3 Waitlisted Tickets
If an event is at full capacity when you purchase, your ticket may be placed on a waitlist. The organizer will approve or reject waitlisted tickets. If rejected, your payment is refunded.

5.4 Ticket Receipts
A receipt is generated for every ticket purchase, showing the price breakdown including any discounts applied and the platform fee.

6. COMMUNITY EVENTS

6.1 Events marked as Community Events have special rules: ticket prices are capped at \$50 per tier, and event duration is limited to 14 days. These rules ensure community events remain accessible.

7. GENERAL

7.1 By creating your account, you acknowledge that you have read, understood, and agree to these terms.

7.2 The Platform reserves the right to update these terms. Continued use of the Platform after changes constitutes acceptance.

7.3 These terms are governed by the applicable laws of the jurisdiction in which the Platform operates.
''';
}
