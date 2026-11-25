"""Generate the revised design, project, and dashboard summary PDFs."""

from __future__ import annotations

import csv
import sys
from collections import Counter, defaultdict
from decimal import Decimal
from pathlib import Path

sys.path.insert(0, str(Path.home() / "AppData/Local/Temp/dmdd_pdf_review"))

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import (
    PageBreak,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
    LongTable,
    KeepTogether,
)
from reportlab.graphics.shapes import Drawing
from reportlab.graphics.charts.barcharts import VerticalBarChart
from reportlab.graphics.charts.barcharts import HorizontalBarChart


ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "DashboardData"
REVISION_DATE = "25 November 2026"
NAVY = colors.HexColor("#18324B")
TEAL = colors.HexColor("#087E8B")
SKY = colors.HexColor("#EAF3F7")
MINT = colors.HexColor("#E7F4F1")
INK = colors.HexColor("#273444")
MUTED = colors.HexColor("#5B6B78")
GRID = colors.HexColor("#CFD8DF")
WHITE = colors.white


def styles():
    base = getSampleStyleSheet()
    return {
        "title": ParagraphStyle(
            "TitleCustom", parent=base["Title"], fontName="Helvetica-Bold",
            fontSize=25, leading=30, textColor=NAVY, spaceAfter=12,
        ),
        "subtitle": ParagraphStyle(
            "SubtitleCustom", parent=base["Normal"], fontName="Helvetica",
            fontSize=11, leading=16, textColor=MUTED, spaceAfter=12,
        ),
        "h1": ParagraphStyle(
            "HeadingOneCustom", parent=base["Heading1"], fontName="Helvetica-Bold",
            fontSize=17, leading=21, textColor=NAVY, spaceBefore=3, spaceAfter=8,
        ),
        "h2": ParagraphStyle(
            "HeadingTwoCustom", parent=base["Heading2"], fontName="Helvetica-Bold",
            fontSize=11.5, leading=14, textColor=TEAL, spaceBefore=8, spaceAfter=5,
        ),
        "body": ParagraphStyle(
            "BodyCustom", parent=base["BodyText"], fontName="Helvetica",
            fontSize=9.2, leading=13.2, textColor=INK, spaceAfter=6,
        ),
        "small": ParagraphStyle(
            "SmallCustom", parent=base["BodyText"], fontName="Helvetica",
            fontSize=7.7, leading=10, textColor=INK,
        ),
        "small_white": ParagraphStyle(
            "SmallWhite", parent=base["BodyText"], fontName="Helvetica-Bold",
            fontSize=8, leading=10, textColor=WHITE,
        ),
        "table_head": ParagraphStyle(
            "TableHeadCustom", parent=base["BodyText"], fontName="Helvetica-Bold",
            fontSize=7.7, leading=9.3, textColor=WHITE,
        ),
        "callout": ParagraphStyle(
            "CalloutCustom", parent=base["BodyText"], fontName="Helvetica-Bold",
            fontSize=9.1, leading=13, textColor=NAVY,
        ),
        "center": ParagraphStyle(
            "CenterCustom", parent=base["BodyText"], fontName="Helvetica",
            fontSize=9, leading=12, alignment=TA_CENTER, textColor=INK,
        ),
    }


S = styles()


def para(text: str, style: str = "body") -> Paragraph:
    return Paragraph(text, S[style])


def footer(canvas, doc):
    canvas.saveState()
    width, _ = letter
    canvas.setStrokeColor(GRID)
    canvas.setLineWidth(0.5)
    canvas.line(36, 31, width - 36, 31)
    canvas.setFont("Helvetica", 7.5)
    canvas.setFillColor(MUTED)
    canvas.drawString(36, 19, f"Restaurant and Food Delivery DBMS | Schema v1 | {REVISION_DATE}")
    canvas.drawRightString(width - 36, 19, str(doc.page))
    canvas.restoreState()


def table_style(header=True, font=8):
    commands = [
        ("GRID", (0, 0), (-1, -1), 0.35, GRID),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 6),
        ("RIGHTPADDING", (0, 0), (-1, -1), 6),
        ("TOPPADDING", (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
        ("FONTNAME", (0, 0), (-1, -1), "Helvetica"),
        ("FONTSIZE", (0, 0), (-1, -1), font),
        ("TEXTCOLOR", (0, 0), (-1, -1), INK),
        ("ROWBACKGROUNDS", (0, 1 if header else 0), (-1, -1), [WHITE, SKY]),
    ]
    if header:
        commands += [
            ("BACKGROUND", (0, 0), (-1, 0), NAVY),
            ("TEXTCOLOR", (0, 0), (-1, 0), WHITE),
            ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
        ]
    return TableStyle(commands)


def callout(text: str, width=540):
    t = Table([[para(text, "callout")]], colWidths=[width])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), MINT),
        ("BOX", (0, 0), (-1, -1), 0.6, TEAL),
        ("LEFTPADDING", (0, 0), (-1, -1), 10),
        ("RIGHTPADDING", (0, 0), (-1, -1), 10),
        ("TOPPADDING", (0, 0), (-1, -1), 8),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
    ]))
    return t


def bullet(text: str):
    return para(f"<font color='{TEAL}'><b>-</b></font> {text}")


def build_design_document():
    output = ROOT / "Design Document.pdf"
    doc = SimpleDocTemplate(
        str(output), pagesize=letter, leftMargin=36, rightMargin=36,
        topMargin=38, bottomMargin=43, title="Restaurant DBMS - Revised Design Document",
        author="Restaurant and Food Delivery DBMS Project",
    )
    story = [
        para("Design Document", "title"),
        para(f"Revised SQL Server schema | Version 1 | {REVISION_DATE}", "subtitle"),
        para("Purpose and scope", "h1"),
        para(
            "This design describes the corrected schema installed by <b>DMDD_DDLScript.sql</b>. "
            "It supports restaurant profiles, staff roles, menu pricing, customer orders, dine-in visits, "
            "delivery, reviews, payments, and food-wastage reports. It replaces the original table list, "
            "which no longer matches the implemented model.",
        ),
        callout(
            "Important rules: order channel is stored per order; couriers are a shared fleet; order lines "
            "snapshot accepted menu prices; credentials are stored separately as application-generated Argon2id hashes."
        ),
        Spacer(1, 10),
        para("Data dictionary", "h1"),
    ]
    rows = [[para("Table", "table_head"), para("Primary key", "table_head"), para("Purpose and key relationships", "table_head")]]
    entities = [
        ("Locations", "ZipCode", "US postal-code directory; parents restaurants and customer/staff addresses."),
        ("Restaurants", "RestaurantID", "Restaurant profile and active flag; one location per restaurant."),
        ("RestaurantAccounts", "RestaurantID", "Restricted login record; unique username and Argon2id PHC hash."),
        ("RestaurantAccountAudit", "AccountAuditID", "Enrollment, reset, and disable audit events; no password/hash values."),
        ("RestaurantWastage", "RestaurantID + DateOfWastage", "One nonnegative pounds measurement per restaurant/day."),
        ("Customers", "CustomerID", "Customer profile; no permanent dine-in/delivery classification."),
        ("Employees", "EmployeeID", "HR-supplied unique staff ID, employer restaurant, role, pay, and active flag."),
        ("Waiters", "WaiterID", "Waiter subtype; restaurant relationship is checked against Employees."),
        ("Chefs", "ChefID", "Chef subtype; role is checked against Employees."),
        ("DeliveryEmployees", "DeliveryEmployeeID", "Courier subtype and transactional availability flag."),
        ("MenuItems", "MenuItemID", "Restaurant menu, unique per-restaurant code, exact decimal price, availability."),
        ("OrderStatuses", "OrderStatusID", "Unique status labels: Pending, Preparing, Ready, In Transit, Fulfilled, Cancelled."),
        ("OrderStatusTransitions", "FromStatusID + ToStatusID", "Allowed transitions for the order state machine."),
        ("Orders", "OrderID", "Customer, restaurant, service type, UTC creation time, and finalized exact totals."),
        ("OrderLines", "OrderID + MenuItemID", "Positive quantity, matching restaurant key, purchase-time UnitPrice snapshot."),
        ("DineInOrders", "OrderID", "Dine-in visit, same-restaurant waiter assignment, and visit timestamp."),
        ("Delivery", "OrderID", "At most one delivery per order; courier and UTC start/end timestamps."),
        ("Payments", "PaymentID", "Order-linked payment attempts with validated method, amount, and status."),
        ("Feedback", "OrderID", "One review per fulfilled order; reviewer is the order customer; complete 1-5 ratings."),
        ("OrderStatusHistory", "OrderStatusHistoryID", "Status change audit trail with UTC timestamp and actor."),
        ("EncryptionDemo", "DemoRecordID", "Optional synthetic recoverable-text example; not used for credentials."),
    ]
    for name, key, description in entities:
        display_name = name.replace("RestaurantAccountAudit", "RestaurantAccount<br/>Audit")
        display_name = display_name.replace("OrderStatusTransitions", "OrderStatus<br/>Transitions")
        rows.append([para(display_name, "small"), para(key, "small"), para(description, "small")])
    dictionary = LongTable(rows, colWidths=[1.15 * inch, 1.55 * inch, 4.8 * inch], repeatRows=1)
    dictionary.setStyle(table_style(font=7.6))
    story += [dictionary, PageBreak(), para("Relationships and integrity", "h1")]
    relations = [
        ("Restaurants", "Locations", "many restaurants use one location; restaurant location is required."),
        ("RestaurantWastage", "Restaurants", "each measurement belongs to one restaurant."),
        ("Employees", "Restaurants", "staff have one employing restaurant; couriers may serve any restaurant."),
        ("Waiters / Chefs / DeliveryEmployees", "Employees", "subtype rows are generated set-wise and role checked."),
        ("Orders", "Customers and Restaurants", "every order has one customer, restaurant, service type, and valid status."),
        ("OrderLines", "Orders and MenuItems", "composite foreign keys require menu items to belong to the order restaurant."),
        ("DineInOrders", "Orders and Waiters", "dine-in detail and waiter must match the order restaurant."),
        ("Delivery", "Orders and DeliveryEmployees", "one delivery per delivery order; a filtered unique index prevents two active courier assignments."),
        ("Payments", "Orders", "each attempt records the method and status for one order."),
        ("Feedback", "Orders and Customers", "only the customer on a fulfilled order may review it."),
        ("RestaurantAccounts", "Restaurants", "account credentials are one-to-one and separated from profile data."),
    ]
    rel_rows = [[para("Child", "table_head"), para("Parent", "table_head"), para("Rule", "table_head")]]
    rel_rows += [[para(a, "small"), para(b, "small"), para(c, "small")] for a, b, c in relations]
    rel_table = LongTable(rel_rows, colWidths=[1.65 * inch, 1.7 * inch, 4.15 * inch], repeatRows=1)
    rel_table.setStyle(table_style(font=7.8))
    story += [rel_table, Spacer(1, 12), para("State and financial rules", "h1")]
    for text in [
        "A new order starts Pending. Allowed transitions are Pending to Preparing or Cancelled; Preparing to Ready or Cancelled; Ready to In Transit, Fulfilled, or Cancelled; and In Transit to Fulfilled.",
        "Processing requires order lines and a finalized amount. Delivery orders cannot be Fulfilled without a started and completed delivery; dine-in orders require a visit record.",
        "Menu prices and line amounts use decimal types. Order creation stores UnitPrice, and finalization records subtotal, explicit tax rate, rounded tax amount, tip, and a computed total.",
        "Parent deletions are restricted by foreign keys. The IsActive flags support soft deactivation while preserving order and review history.",
        "Customer, employee, and menu IDs use their stated source. Order IDs are allocated from a SQL Server sequence. Seed inserts use fixed explicit identity values only in a guarded empty demo database.",
    ]:
        story.append(bullet(text))
    story += [Spacer(1, 8), callout("SQL Server 2019 or later is the supported baseline. The numbered initial-install and separate demo-seed entry points are documented in Migrations/README.md.")]
    doc.build(story, onFirstPage=footer, onLaterPages=footer)
    return output


def build_project_report():
    output = ROOT / "Restaurant and Food Delivery Database Management System.pdf"
    doc = SimpleDocTemplate(
        str(output), pagesize=letter, leftMargin=42, rightMargin=42,
        topMargin=42, bottomMargin=44, title="Restaurant and Food Delivery DBMS - Revised Technical Report",
        author="Restaurant and Food Delivery DBMS Project",
    )
    story = [
        Spacer(1, 22), para("Restaurant and Food Delivery", "title"),
        para("Database Management System - Revised Technical Report", "h1"),
        para(f"Corrected schema and scripts | {REVISION_DATE}", "subtitle"),
        Spacer(1, 18),
        callout("This report describes the revised repository implementation. It supersedes earlier statements that assigned a permanent service type to customers, encrypted login passwords reversibly, calculated bills from current menu prices, or described the Tableau workbook as live reporting.", width=528),
        Spacer(1, 18), para("Project objective", "h1"),
        para("Provide a relational system for restaurant operations and delivery, with reliable order totals, auditable food-wastage reporting, verified-order reviews, and access-separated reporting data."),
        para("The SQL scripts enforce the main relationships and lifecycle rules. Application responsibilities such as authentication verification, rate limiting, payment processing, and jurisdiction-specific tax configuration are stated separately.") ,
        para("What the corrected project delivers", "h2"),
    ]
    features = [
        ("Order integrity", "Transactional order creation, positive quantities, menu availability checks, restaurant-matched items, and purchase-time price snapshots."),
        ("Exact billing", "DECIMAL currency values, explicit tax-rate input, nonnegative tips, one-time finalization, and immutable finalized line prices."),
        ("Delivery lifecycle", "One delivery per order, shared courier fleet, active-assignment protection, exact timestamps, availability updates, and valid status transitions."),
        ("Auditable analytics", "Daily wastage detail and coverage summaries, complete verified-order reviews, and distinct restaurant rating averages."),
    ]
    feature_rows = [[para("Area", "table_head"), para("Implementation", "table_head")]]
    feature_rows += [[para(a, "small"), para(b, "small")] for a, b in features]
    ft = Table(feature_rows, colWidths=[1.45 * inch, 5.88 * inch], repeatRows=1)
    ft.setStyle(table_style(font=8.3))
    story += [ft, PageBreak(), para("1. Data model", "h1")]
    story += [
        para("The schema separates profile data from account credentials and represents service on each order. Customer records are not permanently classed as dine-in or delivery. A customer may use both services over time."),
        para("Orders carry the restaurant and service type. DineInOrders stores the visit-specific waiter assignment. Delivery stores one row per order and derives the restaurant through Orders. Delivery employees belong to a shared platform fleet, so their home restaurant does not limit where they deliver."),
        para("OrderLines reference both the order and menu item through keys containing RestaurantID. That prevents an order for one restaurant from containing another restaurant's menu items. The accepted menu price is saved on each line."),
        para("Feedback is attached to one fulfilled order. A composite foreign key ties the review to the order's customer, ratings are required, and a trigger blocks reviews before fulfillment. A customer may review again after a later eligible order."),
        para("Deletion uses restrictive foreign keys. Restaurants, customers, and employees have active flags for soft deactivation; historical orders and feedback stay available."),
        para("Order status flow", "h2"),
        callout("Pending -> Preparing -> Ready -> Fulfilled (dine-in)<br/>Pending -> Preparing -> Ready -> In Transit -> Fulfilled (delivery)<br/>Cancellation is allowed before dispatch; terminal states cannot be reopened.", width=528),
        Spacer(1, 13), para("2. Transaction workflows", "h1"),
        para("<b>Create:</b> dbo.usp_CreateOrder checks active customer and restaurant records, active menu items, matching ownership, and quantities while holding the menu rows. It creates the order and lines in one transaction and snapshots current prices."),
        para("<b>Finalize:</b> dbo.usp_CalculateTotalAmount accepts an explicit tax rate and tip. It calculates from saved prices, rounds tax to cents, locks the order and lines, stores the breakdown once, and returns the exact total through an OUTPUT parameter."),
        para("<b>Deliver:</b> assignment requires a Ready order and an available active courier. Start and completion procedures update delivery times, courier availability, and order status together. A filtered unique index prevents concurrent active assignments to one courier."),
        para("<b>Review:</b> only the customer on a Fulfilled order can create its review. Food and service scores are both required on the 1-5 scale."),
        PageBreak(), para("3. Reporting procedures", "h1"),
    ]
    procedure_rows = [[para("Procedure", "table_head"), para("Contract", "table_head")]]
    procedures = [
        ("usp_CalculateAndDisplayFoodWastageByRestaurants", "Groups measurements by day, month, half-year, or year within an inclusive date range. Returns measured-day count, pounds total, and average; an absent measurement is not treated as zero."),
        ("usp_CalculateTotalAmount", "Finalizes one pending order with an explicit decimal tax rate and nonnegative tip. It uses UnitPrice snapshots and outputs an exact decimal total."),
        ("usp_TopRestaurantsInArea", "Returns up to five distinct restaurants by average of complete food/service ratings, on a 1-5 scale, with review count and deterministic tie-break."),
        ("usp_CalculateFastestDelivery", "Ranks completed valid deliveries by exact millisecond duration and returns order, courier, and UTC timestamps."),
        ("usp_ListDeliveryViolations", "Accepts a minute threshold, defaults to 60, and can include active overdue deliveries. A violation is strictly greater than the threshold."),
    ]
    procedure_rows += [[para(a, "small"), para(b, "small")] for a, b in procedures]
    pt = LongTable(procedure_rows, colWidths=[2.35 * inch, 4.98 * inch], repeatRows=1)
    pt.setStyle(table_style(font=8.2))
    story += [pt, Spacer(1, 10), para("Reporting views", "h2")]
    for text in [
        "v_RestaurantWastageDaily exposes one row per recorded restaurant/day and labels a measured zero correctly.",
        "v_RestaurantWastageSummary groups by RestaurantID, includes observation count and first/last dates, and leaves lifetime total NULL where no observations exist.",
        "v_RestaurantRatings calculates the restaurant mean from verified reviews. Other views expose a directory, menu catalog, and limited order summary.",
        "DMDD_Permissions.sql grants procedures and views to application and reporting service roles, while credential changes are limited to a separate account-admin service role. These database roles are not tenant boundaries; the application must authorize each restaurant action.",
    ]:
        story.append(bullet(text))
    story += [PageBreak(), para("4. Security and deployment", "h1")]
    story += [
        para("RestaurantAccounts is separate from Restaurants and stores an Argon2id PHC hash, never a decryptable password. Enrollment and reset procedures accept only application-generated Argon2id strings and write audit events without recording credentials."),
        para("The application must authorize restaurant scope, verify passwords with a vetted Argon2id library, enforce rate limiting and account recovery, use TLS, and protect backups and exports. The database does not implement a login service or payment processor."),
        para("Encryption.sql and Decryption.sql are optional demonstrations for one synthetic note encrypted with SQL Server AES-256 and bound to its row ID. This is column encryption, not Transparent Data Encryption. The database master key and certificate need protected backup and rotation before any real recoverable data is used."),
        para("Deployment uses SQL Server 2019 or later and a batch-aware client. Migrations/001_InitialInstall.sql installs the version 1 schema, triggers, views, procedures, and permissions. Migrations/002_SeedDemoData.sql is a separate guarded seed that requires an empty project database."),
        para("There is no automatic upgrade from the original schema. Old reversible credentials require password resets; historical purchase prices cannot be reconstructed from today's menu prices. Migrations/README.md documents staging, backup, and evidence requirements for an existing database."),
        para("5. Seed and dashboard scope", "h1"),
        para("The synthetic seed contains 6 locations, 15 restaurants, 15 customers, 30 employees, 47 menu items, 155 January 2021 wastage measurements for five restaurants, 15 fulfilled orders, 30 order lines, 12 completed deliveries, 3 dine-in visits, and 15 order-linked reviews. The 379 core-row figure includes lookup rows and staff subtypes but excludes 72 status-history entries."),
        para("Sample names and contacts are fictional; phone numbers use the reserved 555-0100 through 555-0199 range. The seed contains no accounts or payments. A zero tax rate and zero tip are explicit demo values because historical tax and payment details were not supplied."),
        para("The Tableau workbook is a static CSV/Hyper snapshot for restaurant and customer counts, measured wastage, and feedback ratings. It does not connect live to SQL Server and does not present order or delivery KPIs. Its refresh sources are sanitized and packaged; a second-machine Tableau refresh still requires a manual check."),
        para("6. Verification scope", "h1"),
        para("The scripts and workbook XML received a static source review. They were not executed against SQL Server, and the workbook was not opened or refreshed in Tableau Desktop. The SQL Server services were stopped in the review environment. Runtime, concurrency, restore, permissions, and rendered-dashboard behavior should be checked on a disposable SQL Server 2019+ instance and Tableau Desktop before release."),
    ]
    doc.build(story, onFirstPage=footer, onLaterPages=footer)
    return output


def dashboard_metrics():
    totals = defaultdict(Decimal)
    days = Counter()
    with (DATA / "RestaurantWastage.csv").open(encoding="utf-8-sig", newline="") as stream:
        for row in csv.DictReader(stream):
            rid = int(row["RestaurantID"])
            totals[rid] += Decimal(row["WastageQuantityInPounds"])
            days[rid] += 1
    ratings = {}
    with (DATA / "feedback1.csv").open(encoding="utf-8-sig", newline="") as stream:
        rows = list(csv.DictReader(stream))
    for row in rows:
        rid = int(row["RestaurantID"])
        ratings[rid] = (Decimal(row["FoodRating"]) + Decimal(row["ServiceRating"])) / Decimal(2)
    channels = Counter()
    with (DATA / "customer.csv").open(encoding="utf-8-sig", newline="") as stream:
        for row in csv.DictReader(stream):
            channels[row["LastOrderChannel"]] += 1
    return totals, days, ratings, channels


def average_waste_chart(totals, days):
    ids = sorted(totals)
    values = [float(totals[i] / Decimal(days[i])) for i in ids]
    drawing = Drawing(505, 220)
    chart = VerticalBarChart()
    chart.x, chart.y, chart.width, chart.height = 55, 42, 415, 150
    chart.data = [values]
    chart.categoryAxis.categoryNames = [f"R{i:02d}" for i in ids]
    chart.categoryAxis.labels.fontName = "Helvetica"
    chart.categoryAxis.labels.fontSize = 8
    chart.valueAxis.valueMin = 0
    chart.valueAxis.valueMax = max(values) * 1.25
    chart.valueAxis.valueStep = max(1, int(chart.valueAxis.valueMax / 5))
    chart.valueAxis.labels.fontName = "Helvetica"
    chart.valueAxis.labels.fontSize = 7
    chart.valueAxis.labelTextFormat = "%.1f"
    chart.valueAxis.visibleGrid = True
    chart.valueAxis.gridStrokeColor = GRID
    chart.valueAxis.gridStrokeWidth = 0.45
    chart.bars[0].fillColor = TEAL
    chart.barSpacing = 8
    chart.groupSpacing = 18
    chart.barLabelFormat = "%.2f"
    chart.barLabels.fontName = "Helvetica"
    chart.barLabels.fontSize = 7
    chart.barLabels.fillColor = INK
    chart.barLabels.nudge = 4
    drawing.add(chart)
    return drawing


def rating_chart(ratings):
    ids = sorted(ratings)
    values = [float(ratings[i]) for i in ids]
    drawing = Drawing(505, 350)
    chart = HorizontalBarChart()
    chart.x, chart.y, chart.width, chart.height = 58, 30, 410, 300
    chart.data = [values]
    chart.categoryAxis.categoryNames = [f"Demo Restaurant {i:02d}" for i in ids]
    chart.categoryAxis.labels.fontName = "Helvetica"
    chart.categoryAxis.labels.fontSize = 7
    chart.valueAxis.valueMin = 0
    chart.valueAxis.valueMax = 5
    chart.valueAxis.valueStep = 1
    chart.valueAxis.labels.fontName = "Helvetica"
    chart.valueAxis.labels.fontSize = 7
    chart.valueAxis.visibleGrid = True
    chart.valueAxis.gridStrokeColor = GRID
    chart.valueAxis.gridStrokeWidth = 0.45
    chart.bars[0].fillColor = TEAL
    chart.barSpacing = 2
    chart.groupSpacing = 4
    drawing.add(chart)
    return drawing


def build_visualization_report():
    output = DATA / "Data Visualization Report.pdf"
    totals, days, ratings, channels = dashboard_metrics()
    doc = SimpleDocTemplate(
        str(output), pagesize=letter, leftMargin=42, rightMargin=42,
        topMargin=38, bottomMargin=43, title="Data Visualization Report - Revised Snapshot",
        author="Restaurant and Food Delivery DBMS Project",
    )
    story = [
        para("Data Visualization Report", "title"),
        para(f"Sanitized Tableau snapshot | Prepared {REVISION_DATE} | Data dates: January 2021 wastage seed", "subtitle"),
        callout("This workbook is a portable CSV/Hyper snapshot. It is not a live SQL Server dashboard. The packaged workbook covers restaurant and customer counts, daily wastage, and restaurant feedback; it does not report orders or deliveries.", width=528),
        Spacer(1, 10), para("Snapshot coverage", "h1"),
    ]
    cov = [
        [para("Restaurants", "table_head"), para("Customers", "table_head"), para("Reviews", "table_head"), para("Wastage days", "table_head")],
        [para("15", "center"), para("15", "center"), para("15", "center"), para("155", "center")],
    ]
    ct = Table(cov, colWidths=[1.833333 * inch] * 4)
    ct.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), NAVY), ("BACKGROUND", (0, 1), (-1, 1), SKY),
        ("GRID", (0, 0), (-1, -1), 0.5, GRID), ("TOPPADDING", (0, 0), (-1, -1), 8),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 8), ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
    ]))
    story += [ct, Spacer(1, 12), para("Average measured wastage per restaurant", "h2"),
              para("The workbook uses AVG(WastageQuantityInPounds) at the restaurant/day grain. Only restaurants with recorded measurements appear; missing days are not treated as zero.", "small"),
              average_waste_chart(totals, days)]
    summary = [[para("Restaurant", "table_head"), para("Measured days", "table_head"), para("Total pounds", "table_head"), para("Average pounds/day", "table_head")]]
    for rid in sorted(totals):
        summary.append([para(f"Demo Restaurant {rid:02d}", "small"), para(str(days[rid]), "small"), para(f"{totals[rid]:,.2f}", "small"), para(f"{totals[rid] / days[rid]:,.2f}", "small")])
    st = Table(summary, colWidths=[1.8 * inch, 1.2 * inch, 1.6 * inch, 1.65 * inch], repeatRows=1)
    st.setStyle(table_style(font=8))
    story += [st, PageBreak(), para("Average restaurant rating", "h1"),
              para("Each plotted score is (FoodRating + ServiceRating) / 2.0 for one complete verified-order review. The metric is a 1-5 average, not a 2-10 rating sum. The seed has one review per restaurant.", "body"),
              rating_chart(ratings)]
    channel_rows = [[para("Latest order channel in this snapshot", "table_head"), para("Customers", "table_head")]]
    for name in ("Delivery", "Dine-in"):
        channel_rows.append([para(name, "small"), para(str(channels[name]), "small")])
    cht = Table(channel_rows, colWidths=[3.4 * inch, 1.8 * inch], repeatRows=1)
    cht.setStyle(table_style(font=8.2))
    story += [cht, Spacer(1, 10), para("Refresh and reconciliation", "h2"),
              para("The workbook and sanitized source CSVs are packaged together. To refresh, export the documented reporting rows, rebuild the Hyper extract with DashboardData/build_tableau_package.py, then open the TWBX in Tableau on a second machine and compare the results with dbo.v_RestaurantWastageDaily and dbo.v_RestaurantRatings. A Tableau Desktop open/refresh and visual check remains to be performed by a local Tableau installation.", "small")]
    doc.build(story, onFirstPage=footer, onLaterPages=footer)
    return output


def main():
    generated = [build_design_document(), build_project_report(), build_visualization_report()]
    for path in generated:
        print(path)


if __name__ == "__main__":
    main()
