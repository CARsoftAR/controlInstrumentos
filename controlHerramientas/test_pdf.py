import sys
import io
import os
import django
sys.path.append(r'C:\Sistemas ABBAMAT\control_herramientas_PROYECTO\controlHerramientas')
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'controlHerramientas.settings')
django.setup()

from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer
from reportlab.lib.pagesizes import landscape, A4
from reportlab.lib import colors
from reportlab.lib.units import mm
from reportlab.lib.styles import ParagraphStyle

buffer = io.BytesIO()
doc = SimpleDocTemplate(buffer, pagesize=landscape(A4), rightMargin=30, leftMargin=30, topMargin=30, bottomMargin=30)
elements = []

def draw_footer(canvas, doc):
    canvas.saveState()
    canvas.setFont("Helvetica", 9)
    canvas.drawString(20*mm, 15*mm, "Test")
    canvas.restoreState()

style = ParagraphStyle(name='Normal', fontSize=10)
data = [[Paragraph(f'Header {i}', style) for i in range(6)]]
for row in range(130):
    data.append([Paragraph(f'Cell {row}-{i}', style) for i in range(6)])

t = Table(data, colWidths=[80, 80, 70, 220, 130, 80], repeatRows=1)
t.setStyle(TableStyle([
    ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#fee2e2')),
    ('GRID', (0, 0), (-1, -1), 1, colors.HexColor('#d1d5db')),
    ('VALIGN', (0, 0), (-1, -1), 'TOP'),
]))
elements.append(t)

doc.build(elements, onFirstPage=draw_footer, onLaterPages=draw_footer)
with open('test_pdf.pdf', 'wb') as f:
    f.write(buffer.getvalue())
print("Test PDF created successfully")
