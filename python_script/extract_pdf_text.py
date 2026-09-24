#!/usr/bin/env python3

import argparse
import pymupdf
import json
import re

# Extracts text from a PDF with PyMuPDF -- organized into detected blocks and
# paragraphs, with text and bbox. Paragraph detecting logic is in this script,
# block/line logic from PyMuPdf.  Output in json format.
#
# Cannot handle tables or any fancy formatting, written for pretty straightforward
# single column text.
#
# This script was created mostly by ChatGPT: https://chatgpt.com/share/69cd2a28-3c68-832b-99d1-38e922106efc
#
# output:
#
# ```
# {
#   pages: [
#     {
#       width: $width,
#       height: $height,
#       blocks: [
#         {
#           bbox: {x0: $x0, y0: $y0, x1: $x1, y1: $y1},
#           paragraphs: [
#               {
#                   bbox: {x0: $x0, y0: $y0, x1: $x1, y1: $y1},
#                   text: "Text of paragraph"
#               }
#           ]
#         }
#       ]
#     }
#   ]
# }
# ```
#
#  python3 extract_pdf_text.py input.pdf
#     # output to stdout
#
#  python3 extract_pdf_text.py input.pdf --pretty
#     # pretty-print the json with indent=2
#

# when space to line height exceeds, call it a paragraph break. Higher 0.7 worked
# well for our born digital, but for OCR'd 0.5 is necessary to not miss some.
BORN_DIGITAL_RATIO_THRESHOLD = 0.7
OCR_RATIO_THRESHOLD = 0.5
MIN_GAP = 2.0  # pdf pixels

# OCR-detected line bboxes are sometimes anomalously tall leading to wrong calcs,
# cap it.
OCR_MAX_GAP = 6.0  # pdf pixels

# keep in sync with Ruby's PdfParagraphSplitter::PAGE_NUMBER_RE
PAGE_NUMBER_RE = re.compile(r"\A(?:[Pp]age )?(\d+)\Z")


def normalize_text_whitespace(text):
    #text = re.sub(r"\s+", " ", text)
    text = text.replace("\u00a0", " ").strip()
    return text


# bbox is a bounding box, given by PyMuPDF as a list of four elements, x0, y0, x1, y1,
# which are actually two points that define a rectangle. Used to specify location of
# a line, paragraph, or block of paragraphs on the PDF page, using PDF pixel coordinates.
def bbox_dict(b):
    return {
        "x0": round(b[0], 1),
        "y0": round(b[1], 1),
        "x1": round(b[2], 1),
        "y1": round(b[3], 1),
    }


# get lines with normalized whitespace and bbox; we don't need span/word granularity
def extract_lines(block, source_text_is_ocr=False):
    lines = []

    for line in block.get("lines", []):
        _each_spantext = (_span.get("text", "") for _span in line.get("spans", []))
        raw = "".join(_each_spantext)

        # OCR consistently hallucinates stray "|" from scan-edge/margin artifacts;
        # a real OCR'd transcript rarely shouldn't contain one that matters to us, better to remove.
        if source_text_is_ocr:
            raw = raw.replace("|", "")

        text = normalize_text_whitespace(raw)

        if not text:
            continue

        bbox = line.get("bbox")
        if not bbox:
            continue

        lines.append({
            "text": text,
            "bbox": bbox_dict(bbox),
        })

    return lines

# is the current line bbox far enough from previous to indicate start of new paragraph?
def is_paragraph_break(prev_bbox, curr_bbox, ratio_threshold, source_text_is_ocr=False):
    prev_y1 = prev_bbox["y1"]
    curr_y0 = curr_bbox["y0"]

    gap = curr_y0 - prev_y1
    line_height = prev_bbox["y1"] - prev_bbox["y0"]

    threshold = max(MIN_GAP, line_height * ratio_threshold)
    if source_text_is_ocr:
        threshold = min(threshold, OCR_MAX_GAP)
    return gap > threshold


# given a list of bbox's, calculate a super bbox that draws the
# rectangle barely just containing them all.
def merge_bbox(bboxes):
    return {
        "x0": min(b["x0"] for b in bboxes),
        "y0": min(b["y0"] for b in bboxes),
        "x1": max(b["x1"] for b in bboxes),
        "y1": max(b["y1"] for b in bboxes),
    }


# take list of lines, and group into paragraphs, with line text joined,
# and total merged bbox of the lines.
def build_paragraphs(lines, ratio_threshold, source_text_is_ocr=False):
    paragraphs = []
    current_lines = []

    for line in lines:
        if not current_lines:
            current_lines.append(line)
            continue

        if is_paragraph_break(current_lines[-1]["bbox"], line["bbox"], ratio_threshold, source_text_is_ocr=source_text_is_ocr):
            paragraphs.append(current_lines)
            current_lines = [line]
        else:
            current_lines.append(line)

    if current_lines:
        paragraphs.append(current_lines)

    return [
        {
            "text": " ".join(l["text"] for l in group),
            "bbox": merge_bbox([l["bbox"] for l in group]),
        }
        for group in paragraphs
    ]


# source_text_is_ocr: for unreliable OCR block detection, use OCR_RATIO_THRESHOLD and build paragraphs page-wide instead of per-block; page-number-only blocks always stay separate (needed by PdfParagraphSplitter#block_is_page_number)
def process_page(page, source_text_is_ocr=False):
    merge_blocks = source_text_is_ocr
    ratio_threshold = OCR_RATIO_THRESHOLD if source_text_is_ocr else BORN_DIGITAL_RATIO_THRESHOLD

    tp = page.get_textpage("layout")
    d = tp.extractDICT()

    # Sort blocks top-to-bottom, then left-to-right
    # Don't know why they don't come out sorted properly.
    blocks = sorted(
        d.get("blocks", []),
        key=lambda b: (
            b.get("bbox", [0, 0, 0, 0])[1],
            b.get("bbox", [0, 0, 0, 0])[0],
        ),
    )

    result_blocks = []
    pending_lines, pending_bboxes = [], []

    def flush_pending():
        if pending_lines:
            result_blocks.append({
                "bbox": merge_bbox(pending_bboxes),
                "paragraphs": build_paragraphs(pending_lines, ratio_threshold, source_text_is_ocr=source_text_is_ocr),
            })
            pending_lines.clear()
            pending_bboxes.clear()

    for block in blocks:
        if block.get("type") != 0:
            continue

        lines = extract_lines(block, source_text_is_ocr=source_text_is_ocr)
        if not lines:
            continue

        is_page_number = len(lines) == 1 and PAGE_NUMBER_RE.match(lines[0]["text"])

        if not merge_blocks or is_page_number:
            flush_pending()
            result_blocks.append({
                "bbox": bbox_dict(block["bbox"]),
                "paragraphs": build_paragraphs(lines, ratio_threshold, source_text_is_ocr=source_text_is_ocr),
            })
        else:
            pending_lines.extend(lines)
            pending_bboxes.append(bbox_dict(block["bbox"]))

    flush_pending()

    return {
        "width": round(page.rect.width, 1),
        "height": round(page.rect.height, 1),
        "blocks": result_blocks,
    }


def main():
    parser = argparse.ArgumentParser(description="Extract structured text from PDF")
    parser.add_argument("pdf_path", help="Path to PDF file")
    parser.add_argument(
        "--pretty",
        action="store_true",
        help="Pretty-print JSON output (indent=2)",
    )
    parser.add_argument(
        "--source-text-is-ocr",
        action="store_true",
        help="Text layer was added by OCR (e.g. ocrmypdf), not born-digital -- adjusts paragraph detection accordingly",
    )

    args = parser.parse_args()

    doc = pymupdf.open(args.pdf_path)
    pages = [process_page(page, source_text_is_ocr=args.source_text_is_ocr) for page in doc]

    json_kwargs = {
        "ensure_ascii": False
    }

    if args.pretty:
        json_kwargs["indent"] = 2

    print(json.dumps({"pages": pages}, **json_kwargs))


if __name__ == "__main__":
    main()
