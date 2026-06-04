from fastapi import APIRouter, File, UploadFile

router = APIRouter(prefix="/imports", tags=["imports"])


@router.post("/excel")
async def import_excel(file: UploadFile = File(...)) -> dict[str, str]:
    return {
        "status": "stub",
        "file_name": file.filename or "unknown",
        "message": "Excel import is reserved for v2. The endpoint is ready for integration tests and UI wiring.",
    }
