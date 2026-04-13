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

RATIO_THRESHOLD = 0.7  # when space to line height exceeds
MIN_GAP = 2.0  # pdf pixels


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
def extract_lines(block):
    lines = []

    for line in block.get("lines", []):
        _each_spantext = (_span.get("text", "") for _span in line.get("spans", []))
        raw = "".join(_each_spantext)

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
def is_paragraph_break(prev_bbox, curr_bbox):
    prev_y1 = prev_bbox["y1"]
    curr_y0 = curr_bbox["y0"]

    gap = curr_y0 - prev_y1
    line_height = prev_bbox["y1"] - prev_bbox["y0"]

    threshold = max(MIN_GAP, line_height * RATIO_THRESHOLD)
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
def build_paragraphs(lines):
    paragraphs = []
    current_lines = []

    for line in lines:
        if not current_lines:
            current_lines.append(line)
            continue

        if is_paragraph_break(current_lines[-1]["bbox"], line["bbox"]):
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


# Take a block, and process it into paragraphs, throwing out line/span level
# bbox and separation.
def process_block(block):
    lines = extract_lines(block)
    if not lines:
        return None

    paragraphs = build_paragraphs(lines)

    block_bbox = block.get("bbox")
    if not block_bbox:
        return None

    return {
        "bbox": bbox_dict(block_bbox),
        "paragraphs": paragraphs,
    }


def process_page(page):
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

    for block in blocks:
        if block.get("type") != 0:
            continue

        processed = process_block(block)
        if processed:
            result_blocks.append(processed)

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

    args = parser.parse_args()

    doc = pymupdf.open(args.pdf_path)
    pages = [process_page(page) for page in doc]

    json_kwargs = {
        "ensure_ascii": False
    }

    if args.pretty:
        json_kwargs["indent"] = 2

    print(json.dumps({"pages": pages}, **json_kwargs))


if __name__ == "__main__":
    main()
