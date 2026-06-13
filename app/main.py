import os
import json
import uuid
import html
from datetime import datetime, timezone

import fitz
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.responses import HTMLResponse, Response

from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient
from azure.storage.queue import QueueClient
from azure.search.documents import SearchClient


app = FastAPI(title="PPT Document Search Web")


def get_credential():
    return DefaultAzureCredential(exclude_interactive_browser_credential=True)


def get_storage_account():
    return os.environ["AZURE_STORAGE_ACCOUNT"]


def get_queue_name():
    return os.environ.get("AZURE_QUEUE_NAME", "index-jobs")


def get_search_endpoint():
    return os.environ["AZURE_SEARCH_ENDPOINT"]


def get_search_index():
    return os.environ["AZURE_SEARCH_INDEX"]


def get_blob_service_client():
    account = get_storage_account()
    return BlobServiceClient(
        account_url=f"https://{account}.blob.core.windows.net",
        credential=get_credential(),
    )


def get_queue_client():
    account = get_storage_account()
    queue_name = get_queue_name()
    return QueueClient(
        account_url=f"https://{account}.queue.core.windows.net",
        queue_name=queue_name,
        credential=get_credential(),
    )


def get_search_client():
    return SearchClient(
        endpoint=get_search_endpoint(),
        index_name=get_search_index(),
        credential=get_credential(),
    )


@app.get("/", response_class=HTMLResponse)
def root():
    return """
<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8">
  <title>PPT Document Search</title>
  <style>
    body { font-family: Arial, sans-serif; margin: 40px; background: #f6f8fa; }
    .box { background: white; padding: 30px; border-radius: 12px; max-width: 960px; box-shadow: 0 2px 8px rgba(0,0,0,0.08); }
    h1 { color: #222; }
    .status { color: green; font-weight: bold; }
    input[type=text] { width: 70%; padding: 10px; font-size: 16px; }
    input[type=file] { padding: 10px; font-size: 15px; }
    button { padding: 10px 18px; font-size: 16px; cursor: pointer; }
    .section { margin-top: 30px; padding-top: 20px; border-top: 1px solid #ddd; }
    .note { color: #666; }
    a { color: #0969da; }
  </style>
</head>
<body>
  <div class="box">
    <h1>PPT Document Search</h1>
    <p class="status">Azure Container Apps Web Service Running</p>

    <div class="section">
      <h2>1. 파일 업로드</h2>
      <form action="/upload" method="post" enctype="multipart/form-data">
        <input type="file" name="file" accept=".pdf,.ppt,.pptx,.xls,.xlsx" required>
        <button type="submit">업로드</button>
      </form>
      <p class="note">업로드 파일은 Blob Storage original 컨테이너에 저장되고, index-jobs Queue에 메시지가 등록됩니다.</p>
    </div>

    <div class="section">
      <h2>2. 문서 검색</h2>
      <form action="/search" method="get">
        <input type="text" name="q" placeholder="검색어를 입력하세요">
        <button type="submit">검색</button>
      </form>
      <p class="note">Worker Job이 인덱싱한 문서를 Azure AI Search에서 조회합니다.</p>
    </div>

    <div class="section">
      <h2>3. 상태 확인</h2>
      <ul>
        <li><a href="/healthz">Health Check</a></li>
        <li><a href="/search?q=업로드">검색 테스트</a></li>
      </ul>
    </div>
  </div>
</body>
</html>
"""


@app.get("/healthz")
def healthz():
    return {
        "status": "ok",
        "service": "ppt-document-search",
        "mode": os.getenv("APP_MODE", "web"),
        "storage_account": os.getenv("AZURE_STORAGE_ACCOUNT"),
        "queue_name": os.getenv("AZURE_QUEUE_NAME"),
        "search_endpoint": os.getenv("AZURE_SEARCH_ENDPOINT"),
        "search_index": os.getenv("AZURE_SEARCH_INDEX"),
        "openai_endpoint": os.getenv("AZURE_OPENAI_ENDPOINT"),
    }


@app.get("/thumb/{file_id}/{page_no}")
def thumbnail(file_id: str, page_no: int):
    if page_no < 1:
        raise HTTPException(status_code=404, detail="thumbnail not found")

    blob_name = f"{file_id}/page-{page_no}.png"
    blob_client = get_blob_service_client().get_blob_client(
        container="thumbnails",
        blob=blob_name,
    )

    try:
        data = blob_client.download_blob().readall()
    except Exception as exc:
        raise HTTPException(status_code=404, detail="thumbnail not found") from exc

    return Response(
        content=data,
        media_type="image/png",
        headers={"Cache-Control": "public, max-age=3600"},
    )


def get_converted_pdf(file_id: str):
    blob_service = get_blob_service_client()
    container = blob_service.get_container_client("converted-pdf")

    blobs = list(container.list_blobs(name_starts_with=f"{file_id}/"))
    pdf_blobs = [blob for blob in blobs if blob.name.lower().endswith(".pdf")]
    if not pdf_blobs:
        raise HTTPException(status_code=404, detail="pdf not found")

    blob_client = container.get_blob_client(pdf_blobs[0].name)
    return blob_client.download_blob().readall()


@app.get("/pdf/{file_id}")
def download_pdf(file_id: str):
    try:
        data = get_converted_pdf(file_id)
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"pdf download failed: {exc}") from exc

    return Response(
        content=data,
        media_type="application/pdf",
        headers={
            "Content-Disposition": 'attachment; filename="document.pdf"',
            "Cache-Control": "private, max-age=300",
        },
    )


@app.get("/pdf/{file_id}/page/{page_no}")
def download_pdf_page(file_id: str, page_no: int):
    if page_no < 1:
        raise HTTPException(status_code=404, detail="page not found")

    try:
        data = get_converted_pdf(file_id)
        source_pdf = fitz.open(stream=data, filetype="pdf")
        if page_no > source_pdf.page_count:
            source_pdf.close()
            raise HTTPException(status_code=404, detail="page not found")

        page_pdf = fitz.open()
        page_pdf.insert_pdf(source_pdf, from_page=page_no - 1, to_page=page_no - 1)
        page_data = page_pdf.tobytes(garbage=4, deflate=True)
        page_pdf.close()
        source_pdf.close()
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"page pdf download failed: {exc}") from exc

    return Response(
        content=page_data,
        media_type="application/pdf",
        headers={
            "Content-Disposition": f'attachment; filename="document-page-{page_no}.pdf"',
            "Cache-Control": "private, max-age=300",
        },
    )


@app.post("/upload", response_class=HTMLResponse)
async def upload(file: UploadFile = File(...)):
    file_id = str(uuid.uuid4())
    original_name = file.filename
    safe_name = original_name.replace("/", "_").replace("\\", "_")
    ext = os.path.splitext(safe_name)[1].lower().replace(".", "")

    blob_name = f"{file_id}/{safe_name}"

    content = await file.read()

    blob_service = get_blob_service_client()
    blob_client = blob_service.get_blob_client(
        container="original",
        blob=blob_name,
    )

    blob_client.upload_blob(content, overwrite=True)

    source_blob_url = blob_client.url

    message = {
        "job_type": "index_document",
        "file_id": file_id,
        "file_name": safe_name,
        "file_ext": ext,
        "container": "original",
        "blob_name": blob_name,
        "source_blob_url": source_blob_url,
        "created_at": datetime.now(timezone.utc).isoformat(),
    }

    queue = get_queue_client()
    queue.send_message(json.dumps(message, ensure_ascii=False))

    return f"""
<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8">
  <title>업로드 완료</title>
</head>
<body>
  <h1>업로드 완료</h1>
  <p><b>파일명:</b> {html.escape(safe_name)}</p>
  <p><b>file_id:</b> {file_id}</p>
  <p><b>Blob:</b> {html.escape(blob_name)}</p>
  <p><b>Queue:</b> index-jobs 메시지 등록 완료</p>
  <p>Worker Job이 실행되면 PDF 변환, 썸네일 생성, Azure AI Search 인덱싱을 처리합니다.</p>
  <p><a href="/">메인으로</a></p>
</body>
</html>
"""


@app.get("/search", response_class=HTMLResponse)
def search(q: str = ""):
    q = q.strip()
    escaped_q = html.escape(q)

    if not q:
        return """
<!DOCTYPE html>
<html lang="ko">
<head><meta charset="UTF-8"><title>검색</title></head>
<body>
  <h1>검색어를 입력하세요.</h1>
  <p><a href="/">메인으로</a></p>
</body>
</html>
"""

    client = get_search_client()

    try:
        results = client.search(
            search_text=q,
            top=20,
            select=[
                "id",
                "file_id",
                "file_name",
                "file_ext",
                "page_no",
                "slide_no",
                "chunk_no",
                "title",
                "text",
                "ocr_text",
                "source_blob_url",
                "pdf_blob_url",
                "thumb_blob_url",
                "updated_at",
            ],
        )

        rows = []
        for r in results:
            file_id = html.escape(str(r.get("file_id", "")))
            file_name = html.escape(str(r.get("file_name", "")))
            title = html.escape(str(r.get("title", "")))
            text_raw = str(r.get("text", "") or "").strip()
            ocr_raw = str(r.get("ocr_text", "") or "").strip()
            page_no = r.get("page_no", "")
            score = r.get("@search.score", 0) or 0
            if float(score) < 3:
                continue

            score_text = f"{float(score):.2f}"
            thumb_blob_url = str(r.get("thumb_blob_url", "") or "")

            content_sections = []
            if text_raw:
                content_sections.append(f"""
                  <div class="content-section">
                    <div class="content-label">문서 텍스트</div>
                    <div class="content-text">{html.escape(text_raw)}</div>
                  </div>
                """)
            if ocr_raw and ocr_raw not in text_raw:
                content_sections.append(f"""
                  <div class="content-section">
                    <div class="content-label">구성도/OCR 텍스트</div>
                    <div class="content-text">{html.escape(ocr_raw)}</div>
                  </div>
                """)

            summary = (
                "".join(content_sections)
                if content_sections
                else '<div class="content-text empty-text">표시할 텍스트가 없습니다.</div>'
            )

            thumb_html = ""
            if file_id and page_no and thumb_blob_url:
                thumb_html = f"""
              <a class="thumb-link" href="/pdf/{file_id}/page/{page_no}" title="이 페이지만 다운로드">
                <img src="/thumb/{file_id}/{page_no}" alt="{file_name} page {page_no}">
              </a>
                """
            else:
                thumb_html = """
              <div class="thumb-empty">NO THUMBNAIL</div>
                """

            download_html = ""
            if file_id:
                download_html = f"""
              <div class="downloads">
                <a class="download primary" href="/pdf/{file_id}">전체 PDF</a>
                <a class="download secondary" href="/pdf/{file_id}/page/{page_no}">이 페이지만</a>
              </div>
                """

            rows.append(f"""
            <article class="card">
              {thumb_html}
              <div class="card-body">
                <h2>{file_name}</h2>
                <div class="meta">
                  <span>Page {page_no}</span>
                  <span>Score {score_text}</span>
                </div>
                <div class="summary">{summary}</div>
                {download_html}
              </div>
            </article>
            """)

        result_html = (
            f'<div class="grid">{"".join(rows)}</div>'
            if rows
            else '<p class="empty">Score 3 이상 검색 결과가 없습니다.</p>'
        )

    except Exception as e:
        result_html = f"<pre>Search error: {html.escape(str(e))}</pre>"

    return f"""
<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8">
  <title>검색 결과</title>
  <style>
    body {{
      margin: 32px;
      background: #f4f6f8;
      color: #202428;
      font-family: Arial, sans-serif;
    }}
    .top {{
      display: flex;
      justify-content: space-between;
      align-items: center;
      gap: 16px;
      margin-bottom: 20px;
    }}
    .top h1 {{
      margin: 0;
      font-size: 24px;
    }}
    .top a {{
      color: #0969da;
      text-decoration: none;
    }}
    .query {{
      margin: 0 0 18px;
      color: #5b626b;
    }}
    .grid {{
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
      gap: 14px;
      align-items: stretch;
    }}
    .card {{
      display: flex;
      flex-direction: column;
      min-height: 360px;
      background: #fff;
      border: 1px solid #d9dee5;
      border-radius: 6px;
      overflow: hidden;
    }}
    .thumb-link,
    .thumb-empty {{
      display: flex;
      align-items: center;
      justify-content: center;
      height: 190px;
      background: #eef1f4;
      border-bottom: 1px solid #d9dee5;
    }}
    .thumb-link img {{
      width: 100%;
      height: 100%;
      object-fit: contain;
      background: #fff;
    }}
    .thumb-empty {{
      color: #87909a;
      font-size: 12px;
      font-weight: 700;
    }}
    .card-body {{
      display: flex;
      flex: 1;
      flex-direction: column;
      padding: 12px;
      gap: 8px;
    }}
    .card h2 {{
      margin: 0;
      font-size: 14px;
      line-height: 1.35;
      word-break: break-word;
    }}
    .meta {{
      display: flex;
      justify-content: space-between;
      gap: 8px;
      color: #606975;
      font-size: 12px;
    }}
    .summary {{
      flex: 1;
      margin: 0;
      max-height: 190px;
      overflow: auto;
      color: #333b45;
      font-size: 13px;
      line-height: 1.45;
      word-break: break-word;
    }}
    .content-section + .content-section {{
      margin-top: 10px;
      padding-top: 10px;
      border-top: 1px solid #e5e9ef;
    }}
    .content-label {{
      margin-bottom: 4px;
      color: #5b626b;
      font-size: 12px;
      font-weight: 700;
    }}
    .content-text {{
      white-space: pre-wrap;
    }}
    .empty-text {{
      color: #87909a;
    }}
    .downloads {{
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 8px;
    }}
    .download {{
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 9px 10px;
      border-radius: 4px;
      text-align: center;
      text-decoration: none;
      font-size: 13px;
      font-weight: 700;
    }}
    .download.primary {{
      background: #0969da;
      color: white;
    }}
    .download.secondary {{
      background: #fff;
      color: #0969da;
      border: 1px solid #0969da;
    }}
    .empty {{
      padding: 24px;
      background: #fff;
      border: 1px solid #d9dee5;
      border-radius: 6px;
    }}
  </style>
</head>
<body>
  <div class="top">
    <h1>검색 결과</h1>
    <a href="/">메인으로</a>
  </div>
  <p class="query">검색어: <b>{escaped_q}</b> · Score 3 이상만 표시</p>
  {result_html}
</body>
</html>
"""
