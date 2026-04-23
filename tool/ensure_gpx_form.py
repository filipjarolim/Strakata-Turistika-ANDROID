from pathlib import Path
from datetime import datetime

from pymongo import MongoClient


def read_database_url() -> str:
    env_path = Path(".env")
    if not env_path.exists():
        raise RuntimeError(".env was not found")
    for line in env_path.read_text(encoding="utf-8").splitlines():
        if line.startswith("DATABASE_URL="):
            value = line.split("=", 1)[1].strip()
            if value:
                return value
    raise RuntimeError("DATABASE_URL is missing in .env")


def main() -> None:
    database_url = read_database_url()
    client = MongoClient(database_url)
    db = client.get_default_database()
    forms = db["forms"]

    now = datetime.utcnow().isoformat()

    def doc(slug: str, name: str, steps: list[dict]) -> dict:
        return {
            "slug": slug,
            "name": name,
            "definition": {"name": name, "steps": steps},
            "createdAt": now,
            "updatedAt": now,
            "isActive": True,
        }

    edit_step = {
        "id": "edit",
        "label": "Detaily výletu",
        "order": 1,
        "fields": [
            {"id": "route_title", "type": "title_input", "label": "Název trasy", "order": 0, "required": True},
            {"id": "route_description", "type": "description_input", "label": "Popis trasy", "order": 1, "required": False},
            {"id": "visit_date", "type": "calendar", "label": "Datum návštěvy", "order": 2, "required": True},
            {"id": "dog_not_allowed", "type": "dog_switch", "label": "Pes neměl přístup", "order": 3, "required": False},
            {"id": "places", "type": "places_manager", "label": "Bodovaná místa", "order": 4, "required": False},
            {
                "id": "monthly_theme",
                "type": "monthly_theme",
                "label": "Téma měsíce",
                "order": 5,
                "required": False,
            },
        ],
    }

    finish_step = {
        "id": "finish",
        "label": "Dokončení",
        "order": 2,
        "fields": [
            {"id": "route_summary", "type": "route_summary", "label": "Souhrn trasy", "order": 0, "required": False},
            {"id": "map_preview", "type": "map_preview", "label": "Náhled mapy", "order": 1, "required": False},
            {"id": "images", "type": "image_upload", "label": "Fotografie", "order": 2, "required": True},
        ],
    }

    required_forms = [
        doc(
            "gps-tracking",
            "GPS záznam trasy",
            [
                {
                    "id": "upload",
                    "label": "Nahrání trasy",
                    "order": 0,
                    "fields": [
                        {"id": "map_preview", "type": "map_preview", "label": "Náhled mapy", "order": 0, "required": False},
                    ],
                },
                edit_step,
                finish_step,
            ],
        ),
        doc(
            "gpx-upload",
            "Nahrání GPX souboru",
            [
                {
                    "id": "upload",
                    "label": "Nahrání GPX",
                    "order": 0,
                    "fields": [
                        {"id": "gpx_file", "type": "gpx_upload", "label": "GPX soubor", "order": 0, "required": True},
                    ],
                },
                edit_step,
                finish_step,
            ],
        ),
        doc(
            "screenshot-upload",
            "Nahrání screenshotu trasy",
            [
                {
                    "id": "upload",
                    "label": "Nahrání screenshotu",
                    "order": 0,
                    "fields": [
                        {"id": "images", "type": "image_upload", "label": "Screenshot trasy", "order": 0, "required": True},
                    ],
                },
                edit_step,
                finish_step,
            ],
        ),
        doc(
            "strakata-upload",
            "Strakatá trasa",
            [
                {
                    "id": "upload",
                    "label": "Strakatá trasa",
                    "order": 0,
                    "fields": [
                        {"id": "gpx_file", "type": "gpx_upload", "label": "GPX soubor", "order": 0, "required": True},
                        {
                            "id": "strakata_route",
                            "type": "strakata_route_selector",
                            "label": "Kategorie Strakaté trasy",
                            "order": 1,
                            "required": True,
                        },
                    ],
                },
                edit_step,
                finish_step,
            ],
        ),
    ]

    inserted = 0
    for form in required_forms:
        if forms.find_one({"slug": form["slug"]}, {"_id": 1}):
            continue
        forms.insert_one(form)
        inserted += 1

    print(f"Inserted {inserted} missing form documents")


if __name__ == "__main__":
    main()
