import json
import os
import shutil
import subprocess
import tempfile
import time
from datetime import datetime, timezone
from pathlib import Path

import fitz
from azure.identity import DefaultAzureCredential
from azure.search.documents import SearchClient
from azure.storage.blob import BlobServiceClient, ContentSettings
from azure.storage.queue import QueueClient


def get_credential():
    return DefaultAzureCredential(exclude_interactive_browser_credential=True)


def get_blob_service_client():
    account = os.environ["AZURE_STORAGE_ACCOUNT"]
    return BlobServiceClient(
        account_url=f"https://{account}.blob.core.windows.net",
        credential=get_credential(),
    )


def get_queue_client():
    account = os.environ["AZURE_STORAGE_ACCOUNT"]
    queue_name = os.environ.get("AZURE_QUEUE_NAME", "index-jobs")
    return QueueClient(
        account_url=f"https://{account}.queue.core.windows.net",
        queue_name=queue_name,
        credential=get_credential(),
    )


def get_search_client():
    return SearchClient(
        endpoint=os.environ["AZURE_SEARCH_ENDPOINT"],
        index_name=os.environ["AZURE_SEARCH_INDEX"],
        credential=get_credential(),
    )


def download_original(blob_service, job, work_dir):
    source_path = work_dir / job["file_name"]
    blob_client = blob_service.get_blob_client(
        container=job.get("container", "original"),
        blob=job["blob_name"],
    )
    source_path.write_bytes(blob_client.download_blob().readall())
    return source_path, blob_client.url


def convert_to_pdf(source_path, file_ext, work_dir):
    if file_ext == "pdf":
        pdf_path = work_dir / f"{source_path.stem}.pdf"
        if source_path != pdf_path:
            shutil.copyfile(source_path, pdf_path)
        return pdf_path

    subprocess.run(
        [
            "soffice",
            "--headless",
            "--convert-to",
            "pdf",
            "--outdir",
            str(work_dir),
            str(source_path),
        ],
        check=True,
        timeout=300,
    )

    pdf_path = work_dir / f"{source_path.stem}.pdf"
    if not pdf_path.exists():
        candidates = sorted(work_dir.glob("*.pdf"))
        if not candidates:
            raise RuntimeError(f"LibreOffice did not create a PDF for {source_path.name}")
        pdf_path = candidates[0]
    return pdf_path


def upload_pdf(blob_service, file_id, pdf_path):
    blob_name = f"{file_id}/{pdf_path.name}"
    blob_client = blob_service.get_blob_client(
        container="converted-pdf",
        blob=blob_name,
    )
    blob_client.upload_blob(
        pdf_path.read_bytes(),
        overwrite=True,
        content_settings=ContentSettings(content_type="application/pdf"),
    )
    return blob_client.url


def upload_thumbnail(blob_service, file_id, page_no, png_bytes):
    blob_name = f"{file_id}/page-{page_no}.png"
    blob_client = blob_service.get_blob_client(
        container="thumbnails",
        blob=blob_name,
    )
    blob_client.upload_blob(
        png_bytes,
        overwrite=True,
        content_settings=ContentSettings(content_type="image/png"),
    )
    return blob_name


def run_ocr(png_bytes, work_dir, page_no):
    image_path = work_dir / f"ocr-page-{page_no}.png"
    image_path.write_bytes(png_bytes)

    try:
        result = subprocess.run(
            [
                "tesseract",
                str(image_path),
                "stdout",
                "-l",
                "kor+eng",
                "--psm",
                "6",
            ],
            check=False,
            capture_output=True,
            text=True,
            timeout=90,
        )
    except Exception as exc:
        print(f"OCR failed on page {page_no}: {exc}", flush=True)
        return ""

    if result.returncode != 0:
        print(
            f"OCR returned {result.returncode} on page {page_no}: {result.stderr[:500]}",
            flush=True,
        )
        return ""

    return " ".join(result.stdout.split())


def build_page_documents(blob_service, job):
    now = datetime.now(timezone.utc).isoformat()
    file_id = job["file_id"]
    file_name = job["file_name"]
    file_ext = job.get("file_ext", "").lower()

    with tempfile.TemporaryDirectory() as tmp:
        work_dir = Path(tmp)
        source_path, source_blob_url = download_original(blob_service, job, work_dir)
        pdf_path = convert_to_pdf(source_path, file_ext, work_dir)
        pdf_blob_url = upload_pdf(blob_service, file_id, pdf_path)

        documents = []
        pdf = fitz.open(pdf_path)
        for page_index, page in enumerate(pdf, start=1):
            text = page.get_text("text").strip()
            if not text:
                text = f"{file_name} page {page_index}"

            pixmap = page.get_pixmap(matrix=fitz.Matrix(2, 2), alpha=False)
            png_bytes = pixmap.tobytes("png")
            ocr_text = run_ocr(png_bytes, work_dir, page_index)
            thumb_blob_name = upload_thumbnail(
                blob_service,
                file_id,
                page_index,
                png_bytes,
            )

            documents.append(
                {
                    "id": f"{file_id}_p{page_index}_c0",
                    "file_id": file_id,
                    "file_name": file_name,
                    "file_ext": file_ext,
                    "page_no": page_index,
                    "slide_no": page_index,
                    "chunk_no": 0,
                    "title": file_name,
                    "text": text[:12000],
                    "ocr_text": ocr_text[:12000],
                    "image_caption": "",
                    "source_blob_url": source_blob_url,
                    "pdf_blob_url": pdf_blob_url,
                    "thumb_blob_url": thumb_blob_name,
                    "updated_at": now,
                }
            )

        pdf.close()
        return documents


def main():
    print("PPT Document Search Worker started", flush=True)

    queue = get_queue_client()
    search = get_search_client()
    blob_service = get_blob_service_client()

    messages = queue.receive_messages(messages_per_page=5, visibility_timeout=600)

    processed = 0

    for msg in messages:
        print("Received queue message:", msg.id, flush=True)

        job = json.loads(msg.content)
        print("Job:", job, flush=True)

        docs = build_page_documents(blob_service, job)
        if docs:
            result = search.upload_documents(documents=docs)
            print("Search upload result:", result, flush=True)

        queue.delete_message(msg)
        print("Deleted queue message:", msg.id, flush=True)

        processed += 1

    print(f"Worker complete. processed={processed}", flush=True)

    # Keep the process alive briefly so Container Apps log streaming can attach.
    time.sleep(3)


if __name__ == "__main__":
    main()
