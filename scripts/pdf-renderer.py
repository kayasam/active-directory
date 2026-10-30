"""Build chapter PDFs from the same Markdown as the downloadable courses."""
from pathlib import Path
import hashlib
import html
import json
import io
import posixpath
import re
import sys
import textwrap
from functools import partial
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / '.pdf-tools'))
try:
    import markdown
    from bs4 import BeautifulSoup, NavigableString
    from reportlab.lib import colors
    from reportlab.lib.enums import TA_LEFT
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.styles import ParagraphStyle
    from reportlab.pdfbase import pdfmetrics
    from reportlab.pdfbase.ttfonts import TTFont
    from reportlab.pdfgen import canvas
    from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Preformatted, Table, TableStyle, HRFlowable, Image, PageBreak
    from svglib.svglib import svg2rlg, register_font
    from pypdf import PdfReader, PdfWriter
except ImportError as error:
    raise SystemExit('PDF : installer les dépendances avec python -m pip install --target .pdf-tools -r scripts/requirements-pdf.txt') from error

CONTENT = ROOT / 'content'
BASE = 'https://kayasam.github.io/linux-initiation'
WIDTH = A4[0] - 96
INK = colors.HexColor('#213547')
ACCENT = colors.HexColor('#126b73')
SOFT = colors.HexColor('#f2f6f8')


class CodeBlock(Preformatted):
    def draw(self):
        self.canv.saveState()
        self.canv.setFillColor(SOFT)
        self.canv.roundRect(-7, -5, self.width + 14, self.height + 10, 4, stroke=0, fill=1)
        self.canv.restoreState()
        super().draw()


def setup_fonts():
    windows = Path('C:/Windows/Fonts')
    linux = Path('/usr/share/fonts/truetype/dejavu')
    files = {
        'Course': (windows / 'arial.ttf', linux / 'DejaVuSans.ttf'),
        'Course-Bold': (windows / 'arialbd.ttf', linux / 'DejaVuSans-Bold.ttf'),
        'Course-Italic': (windows / 'ariali.ttf', linux / 'DejaVuSans-Oblique.ttf'),
        'Course-BoldItalic': (windows / 'arialbi.ttf', linux / 'DejaVuSans-BoldOblique.ttf'),
        'CourseMono': (windows / 'consola.ttf', linux / 'DejaVuSansMono.ttf'),
    }
    for name, candidates in files.items():
        path = next((p for p in candidates if p.is_file()), None)
        assert path, f'Police manquante : {name}'
        pdfmetrics.registerFont(TTFont(name, str(path)))
        if name in ('Course', 'Course-Bold', 'CourseMono'):
            family = 'CourseMono' if name == 'CourseMono' else 'Course'
            weights = ('bold', '600', '650', '700', '750', '800', '850', '900') if name == 'Course-Bold' else ('normal', '400', '500')
            if family == 'CourseMono':
                weights += ('bold', '600', '700')
            for weight in weights:
                register_font(family, str(path), weight=weight, rlgFontName=name)
    pdfmetrics.registerFontFamily('Course', normal='Course', bold='Course-Bold', italic='Course-Italic', boldItalic='Course-BoldItalic')


def inline(node, course_url):
    if isinstance(node, NavigableString):
        return html.escape(str(node))
    value = ''.join(inline(child, course_url) for child in node.children)
    if node.name in ('strong', 'b'):
        return '<b>' + value + '</b>'
    if node.name in ('em', 'i'):
        return '<i>' + value + '</i>'
    if node.name == 'code':
        return '<font name="CourseMono" size="9">' + value + '</font>'
    if node.name == 'br':
        return '<br/>'
    if node.name == 'a':
        href = node.get('href', '')
        if href.startswith('#'):
            href = course_url + href
        if href.startswith(('https://', 'http://')):
            return '<a href="' + html.escape(href, quote=True) + '" color="#126b73">' + value + '</a>'
    if node.name == 'img':
        return ''
    return value


def styles():
    normal = ParagraphStyle('Text', fontName='Course', fontSize=10.5, leading=16, textColor=INK, spaceAfter=9, splitLongWords=True)
    result = {'p': normal, 'li': ParagraphStyle('List', parent=normal, leftIndent=13, firstLineIndent=-10, spaceAfter=5),
              'cell': ParagraphStyle('Cell', parent=normal, fontSize=8.6, leading=12, spaceAfter=0),
              'caption': ParagraphStyle('Caption', parent=normal, fontSize=8.2, leading=12, textColor=colors.HexColor('#536675'), spaceAfter=12),
              'quote': ParagraphStyle('Quote', parent=normal, backColor=SOFT, borderColor=ACCENT, borderWidth=.7, borderPadding=10, spaceBefore=7, spaceAfter=14),
              'code': ParagraphStyle('Code', fontName='CourseMono', fontSize=8.3, leading=12, textColor=INK, backColor=SOFT, borderPadding=9, spaceBefore=3, spaceAfter=13)}
    for level, size in enumerate((23, 16, 12.5, 11.5), 1):
        result['h' + str(level)] = ParagraphStyle('Heading' + str(level), parent=normal, fontName='Course-Bold', fontSize=size, leading=size * 1.28, textColor=ACCENT if level > 1 else INK, spaceBefore=16 if level > 1 else 4, spaceAfter=10, keepWithNext=True)
    return result


def markdown_html(body):
    """Parse fenced code inside Obsidian notes as code, not inline prose."""
    parts = re.split(r'(^```[^\n]*\n.*?^```[^\n]*$)', body, flags=re.M | re.S)
    def quote(match):
        inside = re.sub(r'^> ?', '', match[0], flags=re.M)
        return '<blockquote>\n' + markdown_html(inside) + '\n</blockquote>\n\n'
    for index in range(0, len(parts), 2):
        parts[index] = re.sub(r'(?:^>[^\n]*(?:\n|$))+', quote, parts[index], flags=re.M)
    return markdown.markdown(''.join(parts), extensions=['tables', 'fenced_code', 'sane_lists'])


def local_image(src):
    parsed = urlsplit(src)
    configured = urlsplit(BASE)
    if parsed.netloc and parsed.netloc != configured.netloc:
        raise ValueError('Image externe non intégrée au cours : ' + src)
    path = unquote(parsed.path)
    prefix = configured.path.rstrip('/')+'/'
    if path.startswith(prefix):
        path = path[len(prefix):]
    elif path.startswith('../Ressources/'):
        path = 'ressources/' + path[len('../Ressources/'):]
    target = (CONTENT / path).resolve()
    assert target.is_relative_to(CONTENT.resolve()) and target.is_file(), src
    return target


def image_flowables(node, style):
    path = local_image(node['src'])
    if path.suffix.lower() == '.svg':
        # MuPDF preserves the gradients used by the Fournil diagrams.
        import pymupdf
        with pymupdf.open(path) as drawing:
            png = drawing[0].get_pixmap(matrix=pymupdf.Matrix(2,2)).tobytes('png')
        image = Image(io.BytesIO(png))
        scale = min(WIDTH / image.imageWidth, 300 / image.imageHeight)
        image.drawWidth = image.imageWidth * scale
        image.drawHeight = image.imageHeight * scale
    else:
        image = Image(str(path))
        scale = min(WIDTH / image.imageWidth, 300 / image.imageHeight)
        image.drawWidth = image.imageWidth * scale
        image.drawHeight = image.imageHeight * scale
    return [Spacer(1, 6), image, Spacer(1, 5), Paragraph(html.escape(node.get('alt', '')), style['caption'])]


def flowables(nodes, style, course_url, width=WIDTH):
    output = []
    for node in nodes:
        if isinstance(node, NavigableString):
            if str(node).strip():
                output.append(Paragraph(html.escape(str(node)), style['p']))
            continue
        tag = node.name
        if tag in ('script', 'style', 'nav'):
            continue
        if tag in ('h1', 'h2', 'h3', 'h4', 'h5', 'h6'):
            output.append(Paragraph(inline(node, course_url), style.get(tag, style['h4'])))
        elif tag == 'pre':
            # Wrap only for the printed page; the Markdown source is untouched.
            lines = []
            for line in node.get_text().expandtabs(4).splitlines():
                lines.extend(textwrap.wrap(line, width=91, break_long_words=True, break_on_hyphens=False, replace_whitespace=False, drop_whitespace=False, subsequent_indent='    ') or [''])
            output.append(CodeBlock('\n'.join(lines), style['code']))
        elif tag in ('ul', 'ol'):
            for index, item in enumerate(node.find_all('li', recursive=False), 1):
                bullet = f'{index}.' if tag == 'ol' else '•'
                contents = ''.join(inline(child, course_url) for child in item.children if getattr(child, 'name', None) not in ('ul', 'ol'))
                output.append(Paragraph(html.escape(bullet) + ' ' + contents, style['li']))
                output.extend(flowables(item.find_all(['ul', 'ol'], recursive=False), style, course_url, width - 12))
        elif tag == 'table':
            rows = []
            for row in node.find_all('tr'):
                cells = []
                for cell in row.find_all(['td', 'th'], recursive=False):
                    text = inline(cell, course_url)
                    cells.append(Paragraph('<b>' + text + '</b>' if cell.name == 'th' else text, style['cell']))
                rows.append(cells)
            if rows:
                count = max(map(len, rows))
                rows = [row + [''] * (count - len(row)) for row in rows]
                table = Table(rows, colWidths=[width / count] * count, repeatRows=1, hAlign='LEFT')
                table.setStyle(TableStyle([('VALIGN', (0, 0), (-1, -1), 'TOP'), ('BACKGROUND', (0, 0), (-1, 0), SOFT), ('LINEBELOW', (0, 0), (-1, 0), .7, ACCENT), ('LINEBELOW', (0, 1), (-1, -1), .3, colors.HexColor('#dbe4ea')), ('LEFTPADDING', (0, 0), (-1, -1), 7), ('RIGHTPADDING', (0, 0), (-1, -1), 7), ('TOPPADDING', (0, 0), (-1, -1), 7), ('BOTTOMPADDING', (0, 0), (-1, -1), 7)]))
                output.extend([table, Spacer(1, 12)])
        elif tag == 'blockquote':
            # Keep the note text and paragraphs; render nested code/tables normally.
            for child in node.children:
                if getattr(child, 'name', None) == 'p':
                    text = re.sub(r'^\[![A-Z]+\][-+]?\s*', '', inline(child, course_url))
                    if text.strip():
                        output.append(Paragraph(text, style['quote']))
                else:
                    output.extend(flowables([child], style, course_url, width))
        elif tag == 'p':
            pictures = node.find_all('img')
            text = inline(node, course_url)
            if text.strip():
                output.append(Paragraph(text, style['p']))
            for picture in pictures:
                output.extend(image_flowables(picture, style))
        elif tag == 'img':
            output.extend(image_flowables(node, style))
        elif tag == 'iframe':
            src = node.get('src', '')
            if src:
                output.append(Paragraph('<b>Vidéo du cours :</b> <a href="' + html.escape(src, quote=True) + '" color="#126b73">ouvrir la vidéo en ligne</a>', style['quote']))
        elif tag == 'hr':
            output.extend([Spacer(1, 5), HRFlowable(width='100%', thickness=.5, color=colors.HexColor('#dbe4ea')), Spacer(1, 10)])
        else:
            output.extend(flowables(node.children, style, course_url, width))
    return output

