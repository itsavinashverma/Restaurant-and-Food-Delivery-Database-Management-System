"""Build a portable Tableau TWBX from the sanitized CSV snapshot.

Requires tableauhyperapi. Run from any directory with:
    python DashboardData/build_tableau_package.py
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import tempfile
import zipfile
from pathlib import Path

from tableauhyperapi import (
    Connection,
    CreateMode,
    HyperProcess,
    Inserter,
    Nullability,
    SqlType,
    TableDefinition,
    TableName,
    Telemetry,
)


ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = Path(__file__).resolve().parent
WORKBOOK_TEMPLATE = DATA_DIR / "DMDD_Tableau.twb"
REPORT_PDF = DATA_DIR / "Data Visualization Report.pdf"
SOURCE_NAMES = (
    "RestaurantWastage.csv",
    "Restaurant.csv",
    "feedback1.csv",
    "customer.csv",
)
HYPER_RELATIVE_PATH = Path(
    "Data/TableauTemp/#TableauTemp_1hmcxss1bnyobl13d2ihv0z5rwlo.hyper"
)
TABLES = {
    "RestaurantWastage.csv": "RestaurantWastage.csv_ACD5F5F333084F25973BB59660A6D721",
    "Restaurant.csv": "Restaurant.csv_C026B1B4C329418D94FB61858A4C5250",
    "feedback1.csv": "feedback1.csv_741F412BA64A42D59DA0368F2145688F",
    "customer.csv": "customer.csv_942F10E9D241461FB787F2294376C433",
}


def read_csv(name: str) -> list[dict[str, str]]:
    path = DATA_DIR / name
    with path.open("r", encoding="utf-8-sig", newline="") as stream:
        reader = csv.DictReader(stream)
        if not reader.fieldnames:
            raise ValueError(f"{path} has no CSV header")
        forbidden = {"StreetAddress", "PhoneNumber", "CustomerType"}
        if forbidden.intersection(reader.fieldnames):
            raise ValueError(f"{path} contains a contact or obsolete channel field")
        return list(reader)


def csv_rows() -> dict[str, list[tuple]]:
    waste = [
        (
            int(row["RestaurantID"]),
            dt.date.fromisoformat(row["DateOfWastage"]),
            float(row["WastageQuantityInPounds"]),
        )
        for row in read_csv("RestaurantWastage.csv")
    ]
    restaurants = [
        (int(row["RestaurantID"]), row["RestaurantName"], int(row["ZipCode"]), row["Cuisine"])
        for row in read_csv("Restaurant.csv")
    ]
    feedback = [
        (
            int(row["CustomerID"]),
            int(row["RestaurantID"]),
            row["FeedbackDescription"],
            int(row["FoodRating"]),
            int(row["ServiceRating"]),
        )
        for row in read_csv("feedback1.csv")
    ]
    customers = [
        (int(row["CustomerID"]), row["CustomerName"], int(row["ZipCode"]), row["LastOrderChannel"])
        for row in read_csv("customer.csv")
    ]

    expected = {"RestaurantWastage.csv": 155, "Restaurant.csv": 15, "feedback1.csv": 15, "customer.csv": 15}
    actual = {
        "RestaurantWastage.csv": len(waste),
        "Restaurant.csv": len(restaurants),
        "feedback1.csv": len(feedback),
        "customer.csv": len(customers),
    }
    if actual != expected:
        raise ValueError(f"Unexpected dashboard snapshot row counts: {actual}")
    if len({(row[0], row[1]) for row in waste}) != len(waste):
        raise ValueError("Wastage rows must be unique per restaurant and date")
    if len({row[0] for row in restaurants}) != len(restaurants):
        raise ValueError("Restaurant IDs must be unique")
    if len({row[0] for row in customers}) != len(customers):
        raise ValueError("Customer IDs must be unique")
    if any(not 1 <= row[3] <= 5 or not 1 <= row[4] <= 5 for row in feedback):
        raise ValueError("Ratings must be complete values from 1 to 5")
    if any(row[3] not in ("Delivery", "Dine-in", "No order") for row in customers):
        raise ValueError("LastOrderChannel must be Delivery or Dine-in")

    return {
        "RestaurantWastage.csv": waste,
        "Restaurant.csv": restaurants,
        "feedback1.csv": feedback,
        "customer.csv": customers,
    }


def table_definitions() -> dict[str, list[TableDefinition.Column]]:
    required = Nullability.NOT_NULLABLE
    return {
        "RestaurantWastage.csv": [
            TableDefinition.Column("RestaurantID", SqlType.big_int(), required),
            TableDefinition.Column("DateOfWastage", SqlType.date(), required),
            TableDefinition.Column("WastageQuantityInPounds", SqlType.double(), required),
        ],
        "Restaurant.csv": [
            TableDefinition.Column("RestaurantID", SqlType.big_int(), required),
            TableDefinition.Column("RestaurantName", SqlType.text(), required),
            TableDefinition.Column("ZipCode", SqlType.big_int(), required),
            TableDefinition.Column("Cuisine", SqlType.text(), required),
        ],
        "feedback1.csv": [
            TableDefinition.Column("CustomerID", SqlType.big_int(), required),
            TableDefinition.Column("RestaurantID", SqlType.big_int(), required),
            TableDefinition.Column("FeedbackDescription", SqlType.text(), required),
            TableDefinition.Column("FoodRating", SqlType.big_int(), required),
            TableDefinition.Column("ServiceRating", SqlType.big_int(), required),
        ],
        "customer.csv": [
            TableDefinition.Column("CustomerID", SqlType.big_int(), required),
            TableDefinition.Column("CustomerName", SqlType.text(), required),
            TableDefinition.Column("ZipCode", SqlType.big_int(), required),
            TableDefinition.Column("LastOrderChannel", SqlType.text(), required),
        ],
    }


def build_hyper(path: Path, data: dict[str, list[tuple]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with HyperProcess(Telemetry.DO_NOT_SEND_USAGE_DATA_TO_TABLEAU) as hyper:
        with Connection(hyper.endpoint, str(path), CreateMode.CREATE_AND_REPLACE) as connection:
            connection.catalog.create_schema("Extract")
            for source_name in SOURCE_NAMES:
                definition = TableDefinition(
                    TableName("Extract", TABLES[source_name]),
                    table_definitions()[source_name],
                )
                connection.catalog.create_table(definition)
                with Inserter(connection, definition) as inserter:
                    inserter.add_rows(data[source_name])
                    inserter.execute()


def build_package(output: Path) -> None:
    if not WORKBOOK_TEMPLATE.is_file() or not REPORT_PDF.is_file():
        raise FileNotFoundError("Workbook template or revised visualization report is missing")
    workbook = WORKBOOK_TEMPLATE.read_bytes()
    if b"C:/Users/" in workbook or b"C:\\Users\\" in workbook:
        raise ValueError("The workbook template contains an absolute Windows user path")

    data = csv_rows()
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="restaurant_tableau_") as temp_name:
        temp = Path(temp_name)
        hyper_path = temp / HYPER_RELATIVE_PATH
        build_hyper(hyper_path, data)

        inner_path = temp / "DMDD_Tableau.twbx"
        with zipfile.ZipFile(inner_path, "w", compression=zipfile.ZIP_DEFLATED) as package:
            package.writestr("dmdd.twb", workbook)
            package.write(hyper_path, HYPER_RELATIVE_PATH.as_posix())
            for source_name in SOURCE_NAMES:
                package.write(DATA_DIR / source_name, f"Data/Source/{source_name}")

        outer_temp = output.with_suffix(output.suffix + ".tmp")
        with zipfile.ZipFile(outer_temp, "w", compression=zipfile.ZIP_DEFLATED) as archive:
            archive.write(inner_path, "DataVisualizationDashboard/DMDD_Tableau.twbx")
            archive.write(REPORT_PDF, "DataVisualizationDashboard/Data Visualization Report.pdf")
        outer_temp.replace(output)

    print(f"Wrote {output} with a packaged workbook, sanitized CSV sources, and rebuilt Hyper extract.")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "DataVisualizationDashboard.zip")
    args = parser.parse_args()
    build_package(args.output.resolve())


if __name__ == "__main__":
    main()
